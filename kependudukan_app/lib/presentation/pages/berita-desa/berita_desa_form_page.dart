import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/berita_desa_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class BeritaDesaFormPage extends StatefulWidget {
  final int? draftId; // jika ada, mode edit
  final String? initialJudul;
  final String? initialDeskripsi;
  final String? initialKomentar;
  const BeritaDesaFormPage({
    Key? key,
    this.draftId,
    this.initialJudul,
    this.initialDeskripsi,
    this.initialKomentar,
  }) : super(key: key);

  @override
  State<BeritaDesaFormPage> createState() => _BeritaDesaFormPageState();
}

class _BeritaDesaFormPageState extends State<BeritaDesaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _komentarController = TextEditingController();
  File? _pickedImage;
  bool _submitting = false;
  late final BeritaDesaApiService _api;

  @override
  void initState() {
    super.initState();
    _api = BeritaDesaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    if (widget.initialJudul != null) {
      _judulController.text = widget.initialJudul!;
    }
    if (widget.initialDeskripsi != null) {
      _deskripsiController.text = widget.initialDeskripsi!;
    }
    if (widget.initialKomentar != null) {
      _komentarController.text = widget.initialKomentar!;
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _komentarController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile != null) {
      setState(() {
        _pickedImage = File(xfile.path);
      });
    }
  }

  Future<void> _submitApproval() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final res = await _api.createBeritaDesa(
        judul: _judulController.text.trim(),
        deskripsi: _deskripsiController.text.trim(),
        komentar: _komentarController.text.trim().isEmpty
            ? null
            : _komentarController.text.trim(),
        gambar: _pickedImage,
        submitForApproval: true,
      );
      if (!mounted) return;
      final statusMsg = (res['message'] ??
              'Berita diarsipkan dan menunggu verifikasi admin desa')
          .toString();
      MessageService.showSuccessSnackBar(context, statusMsg);

      // Clear cache berita desa untuk memastikan data ter-update
      await _api.clearCache();
      if (!mounted) return;

      // Notify parent page to refresh data
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      // Clean up error message for better user experience
      if (errorMessage.contains('Server error:')) {
        errorMessage = errorMessage.replaceAll('Server error:', '').trim();
      }
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.replaceAll('Exception:', '').trim();
      }
      MessageService.showErrorSnackBar(context, errorMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.draftId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isEdit ? 'Edit Draf Berita' : 'Tulis Berita Desa',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kartu Form
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field Judul
                    _buildFieldLabel(label: 'Judul Berita', isRequired: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _judulController,
                      style: const TextStyle(fontSize: 14),
                      decoration: _buildInputDecoration(
                        hintText: 'Masukkan judul berita desa...',
                        prefixIcon: Icons.title_rounded,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Judul berita wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Field Deskripsi
                    _buildFieldLabel(
                        label: 'Isi / Deskripsi Berita', isRequired: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _deskripsiController,
                      minLines: 5,
                      maxLines: 10,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                      decoration: _buildInputDecoration(
                        hintText:
                            'Tuliskan isi atau rangkaian kegiatan berita secara detail...',
                        prefixIcon: Icons.description_rounded,
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Deskripsi berita wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Field Komentar
                    _buildFieldLabel(
                        label: 'Catatan Tambahan', isRequired: false),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _komentarController,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14),
                      decoration: _buildInputDecoration(
                        hintText:
                            'Catatan atau pesan untuk verifikator desa (opsional)...',
                        prefixIcon: Icons.chat_bubble_outline_rounded,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload Gambar
                    _buildFieldLabel(
                        label: 'Foto Dokumentasi', isRequired: false),
                    const SizedBox(height: 8),
                    _buildImageUploader(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Berita',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel({required String label, required bool isRequired}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildImageUploader() {
    if (_pickedImage != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.file(
                _pickedImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_rounded, size: 16),
                      label: const Text(
                        'Ganti Foto',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _pickedImage = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    label: const Text(
                      'Hapus',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 28,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pilih Foto Dokumentasi',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Format JPG, PNG (Maksimal 5MB)',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
