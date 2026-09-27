import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;

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
      appBar: AppBar(
        title: const Text('Detail Berita Desa'),
        backgroundColor: const Color(0xFF4A47DC),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadDetail,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A47DC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    ],
                  ),
                ))
              : _detail == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Data tidak tersedia',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Image
                          if (_detail!.gambarUrl.isNotEmpty)
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
                                height: 250,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    _detail!.gambarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 250,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              size: 64,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Gambar tidak tersedia',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  _detail!.judul,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                    height: 1.3,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Date
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A47DC)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: const Color(0xFF4A47DC),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDate(_detail!.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4A47DC),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Description
                                const Text(
                                  'Deskripsi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Html(
                                  data: _detail!.deskripsi,
                                  style: {
                                    'body': Style(
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      fontSize: FontSize(16),
                                      lineHeight: LineHeight.em(1.6),
                                      color: const Color(0xFF4A4A4A),
                                    ),
                                    'p': Style(margin: Margins.only(bottom: 8)),
                                  },
                                ),

                                // Comment section commented out
                                // if (_detail!.komentar.isNotEmpty) ...[
                                //   const SizedBox(height: 24),
                                //   const Text(
                                //     'Komentar',
                                //     style: TextStyle(
                                //       fontSize: 18,
                                //       fontWeight: FontWeight.w600,
                                //       color: Color(0xFF1A1A1A),
                                //     ),
                                //   ),
                                //   const SizedBox(height: 12),
                                //   Container(
                                //     padding: const EdgeInsets.all(16),
                                //     decoration: BoxDecoration(
                                //       color: Colors.grey[50],
                                //       borderRadius: BorderRadius.circular(12),
                                //       border: Border.all(
                                //         color: Colors.grey[200]!,
                                //       ),
                                //     ),
                                //     child: Text(
                                //       _detail!.komentar,
                                //       style: TextStyle(
                                //         fontSize: 14,
                                //         color: Colors.grey[700],
                                //         height: 1.5,
                                //       ),
                                //     ),
                                //   ),
                                // ],

                                // Location Info
                                if (_detail!.wilayahInfo != null &&
                                    _detail!.wilayahInfo!.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: const Color(0xFF4A47DC),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Lokasi',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        ..._detail!.wilayahInfo!.entries
                                            .map((e) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 12),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        margin: const EdgeInsets
                                                            .only(
                                                            top: 6, right: 12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFF4A47DC),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              '${e.key[0].toUpperCase()}${e.key.substring(1)}',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                    0xFF4A47DC),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              '${e.value}',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 16,
                                                                color: Color(
                                                                    0xFF4A4A4A),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 32),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
    );
  }
}
