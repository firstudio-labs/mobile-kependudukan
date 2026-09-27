import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/core/utils/image_utils.dart';
import 'package:ladimas/data/models/document_model.dart';
import 'package:ladimas/presentation/cubits/document/document_cubit.dart';
import 'package:ladimas/presentation/cubits/document/document_state.dart';
import 'package:ladimas/presentation/pages/camera_document_page.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';

class FamilyMemberDocumentsPage extends StatefulWidget {
  final String nik;
  final String name;

  const FamilyMemberDocumentsPage({
    Key? key,
    required this.nik,
    required this.name,
  }) : super(key: key);

  @override
  State<FamilyMemberDocumentsPage> createState() =>
      _FamilyMemberDocumentsPageState();
}

class _FamilyMemberDocumentsPageState extends State<FamilyMemberDocumentsPage> {
  late final DocumentCubit _documentCubit;

  @override
  void initState() {
    super.initState();
    _documentCubit = GetIt.instance<DocumentCubit>();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    await _documentCubit.loadFamilyMemberDocuments(widget.nik);
  }

  Future<void> _selectAndUploadDocument(
      String documentType, String documentTitle) async {
    try {
      // Show source selection dialog
      final String? source = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Upload $documentTitle'),
          content: const Text(
              'Pilih sumber gambar atau dokumen yang ingin diupload:'),
          actions: [
            // Camera option
            TextButton(
              onPressed: () => Navigator.pop(context, 'camera'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Kamera'),
                ],
              ),
            ),

            // Gallery option (images)
            TextButton(
              onPressed: () => Navigator.pop(context, 'gallery'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Galeri'),
                ],
              ),
            ),

            // Document picker option (files)
            TextButton(
              onPressed: () => Navigator.pop(context, 'document'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_present, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Pilih Dokumen'),
                ],
              ),
            ),

            // Cancel
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (source == null) return;

      File? imageFile;

      if (source == 'camera') {
        // Use custom camera with overlay (KTP overlay for foto_ktp)
        imageFile = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentCameraPage(
              documentType: documentType,
              documentTitle: documentTitle,
            ),
          ),
        );
      } else if (source == 'gallery') {
        // Use gallery picker for images
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          imageFile = File(image.path);
        }
      } else if (source == 'document') {
        // Use file picker for documents (PDF, DOC, etc.)
        try {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
            allowMultiple: false,
          );

          if (result != null &&
              result.files.isNotEmpty &&
              result.files.single.path != null) {
            final documentFile = File(result.files.single.path!);

            // Check file size (max 10MB)
            final fileSize = await documentFile.length();
            if (fileSize > 10 * 1024 * 1024) {
              // 10MB
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ukuran file maksimal 10MB'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }

            // For image files, compress them
            final fileExtension = result.files.single.extension?.toLowerCase();
            if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
              // Process as image
              imageFile = await ImageUtils.processImage(
                documentFile,
                quality: 85,
                convertToWebP: false,
              );
            } else {
              // For non-image files (PDF, DOC), use as is
              imageFile = documentFile;
            }

            // Show processing message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memproses dokumen...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            // User cancelled file picker
            return;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal memilih dokumen: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      if (imageFile != null) {
        // Show uploading message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengupload dokumen...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Upload file directly - WebP conversion will be handled by backend
        await _documentCubit.uploadDocument(
            widget.nik, documentType, imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete(String documentType, String documentTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus $documentTitle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(documentType);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(String documentType) async {
    try {
      await _documentCubit.deleteDocument(widget.nik, documentType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus dokumen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(String url, String documentType) async {
    try {
      // Show downloading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mengunduh dokumen...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Get the public Download directory
      final directory = Directory('/storage/emulated/0/Download/Kependudukan');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create a file name based on document type and timestamp
      final fileName =
          '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(directory.path, fileName);

      // Download the file
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh dokumen');
      }

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Dokumen berhasil disimpan di folder Download/Kependudukan'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh dokumen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dokumen ${widget.name}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _documentCubit.loadFamilyMemberDocuments(widget.nik,
                  forceRefresh: true);
            },
          ),
        ],
      ),
      body: BlocConsumer<DocumentCubit, DocumentState>(
        bloc: _documentCubit,
        listener: (context, state) {
          if (state is DocumentUploading) {
            // Tampilkan loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mengupload dokumen...'),
                duration: Duration(seconds: 1),
              ),
            );
          } else if (state is DocumentUploaded) {
            // Tampilkan pesan sukses
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dokumen berhasil diunggah!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is DocumentDeleting) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Menghapus dokumen...'),
                duration: Duration(seconds: 1),
              ),
            );
          } else if (state is DocumentDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dokumen berhasil dihapus!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is DocumentError) {
            // Tampilkan pesan error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is DocumentLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is DocumentError &&
              !(state is DocumentUploaded || state is DocumentLoaded)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDocuments,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          // Ambil data dokumen dari state
          FamilyMemberDocuments documents = const FamilyMemberDocuments();

          if (state is DocumentLoaded) {
            documents = state.documents;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDocumentCard('Foto Diri',
                  documents.fotoDiri ?? _createEmptyDocument(), 'foto_diri'),
              _buildDocumentCard('Foto KTP',
                  documents.fotoKtp ?? _createEmptyDocument(), 'foto_ktp'),
              _buildDocumentCard('Foto Akta',
                  documents.fotoAkta ?? _createEmptyDocument(), 'foto_akta'),
              _buildDocumentCard('Ijazah',
                  documents.ijazah ?? _createEmptyDocument(), 'ijazah'),
              _buildDocumentCard('Foto KK',
                  documents.fotoKk ?? _createEmptyDocument(), 'foto_kk'),
              _buildDocumentCard('Foto Rumah',
                  documents.fotoRumah ?? _createEmptyDocument(), 'foto_rumah'),
            ],
          );
        },
      ),
    );
  }

  DocumentModel _createEmptyDocument() {
    return const DocumentModel(
      exists: false,
      filePath: '',
      extension: '',
      previewUrl: '',
      updatedAt: null,
    );
  }

  Widget _buildDocumentCard(
      String title, DocumentModel document, String documentType) {
    final bool exists = document.exists;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document image
          if (exists && document.previewUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                document.previewUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error, size: 40, color: Colors.red),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Document info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (exists)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _confirmDelete(documentType, title),
                            tooltip: 'Hapus dokumen',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _selectAndUploadDocument(documentType, title),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label:
                            Text(exists ? 'Update Dokumen' : 'Upload Dokumen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (exists && document.updatedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Terakhir diperbarui: ${DateFormat('dd MMMM yyyy, HH:mm').format(document.updatedAt!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (!exists) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada dokumen',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (exists && document.previewUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _downloadDocument(document.previewUrl, documentType),
                      icon: const Icon(Icons.download),
                      label: const Text('Unduh Dokumen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
