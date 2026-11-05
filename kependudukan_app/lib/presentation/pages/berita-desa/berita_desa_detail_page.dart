import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/theme/app_theme.dart';
import '../../../data/datasources/berita_desa_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/models/berita_desa_model.dart';
import 'package:ladimas/presentation/pages/pengumuman/image_viewer_page.dart';

class BeritaDesaDetailPage extends StatefulWidget {
  final int id;

  const BeritaDesaDetailPage({Key? key, required this.id}) : super(key: key);

  @override
  State<BeritaDesaDetailPage> createState() => _BeritaDesaDetailPageState();
}

class _BeritaDesaDetailPageState extends State<BeritaDesaDetailPage> {
  late final BeritaDesaApiService _apiService;
  BeritaDesaModel? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = BeritaDesaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final data = await _apiService.getBeritaDesaDetail(id: widget.id);
      if (mounted) {
        setState(() {
          _detail = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(date);
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Detail Berita Desa',
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
            tooltip: 'Muat Ulang',
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            onPressed: _loadDetail,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Gagal Memuat Berita',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loadDetail,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              : _detail == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.article_outlined,
                                  size: 44,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Data Berita Tidak Ditemukan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Berita mungkin telah dihapus atau tidak tersedia.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Foto Berita
                          if (_detail!.gambarUrl.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImageViewerPage(
                                      imageUrl: _detail!.gambarUrl,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                height: 230,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(19),
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        _detail!.gambarUrl,
                                        width: double.infinity,
                                        height: 230,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: const Color(0xFFF1F5F9),
                                            child: const Center(
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                size: 48,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.65),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.zoom_in_rounded,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Lihat Foto',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Konten Kartu Utama Berita
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
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
                                // Badge & Tanggal
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'BERITA DESA',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule_rounded,
                                          size: 14,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formatDate(_detail!.createdAt),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Judul Berita
                                Text(
                                  _detail!.judul,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 16),

                                // Label Isi Berita
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Isi Berita',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Teks HTML Berita
                                Html(
                                  data: _detail!.deskripsi,
                                  style: {
                                    'body': Style(
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      fontSize: FontSize(14.5),
                                      lineHeight: const LineHeight(1.6),
                                      color: const Color(0xFF334155),
                                    ),
                                    'p': Style(
                                      margin: Margins.only(bottom: 10),
                                    ),
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Informasi Lokasi / Wilayah jika tersedia
                          if (_detail!.wilayahInfo != null &&
                              _detail!.wilayahInfo!.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: AppTheme.primaryColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Informasi Wilayah',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(
                                      height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 12),
                                  ..._detail!.wilayahInfo!.entries.map((e) {
                                    final label = e.key.isNotEmpty
                                        ? '${e.key[0].toUpperCase()}${e.key.substring(1)}'
                                        : '';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            ': ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${e.value}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
