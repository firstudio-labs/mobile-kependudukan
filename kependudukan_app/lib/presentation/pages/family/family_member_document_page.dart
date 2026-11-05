import 'dart:io';

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
      // Modern bottom sheet for source selection
      final String? source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Unggah $documentTitle',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih sumber dokumen yang ingin Anda unggah',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              _buildUploadOptionTile(
                icon: Icons.camera_alt_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                title: 'Kamera',
                subtitle: 'Ambil foto dokumen secara langsung',
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              const SizedBox(height: 10),
              _buildUploadOptionTile(
                icon: Icons.photo_library_rounded,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
                title: 'Galeri Foto',
                subtitle: 'Pilih foto dokumen dari galeri perangkat',
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              const SizedBox(height: 10),
              _buildUploadOptionTile(
                icon: Icons.description_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                title: 'Pilih Dokumen',
                subtitle: 'Unggah berkas PDF, DOC, atau format gambar',
                onTap: () => Navigator.pop(context, 'document'),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      File? imageFile;

      if (source == 'camera') {
        if (!mounted) return;
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
        try {
          FilePickerResult? result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
            allowMultiple: false,
          );

          if (result != null &&
              result.files.isNotEmpty &&
              result.files.single.path != null) {
            final documentFile = File(result.files.single.path!);

            final fileSize = await documentFile.length();
            if (fileSize > 10 * 1024 * 1024) {
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

            final fileExtension = result.files.single.extension?.toLowerCase();
            if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
              imageFile = await ImageUtils.processImage(
                documentFile,
                quality: 85,
                convertToWebP: false,
              );
            } else {
              imageFile = documentFile;
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memproses dokumen...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengupload dokumen...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

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

  Widget _buildUploadOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String documentType, String documentTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Dokumen?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $documentTitle? Dokumen yang dihapus tidak dapat dipulihkan.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(documentType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Hapus Dokumen'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mengunduh dokumen...'),
          duration: Duration(seconds: 1),
        ),
      );

      final directory = Directory('/storage/emulated/0/Download/Kependudukan');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName =
          '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(directory.path, fileName);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh dokumen');
      }

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Dokumen Anggota',
          style: TextStyle(
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon:
                const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mengupload dokumen...'),
                duration: Duration(seconds: 1),
              ),
            );
          } else if (state is DocumentUploaded) {
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Memuat dokumen...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            );
          } else if (state is DocumentError &&
              !(state is DocumentUploaded || state is DocumentLoaded)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memuat Dokumen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loadDocuments,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          FamilyMemberDocuments documents = const FamilyMemberDocuments();

          if (state is DocumentLoaded) {
            documents = state.documents;
          }

          // Count available documents
          int availableCount = 0;
          final docList = [
            documents.fotoDiri,
            documents.fotoKtp,
            documents.fotoAkta,
            documents.ijazah,
            documents.fotoKk,
            documents.fotoRumah,
          ];
          for (final d in docList) {
            if (d != null && d.exists) availableCount++;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _buildMemberHeaderCard(availableCount, docList.length),
              const SizedBox(height: 16),
              _buildDocumentCard(
                'Foto Diri',
                documents.fotoDiri ?? _createEmptyDocument(),
                'foto_diri',
                Icons.account_box_rounded,
                const Color(0xFF0284C7),
                const Color(0xFFE0F2FE),
              ),
              _buildDocumentCard(
                'Foto KTP',
                documents.fotoKtp ?? _createEmptyDocument(),
                'foto_ktp',
                Icons.badge_rounded,
                const Color(0xFF7C3AED),
                const Color(0xFFEDE9FE),
              ),
              _buildDocumentCard(
                'Foto Akta Kelahiran',
                documents.fotoAkta ?? _createEmptyDocument(),
                'foto_akta',
                Icons.history_edu_rounded,
                const Color(0xFFD97706),
                const Color(0xFFFEF3C7),
              ),
              _buildDocumentCard(
                'Ijazah',
                documents.ijazah ?? _createEmptyDocument(),
                'ijazah',
                Icons.school_rounded,
                const Color(0xFF0D9488),
                const Color(0xFFCCFBF1),
              ),
              _buildDocumentCard(
                'Foto Kartu Keluarga',
                documents.fotoKk ?? _createEmptyDocument(),
                'foto_kk',
                Icons.family_restroom_rounded,
                const Color(0xFF4F46E5),
                const Color(0xFFE0E7FF),
              ),
              _buildDocumentCard(
                'Foto Rumah',
                documents.fotoRumah ?? _createEmptyDocument(),
                'foto_rumah',
                Icons.home_work_rounded,
                const Color(0xFF16A34A),
                const Color(0xFFDCFCE7),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Header profile info of the family member
  Widget _buildMemberHeaderCard(int availableCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'NIK: ${widget.nik}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Dokumen Terunggah',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: availableCount > 0
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$availableCount dari $totalCount Berkas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: availableCount > 0
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
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
    String title,
    DocumentModel document,
    String documentType,
    IconData icon,
    Color iconColor,
    Color iconBgColor,
  ) {
    final bool exists = document.exists;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exists ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Icon + Title + Status Pill
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (exists && document.updatedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm')
                                    .format(document.updatedAt!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: exists
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        exists
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_empty_rounded,
                        size: 13,
                        color: exists
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exists ? 'Tersedia' : 'Belum Ada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: exists
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Document preview / Dropzone
          if (exists && document.previewUrl.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 190,
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  child: Image.network(
                    document.previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 190,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                size: 36,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Gagal memuat pratinjau gambar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppTheme.primaryColor,
                          strokeWidth: 2.5,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ] else ...[
            // Dropzone placeholder when no document is uploaded
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectAndUploadDocument(documentType, title),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 26,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada berkas $title',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ketuk di sini untuk mengunggah dokumen',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Action Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: exists
                ? Row(
                    children: [
                      // Delete button
                      IconButton(
                        onPressed: () => _confirmDelete(documentType, title),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: const Color(0xFFDC2626),
                        tooltip: 'Hapus dokumen',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Download button if url exists
                      if (document.previewUrl.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _downloadDocument(
                                document.previewUrl, documentType),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Unduh'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      // Update/Change button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _selectAndUploadDocument(documentType, title),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Ganti'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _selectAndUploadDocument(documentType, title),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text('Unggah $title'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
