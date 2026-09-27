import 'package:flutter/material.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.nikController,
          decoration: InputDecoration(
            labelText: 'NIK',
            hintText: 'Cari berdasarkan NIK atau nama',
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        if (_searchQuery.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _getFilteredResidents().map((resident) {
                return ListTile(
                  title: Text(resident['name']),
                  subtitle: Text(resident['nik']),
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
        const SizedBox(height: 16),
        TextField(
          controller: widget.nameController,
          decoration: const InputDecoration(
            labelText: 'Nama Pemilik',
            border: OutlineInputBorder(),
          ),
          readOnly: true,
        ),
      ],
    );
  }
}
