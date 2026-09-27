import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/berita_desa_api_service.dart';
import 'package:ladimas/data/models/berita_desa_model.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/profile/profile_edit_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ladimas/presentation/pages/berita-desa/berita_desa_detail_page.dart';
import 'package:ladimas/presentation/pages/berita-desa/berita_desa_form_page.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:ladimas/presentation/pages/pengumuman/image_viewer_page.dart';

class BeritaDesaPage extends StatefulWidget {
  final Penduduk? penduduk;
  const BeritaDesaPage({Key? key, this.penduduk}) : super(key: key);

  @override
  State<BeritaDesaPage> createState() => _BeritaDesaPageState();
}

class _BeritaDesaPageState extends State<BeritaDesaPage> {
  late final BeritaDesaApiService _beritaDesaApiService;
  List<BeritaDesaModel> _beritaDesa = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _beritaDesaApiService = BeritaDesaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _loadBeritaDesa();
  }

  Future<void> _loadBeritaDesa() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final int? villageId = await _getVillageId();
      print('BeritaDesaPage - Village ID: $villageId');

      final berita = await _beritaDesaApiService.getBeritaDesa(
        villageId: villageId,
      );

      print('BeritaDesaPage - Berita Count: ${berita.length}');
      for (var b in berita) {
        print(
            'BeritaDesaPage - Berita: ${b.judul} (ID: ${b.id}, Village: ${b.villageId})');
      }

      if (mounted) {
        setState(() {
          _beritaDesa = berita;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      print('BeritaDesaPage - Auth error: ${e.message}');
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } on ServerException catch (e) {
      print('BeritaDesaPage - Server error: ${e.message}');
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('BeritaDesaPage - General error: $e');
      if (mounted) {
        setState(() {
          _error = 'Terjadi kesalahan: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<int?> _getVillageId() async {
    try {
      String? nik = widget.penduduk?.nik;
      if (nik == null || nik.isEmpty) {
        final creds = await AuthLocalStorage().getUserCredentials();
        nik = creds?['nik']?.toString();
      }
      if (nik == null || nik.isEmpty) {
        print('BeritaDesaPage - NIK is empty');
        return null;
      }

      print('BeritaDesaPage - Getting village ID for NIK: $nik');

      // Optimasi: ambil 1 record via endpoint detail NIK (bukan tarik /all-citizens).
      final response = await http.get(
        Uri.parse('${AppConstants.goBaseUrl}/api/citizens/$nik'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print(
            'BeritaDesaPage - Error getting village ID: ${response.statusCode}');
        return null;
      }

      final dynamic responseData = json.decode(response.body);
      final citizen = (responseData is Map<String, dynamic>)
          ? (responseData['data'] as Map<String, dynamic>?)
          : null;
      if (citizen == null) {
        print('BeritaDesaPage - Invalid response structure');
        return null;
      }

      final dynamic vId = citizen['village_id'];
      print('BeritaDesaPage - Found citizen with village_id: $vId');
      if (vId is int) return vId;
      return int.tryParse('$vId');
    } catch (e) {
      print('BeritaDesaPage - Exception in _getVillageId: $e');
    }
    return null;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pengaturan',
          style:
              TextStyle(color: Color(0xFF4A47DC), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF4A47DC)),
              title: const Text('Edit Data Diri'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileEditPage(penduduk: widget.penduduk!),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar'),
              onTap: () {
                Navigator.pop(ctx);
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4A47DC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('TUTUP',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi',
          style:
              TextStyle(color: Color(0xFF4A47DC), fontWeight: FontWeight.bold),
        ),
        content: const Text('Apakah Anda yakin ingin keluar?',
            style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('BATAL',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutEvent());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('KELUAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: SafeArea(
          child: Column(
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat datang di',
                      style: TextStyle(fontSize: 16, color: Color(0xFF4A47DC)),
                    ),
                    const Text(
                      'LADIMAS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A47DC),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Layanan Digital Masyarakat',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A47DC),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // Content Section
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadBeritaDesa,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A47DC),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          )
                        : _beritaDesa.isEmpty
                            ? const Center(
                                child: Text('Belum ada berita desa'),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBeritaDesa,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _beritaDesa.length,
                                  itemBuilder: (context, index) {
                                    final berita = _beritaDesa[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BeritaDesaDetailPage(
                                                      id: berita.id),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (berita.gambarUrl.isNotEmpty)
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ImageViewerPage(
                                                        imageUrl:
                                                            berita.gambarUrl,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Image.network(
                                                  berita.gambarUrl,
                                                  width: double.infinity,
                                                  height: 200,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      width: double.infinity,
                                                      height: 200,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.error_outline,
                                                        color: Colors.grey,
                                                        size: 50,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    berita.judul,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Html(
                                                    data: berita.deskripsi,
                                                    style: {
                                                      'body': Style(
                                                        margin: Margins.zero,
                                                        padding:
                                                            HtmlPaddings.zero,
                                                        fontSize: FontSize(14),
                                                        lineHeight:
                                                            LineHeight.em(1.3),
                                                      ),
                                                      'p': Style(
                                                          margin: Margins.only(
                                                              bottom: 6)),
                                                    },
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Tanggal: ${_formatDate(berita.createdAt)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: const Color(0xFF4A47DC),
          unselectedItemColor: Colors.grey,
          currentIndex: 0, // Berita aktif
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.newspaper), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Layanan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Setting'),
          ],
          onTap: (index) {
            if (index == 1) {
              if (widget.penduduk != null) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PendudukHomePage(penduduk: widget.penduduk!),
                  ),
                );
              } else {
                MessageService.showErrorSnackBar(
                  context,
                  'Data penduduk tidak tersedia',
                );
              }
            } else if (index == 2) {
              _showSettingsDialog(context);
            }
            // Index 0 (Berita) tidak perlu aksi karena sudah di halaman ini
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BeritaDesaFormPage()),
            );
            if (result == true) {
              _loadBeritaDesa();
            }
          },
          backgroundColor: const Color(0xFF4A47DC),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
