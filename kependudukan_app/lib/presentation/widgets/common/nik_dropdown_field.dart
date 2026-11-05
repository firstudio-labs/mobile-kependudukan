import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/theme/app_theme.dart';

class NikDropdownField extends StatefulWidget {
  final TextEditingController nikController;
  final TextEditingController nameController;
  final Function(String nik, String name)? onSelected;

  const NikDropdownField({
    Key? key,
    required this.nikController,
    required this.nameController,
    this.onSelected,
  }) : super(key: key);

  @override
  State<NikDropdownField> createState() => _NikDropdownFieldState();
}

class _NikDropdownFieldState extends State<NikDropdownField> {
  List<Map<String, dynamic>> _nikData = [];
  bool _isLoading = false;
  bool _showDropdown = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _searchNIKData(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _nikData = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('${AppConstants.goBaseUrl}/api/v2/citizens-lite')
          .replace(queryParameters: {
        'search': query,
        'page': '1',
        'items_per_page': '5',
      });

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        final citizens = (data is Map<String, dynamic>)
            ? (data['data'] is Map<String, dynamic>
                ? data['data']['citizens']
                : null)
            : null;
        setState(() {
          _nikData = (citizens is List)
              ? citizens.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];
        });
      } else {
        MessageService.showErrorSnackBar(context, 'Gagal memuat data NIK');
      }
    } catch (e) {
      MessageService.showErrorSnackBar(context, 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredData() {
    final query = widget.nikController.text.toLowerCase();
    return _nikData
        .where((item) {
          final nikMatch = item['nik'].toString().toLowerCase().contains(query);
          final nameMatch = (item['full_name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query);
          return nikMatch || nameMatch;
        })
        .take(5)
        .toList(); // Limit results to 5 for better UI
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('NIK Pemilik'),
        TextFormField(
          controller: widget.nikController,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: 'Cari NIK atau nama pemilik...',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.badge_outlined,
                size: 20, color: Color(0xFF64748B)),
            suffixIcon: IconButton(
              icon: Icon(
                _showDropdown
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF64748B),
              ),
              onPressed: () {
                setState(() {
                  _showDropdown = !_showDropdown;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) => value!.isEmpty ? 'NIK harus diisi' : null,
          onChanged: (value) {
            setState(() {
              _showDropdown = value.isNotEmpty;
            });

            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              _searchNIKData(value);
            });
          },
        ),
        if (_showDropdown && widget.nikController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    )
                  : _buildDropdownList(),
            ),
          ),
        const SizedBox(height: 16),
        _buildLabel('Nama Pemilik'),
        TextFormField(
          controller: widget.nameController,
          readOnly: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
          decoration: InputDecoration(
            hintText: 'Nama otomatis terisi saat NIK dipilih',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.person_outline_rounded,
                size: 20, color: Color(0xFF64748B)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) =>
              value!.isEmpty ? 'Nama pemilik harus diisi' : null,
        ),
      ],
    );
  }

  Widget _buildDropdownList() {
    final filteredData = _getFilteredData();

    if (filteredData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'Tidak ada data yang cocok',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: filteredData.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final citizen = filteredData[index];
          return ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              citizen['nik'].toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
            subtitle: Text(
              citizen['full_name'] ?? 'Nama tidak tersedia',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            onTap: () {
              setState(() {
                widget.nikController.text = citizen['nik'].toString();
                widget.nameController.text = citizen['full_name'] ?? '';
                _showDropdown = false;
              });

              if (widget.onSelected != null) {
                widget.onSelected!(
                  citizen['nik'].toString(),
                  citizen['full_name'] ?? '',
                );
              }
            },
          );
        },
      ),
    );
  }
}
