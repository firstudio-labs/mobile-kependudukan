import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:http/http.dart' as http;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.nikController,
          decoration: InputDecoration(
            labelText: 'NIK Pemilik',
            hintText: 'Cari berdasarkan NIK atau nama',
            prefixIcon: const Icon(Icons.credit_card),
            suffixIcon: IconButton(
              icon: Icon(
                  _showDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down),
              onPressed: () {
                setState(() {
                  _showDropdown = !_showDropdown;
                });
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDropdownList(),
            ),
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.nameController,
          decoration: InputDecoration(
            labelText: 'Nama Pemilik',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          child: Text('Tidak ada data yang cocok'),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: filteredData.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final citizen = filteredData[index];
        return ListTile(
          dense: true,
          title: Text(
            citizen['nik'].toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(citizen['full_name'] ?? 'Nama tidak tersedia'),
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
    );
  }
}
