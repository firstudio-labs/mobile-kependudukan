import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ladimas/core/theme/app_theme.dart';

class AssetFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final String? Function(String?)? validator;
  final bool enabled;

  const AssetFormTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.validator,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          enabled: enabled,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF1E293B),
            fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Masukkan ${label.toLowerCase()}',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[400]!),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }
}