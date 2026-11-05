import 'package:flutter/material.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:ladimas/core/theme/app_theme.dart';

class NikDropdownField extends StatefulWidget {
  final TextEditingController nikController;
  final TextEditingController nameController;
  final Function(String nik, String name) onSelected;

  const NikDropdownField({
    Key? key,
    required this.nikController,
    required this.nameController,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<NikDropdownField> createState() => _NikDropdownFieldState();
}

class _NikDropdownFieldState extends State<NikDropdownField> {
  List<Map<String, dynamic>> _residents = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  Future<void> _loadResidents() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/residents'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _residents = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading residents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredResidents() {
    if (_searchQuery.isEmpty) return _residents;
    return _residents.where((resident) {
      final nik = resident['nik'].toString().toLowerCase();
      final name = resident['name'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nik.contains(query) || name.contains(query);
    }).toList();
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
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

  InputDecoration _decoration({
    String? hint,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
      ),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('NIK'),
        TextField(
          controller: widget.nikController,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: _decoration(
            hint: 'Cari berdasarkan NIK atau nama',
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                : const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        if (_searchQuery.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(vertical: 4),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                children: _getFilteredResidents().map((resident) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      resident['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      resident['nik'],
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    onTap: () {
                      widget.nikController.text = resident['nik'];
                      widget.nameController.text = resident['name'];
                      widget.onSelected(resident['nik'], resident['name']);
                      setState(() => _searchQuery = '');
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _buildLabel('Nama Pemilik'),
        TextField(
          controller: widget.nameController,
          readOnly: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          decoration: _decoration(hint: 'Terisi otomatis', readOnly: true),
        ),
      ],
    );
  }
}
