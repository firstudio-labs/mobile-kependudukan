import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/berita_desa_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class BeritaDesaFormPage extends StatefulWidget {
  final int? draftId; // jika ada, mode edit
  final String? initialJudul;
  final String? initialDeskripsi;
  final String? initialKomentar;
  const BeritaDesaFormPage(
      {Key? key,
      this.draftId,
      this.initialJudul,
      this.initialDeskripsi,
      this.initialKomentar})
      : super(key: key);

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
    if (widget.initialJudul != null)
      _judulController.text = widget.initialJudul!;
    if (widget.initialDeskripsi != null)
      _deskripsiController.text = widget.initialDeskripsi!;
    if (widget.initialKomentar != null)
      _komentarController.text = widget.initialKomentar!;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.draftId == null ? 'Buat Berita Desa' : 'Edit Draf Berita'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _judulController,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deskripsiController,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Deskripsi wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _komentarController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Komentar (opsional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Pilih Gambar'),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedImage != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _pickedImage!,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitApproval,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan Berita'),
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
}
