import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

class AssetFormImagePicker extends StatefulWidget {
  final String label;
  final String? initialImageUrl;
  final Function(File?) onImageSelected;

  const AssetFormImagePicker({
    Key? key,
    required this.label,
    this.initialImageUrl,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  State<AssetFormImagePicker> createState() => _AssetFormImagePickerState();
}

class _AssetFormImagePickerState extends State<AssetFormImagePicker> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        widget.onImageSelected(_imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildImagePreview(),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else if (widget.initialImageUrl != null &&
        widget.initialImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.initialImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: AppTheme.primaryColor,
          ),
          SizedBox(height: 8),
          Text(
            'Pilih Foto',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
