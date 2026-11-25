import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/data/models/pemerintah_desa_model.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/village_stats_api_service.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

class ProfilDesaPage extends StatefulWidget {
  final Penduduk penduduk;

  const ProfilDesaPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<ProfilDesaPage> createState() => _ProfilDesaPageState();
}

class _ProfilDesaPageState extends State<ProfilDesaPage> {
  // Data state
  PemerintahDesaModel? _pemdes;
  bool _isLoadingPemdes = true;
  bool _isLoadingGoStats = false;
  String? _villageName;
  bool _isProfilDesaExpanded =
      true; // Default expanded untuk menampilkan semua data

  // Touch indices untuk pie charts
  int _touchedIndex = -1;
  int _touchedAgeIndex = -1;
  int _touchedEducationIndex = -1;
  int _touchedReligionIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoadingPemdes = true;
      });
    }

    await _loadProfilDesa(forceRefresh: forceRefresh);
  }

  Future<void> _loadProfilDesa({bool forceRefresh = false}) async {
    final startTime = DateTime.now();

    if (forceRefresh) {
      print('🔄 [ProfilDesa] Force refresh - akan load data baru dari API...');
    } else {
      print('🔵 [ProfilDesa] Loading Profil Desa data...');
    }

    print('👤 [ProfilDesa] User NIK: ${widget.penduduk.nik}');
    print('👤 [ProfilDesa] User Name: ${widget.penduduk.name}');

    try {
      final authLocalStorage = AuthLocalStorage();

      // OPTIMASI: Cek cache terlebih dahulu (jika tidak force refresh)
      if (!forceRefresh) {
        final cacheCheckStart = DateTime.now();
        final cachedData = await authLocalStorage.getCachedPemerintahDesa();
        print(
            '⏱️  [ProfilDesa] Cache check: ${DateTime.now().difference(cacheCheckStart).inMilliseconds}ms');

        if (cachedData != null && cachedData.isNotEmpty) {
          // Gunakan cache untuk tampilan cepat
          final data = PemerintahDesaModel.fromJson(cachedData);

          if (mounted) {
            setState(() {
              _pemdes = data;
              _isLoadingPemdes = false;
            });
          }

          // Load nama desa di background (non-blocking)
          _loadVillageNameFromData(data);

          // Ambil statistik langsung dari Go (lebih cepat & konsisten)
          _loadGoVillageStatsFromPemdes(data);

          print(
              '✅ [ProfilDesa] Loaded from cache: ${DateTime.now().difference(startTime).inMilliseconds}ms');

          // Refresh data di background (optional)
          _refreshProfilDesaInBackground();
          return;
        }
      }

      // Ambil data dari API jika tidak ada cache atau force refresh
      final rawToken = await authLocalStorage.getStoredToken();

      if (rawToken == null || rawToken.isEmpty) {
        throw Exception('Token tidak tersedia');
      }

      print('🔑 [ProfilDesa] Token available: ${rawToken.length} chars');

      String bearer = rawToken;
      if (bearer.contains('|')) {
        final parts = bearer.split('|');
        if (parts.length > 1) bearer = parts[1].trim();
      }

      final base = AppConstants.authApiUrl;
      final url = '$base/user/profil-desa';

      print('🌐 [ProfilDesa] Fetching from: $url');
      final apiStartTime = DateTime.now();

      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearer',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      print('📡 [ProfilDesa] Response status: ${resp.statusCode}');
      if (resp.statusCode != 200) {
        print('❌ [ProfilDesa] Response body: ${resp.body}');
      }

      print(
          '⏱️  [ProfilDesa] API response in ${DateTime.now().difference(apiStartTime).inMilliseconds}ms');

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(resp.body);
        final data = PemerintahDesaModel.fromJson(jsonData);

        // Cache data untuk kunjungan berikutnya
        await authLocalStorage.cachePemerintahDesa(jsonData);
        print('✅ [ProfilDesa] Data cached successfully');

        if (mounted) {
          setState(() {
            _pemdes = data;
            _isLoadingPemdes = false;
          });
        }

        // Load nama desa di background (non-blocking)
        _loadVillageNameFromData(data);

        // Ambil statistik langsung dari Go (lebih cepat & konsisten)
        _loadGoVillageStatsFromPemdes(data);

        final loadTime = DateTime.now().difference(startTime).inMilliseconds;
        if (forceRefresh) {
          print('✅ [ProfilDesa] Force refresh completed in ${loadTime}ms');
        } else {
          print('✅ [ProfilDesa] Total load time: ${loadTime}ms');
        }
      } else {
        throw Exception('Failed to load profil desa: ${resp.statusCode}');
      }
    } catch (e) {
      print('❌ [ProfilDesa] Error loading Profil Desa: $e');
      if (mounted) {
        setState(() {
          _pemdes = null;
          _isLoadingPemdes = false;
        });
      }
    }
  }

  void _loadGoVillageStatsFromPemdes(PemerintahDesaModel data) {
    final villageId = (data.pemerintahVillagesId ?? data.villageId);
    if (villageId == null || villageId <= 0) return;
    _loadGoVillageStats(villageId);
  }

  Future<void> _loadGoVillageStats(int villageId) async {
    // Hindari spam request
    if (_isLoadingGoStats) return;

    if (mounted) {
      setState(() {
        _isLoadingGoStats = true;
      });
    }

    try {
      final svc = VillageStatsApiService(client: http.Client());
      final bundle = await svc.fetchVillageStats(villageId);

      if (!mounted) return;
      if (_pemdes == null) {
        setState(() {
          _isLoadingGoStats = false;
        });
        return;
      }

      // Override statistik di model agar seluruh UI yang sudah ada otomatis pakai data Go.
      final p = _pemdes!;
      setState(() {
        _pemdes = PemerintahDesaModel(
          villageId: p.villageId,
          kepalaDesa: p.kepalaDesa,
          perangkatDesa: p.perangkatDesa,
          dataWilayah: p.dataWilayah,
          statistikPenduduk: bundle.statistikPenduduk,
          statistikUmur: bundle.statistikUmur,
          statistikPendidikan: bundle.statistikPendidikan,
          statistikAgama: bundle.statistikAgama,
          usahaDesa: p.usahaDesa,
          saranaUmum: p.saranaUmum,
          saranaUmumByKategori: p.saranaUmumByKategori,
          kesenianBudaya: p.kesenianBudaya,
          abdes: p.abdes,
          warungkuKlasifikasiJenis: p.warungkuKlasifikasiJenis,
          pemerintahAlamat: p.pemerintahAlamat,
          pemerintahKontak: p.pemerintahKontak,
          pemerintahProvinceId: p.pemerintahProvinceId,
          pemerintahDistrictId: p.pemerintahDistrictId,
          pemerintahSubDistrictId: p.pemerintahSubDistrictId,
          pemerintahVillagesId: p.pemerintahVillagesId,
        );
        _isLoadingGoStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Jangan ganggu UI utama: cukup log saja dan biarkan fallback Laravel tetap tampil.
      print('❌ [ProfilDesa] Go stats error: $e');
      setState(() {
        _isLoadingGoStats = false;
      });
    }
  }

  /// Load nama desa dari data
  void _loadVillageNameFromData(PemerintahDesaModel data) {
    final String? villageIdStr =
        (data.pemerintahVillagesId ?? data.villageId)?.toString();
    if (villageIdStr != null) {
      Future.microtask(() async {
        try {
          final village = await WilayahService().getVillage(
              villageIdStr,
              data.pemerintahSubDistrictId?.toString(),
              data.pemerintahDistrictId?.toString());
          if (mounted && village != null) {
            setState(() {
              _villageName =
                  (village['name'] ?? village['nama'] ?? '').toString();
            });
            print('✅ [ProfilDesa] Village name loaded: $_villageName');
          }
        } catch (e) {
          print('❌ [ProfilDesa] Error loading village name: $e');
        }
      });
    }
  }

  /// Refresh data di background setelah cache ditampilkan
  Future<void> _refreshProfilDesaInBackground() async {
    try {
      print('🔄 [ProfilDesa] Background refresh started...');
      final authLocalStorage = AuthLocalStorage();
      final rawToken = await authLocalStorage.getStoredToken();

      if (rawToken == null || rawToken.isEmpty) {
        print('⚠️  [ProfilDesa] No token for background refresh');
        return;
      }

      String bearer = rawToken;
      if (bearer.contains('|')) {
        final parts = bearer.split('|');
        if (parts.length > 1) bearer = parts[1].trim();
      }

      final base = AppConstants.authApiUrl;
      final url = '$base/user/profil-desa';

      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearer',
          'X-API-Key': AppConstants.apiKey,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('{"status": "TIMEOUT"}', 408),
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(resp.body);
        final data = PemerintahDesaModel.fromJson(jsonData);

        // Update cache dengan data terbaru
        await authLocalStorage.cachePemerintahDesa(jsonData);

        // Update UI jika masih mounted
        if (mounted) {
          setState(() {
            _pemdes = data;
          });
          _loadVillageNameFromData(data);
        }

        print('✅ [ProfilDesa] Background refresh completed');
      } else {
        print('⚠️  [ProfilDesa] Background refresh failed: ${resp.statusCode}');
      }
    } catch (e) {
      print('⚠️  [ProfilDesa] Background refresh error: $e');
      // Tidak perlu update UI jika background refresh gagal
    }
  }

  String? _resolveStorageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    String url = rawUrl.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('file://')) {
      url = url.substring(7);
    }
    String base = AppConstants.storageUrl.trim();
    if (base.isEmpty) return null;
    if (!base.endsWith('/')) base = '$base/';
    final path = url.startsWith('/') ? url.substring(1) : url;
    return '$base$path';
  }

  Widget _buildHeaderSection() {
    final double topPadding = MediaQuery.of(context).padding.top + 20;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Publik',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoadingPemdes
                        ? 'Profil Desa'
                        : (() {
                            final vn = _villageName;
                            return (vn != null && vn.isNotEmpty)
                                ? 'Profil Desa $vn'
                                : 'Profil Desa';
                          })(),
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(
            _isLoadingPemdes
                ? 'Profil Desa'
                : (() {
                    final vn = _villageName;
                    return (vn != null && vn.isNotEmpty)
                        ? 'Profil Desa $vn'
                        : 'Profil Desa';
                  })(),
            style: const TextStyle(
              color:
                  AppTheme.primaryColor, // Sesuai dengan warna AppBar Warungku
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: AppTheme.primaryColor,
          child: _isLoadingPemdes
              ? const Center(child: CircularProgressIndicator())
              : _pemdes == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Gagal memuat data profil desa',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _loadData(forceRefresh: true),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildProfilDesaCards(),
                      ),
                    ),
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: 3, // Profil Desa
          items: [
            AppBottomNavBar.item(icon: Icons.home_outlined, label: 'Beranda'),
            AppBottomNavBar.item(icon: Icons.storefront, label: 'Warungku'),
            AppBottomNavBar.item(
                icon: Icons.grid_view_outlined, label: 'Informasi'),
            AppBottomNavBar.item(
                icon: Icons.account_balance, label: 'Profil Desa'),
            AppBottomNavBar.item(
                icon: Icons.receipt_long_outlined, label: 'Tagihan'),
            AppBottomNavBar.item(
                icon: Icons.description_outlined, label: 'Portal'),
          ],
          onTap: (index) {
            // Logika navigasi tetap sama
            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BerandaPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WarungkuPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 2:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PendudukHomePage(
                      penduduk: widget.penduduk,
                      initialTabIndex: 0,
                    ),
                  ),
                );
                break;
              case 3:
                break;
              case 4:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TagihanPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 5:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DocumentServicesWebViewPage(penduduk: widget.penduduk),
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }

  // Helper untuk membungkus konten dalam card modern
  Widget _buildModernCard(
      {required String title,
      required IconData icon,
      required Widget content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildProfilDesaCards() {
    return Column(
      children: [
        // 1. Wilayah (Selalu Tampil)
        _buildModernCard(
          title: 'Wilayah Desa',
          icon: Icons.map_outlined,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                  'Luas Wilayah',
                  _pemdes!.dataWilayah.isNotEmpty
                      ? '${_pemdes!.dataWilayah.first.luasWilayah ?? '-'} m²'
                      : '-'),
              const SizedBox(height: 12),
              _buildInfoRow(
                  'Jumlah Dusun',
                  _pemdes!.dataWilayah.isNotEmpty
                      ? (_pemdes!.dataWilayah.first.jumlahDusun ?? 0).toString()
                      : '-'),
              const SizedBox(height: 12),
              _buildInfoRow(
                  'Jumlah RT',
                  _pemdes!.dataWilayah.isNotEmpty
                      ? (_pemdes!.dataWilayah.first.jumlahRT ?? 0).toString()
                      : '-'),
              const SizedBox(height: 16),
              _buildBatasWilayah(_pemdes!.dataWilayah.isNotEmpty
                  ? _pemdes!.dataWilayah.first.batasWilayah
                  : null),
            ],
          ),
        ),

        // Konten tambahan ditampilkan saat expand
        if (_isProfilDesaExpanded) ...[
          // 2. Kependudukan (Gender & Usia)
          _buildModernCard(
            title: 'Kependudukan & Usia',
            icon: Icons.people_alt_outlined,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Berdasarkan Jenis Kelamin',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildPieChart(),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildModernInfoRow(
                              'Laki-laki',
                              (_pemdes!.statistikPenduduk?.male ?? 0)
                                  .toString(),
                              icon: Icons.male,
                              color: const Color(0xFF2196F3)),
                          const SizedBox(height: 8),
                          _buildModernInfoRow(
                              'Perempuan',
                              (_pemdes!.statistikPenduduk?.female ?? 0)
                                  .toString(),
                              icon: Icons.female,
                              color: const Color(0xFFE91E63)),
                          const SizedBox(height: 8),
                          _buildModernInfoRow(
                              'Total',
                              (_pemdes!.statistikPenduduk?.total ?? 0)
                                  .toString(),
                              icon: Icons.group,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),
                const Text('Berdasarkan Usia',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAgePieChart(),
                    const SizedBox(width: 24),
                    Expanded(child: _buildAgeInfoColumn()),
                  ],
                ),
              ],
            ),
          ),

          // 3. Statistik Pendidikan
          _buildModernCard(
            title: 'Statistik Pendidikan',
            icon: Icons.school_outlined,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildEducationPieChart()),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12)),
                  child: _buildEducationInfoColumn(),
                ),
              ],
            ),
          ),

          // 4. Statistik Agama
          _buildModernCard(
            title: 'Statistik Agama',
            icon: Icons.balance_outlined,
            content: Row(
              children: [
                _buildReligionPieChart(),
                const SizedBox(width: 24),
                Expanded(child: _buildReligionInfoColumn()),
              ],
            ),
          ),

          // 5. Potensi & Usaha
          _buildModernCard(
            title: 'Potensi & Usaha Desa',
            icon: Icons.storefront_outlined,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unit Usaha Masyarakat',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333))),
                const SizedBox(height: 8),
                ...(() {
                  final Map<String, int> counts = {};
                  final Map<String, String> display = {};
                  for (final w
                      in (_pemdes?.warungkuKlasifikasiJenis ?? const [])) {
                    final raw = w.jenis.trim();
                    final key = raw.isEmpty ? 'lainnya' : raw.toLowerCase();
                    final int val = (w.totalBarang is int && w.totalBarang > 0)
                        ? w.totalBarang
                        : 1;
                    counts[key] = (counts[key] ?? 0) + val;
                    if (!display.containsKey(key)) {
                      display[key] = key.isEmpty
                          ? 'Lainnya'
                          : key[0].toUpperCase() + key.substring(1);
                    }
                  }
                  if (counts.isEmpty) {
                    return <Widget>[
                      const Text('Belum ada data potensi',
                          style: TextStyle(color: Color(0xFF666666)))
                    ];
                  }
                  final keys = counts.keys.toList()
                    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
                  return [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: keys
                            .map((k) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildInfoRow(
                                      display[k] ?? k, counts[k]!.toString()),
                                ))
                            .toList(),
                      ),
                    )
                  ];
                }()),
                const SizedBox(height: 16),
                _buildUsahaDesaGrouped(_pemdes!.usahaDesa),
              ],
            ),
          ),

          // 6. Fasilitas Umum
          _buildModernCard(
            title: 'Fasilitas & Sarana Umum',
            icon: Icons.business_outlined,
            content: _buildSaranaUmumByKategori(_pemdes!.saranaUmumByKategori),
          ),

          // 7. Budaya & ABDES
          _buildModernCard(
            title: 'Sosial Budaya & ABDES',
            icon: Icons.color_lens_outlined,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKesenianGrouped(_pemdes!.kesenianBudaya),
                const SizedBox(height: 16),
                _buildAbdesGrouped(_pemdes!.abdes),
              ],
            ),
          ),
        ],

        // Expand/Collapse Button (Dibuat full width dan rapi)
        GestureDetector(
          onTap: () {
            setState(() {
              _isProfilDesaExpanded = !_isProfilDesaExpanded;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isProfilDesaExpanded
                      ? 'Sembunyikan Detail'
                      : 'Lihat Semua Detail',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isProfilDesaExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernInfoRow(String label, String value,
      {required IconData icon, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  Widget _buildBatasWilayah(String? raw) {
    final String source = (raw ?? '').trim();
    if (source.isEmpty) {
      return const SizedBox.shrink();
    }

    final cleaned =
        source.replaceAll('{', '').replaceAll('}', '').replaceAll('\n', ' ');

    final Map<String, String> dir = {};
    for (final part in cleaned.split(',')) {
      final seg = part.split(':');
      if (seg.isEmpty) continue;
      final key = seg.first.trim().toLowerCase();
      final value = seg.length > 1 ? seg.sublist(1).join(':').trim() : '-';
      if (key.isNotEmpty) dir[key] = value.isEmpty ? '-' : value;
    }

    String v(String k) => dir[k] ?? '-';

    Widget borderItem(String title, String val, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(title,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                val,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1E1E)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Batas Wilayah',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333))),
        const SizedBox(height: 12),
        Row(
          children: [
            borderItem('Utara', v('utara'), Icons.arrow_upward),
            const SizedBox(width: 8),
            borderItem('Selatan', v('selatan'), Icons.arrow_downward),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            borderItem('Timur', v('timur'), Icons.arrow_forward),
            const SizedBox(width: 8),
            borderItem('Barat', v('barat'), Icons.arrow_back),
          ],
        ),
      ],
    );
  }

  Widget _buildUsahaDesaGrouped(List<UsahaDesa> usaha) {
    if (usaha.isEmpty) return const SizedBox.shrink();

    final Map<String, List<UsahaDesa>> grouped = {};
    for (final u in usaha) {
      final String jenis = (u.jenis ?? 'Usaha Desa').trim();
      if (u.namaUsaha.trim().isEmpty) continue;
      grouped.putIfAbsent(jenis, () => <UsahaDesa>[]).add(u);
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daftar Usaha Desa',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              entry.key,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          for (final item in entry.value)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  if ((item.photoUrl ?? '').trim().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _resolveStorageUrl(item.photoUrl) ?? item.photoUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fallbackImage(Icons.store),
                      ),
                    )
                  else
                    _fallbackImage(Icons.store),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.namaUsaha,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSaranaUmumByKategori(List<SaranaUmumByKategori> groups) {
    if (groups.isEmpty) {
      return const Text('Belum ada data sarana umum',
          style: TextStyle(color: Color(0xFF666666)));
    }

    final Map<String, Map<String, List<SaranaRingkas>>> byJenis = {};
    for (final g in groups) {
      final String jenis = (g.kategori.jenisSarana ?? 'Sarana Umum').trim();
      final String kategori = (g.kategori.kategori ?? '-').trim();
      for (final s in g.sarana) {
        if (s.namaSarana.trim().isEmpty) continue;
        byJenis.putIfAbsent(jenis, () => <String, List<SaranaRingkas>>{});
        byJenis[jenis]!.putIfAbsent(kategori, () => <SaranaRingkas>[]).add(s);
      }
    }

    if (byJenis.isEmpty) {
      return const Text('Belum ada data sarana umum',
          style: TextStyle(color: Color(0xFF666666)));
    }

    final jenisKeys = byJenis.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final jenis in jenisKeys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(
              jenis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          ...(() {
            final kategoriMap = byJenis[jenis]!;
            final kategoriKeys = kategoriMap.keys.toList()..sort();
            return kategoriKeys.map((kat) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kat,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in kategoriMap[kat]!)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          if ((item.photoUrl ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _resolveStorageUrl(item.photoUrl) ??
                                    item.photoUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _fallbackImage(Icons.place),
                              ),
                            )
                          else
                            _fallbackImage(Icons.place),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.namaSarana,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              );
            }).toList();
          }()),
        ],
      ],
    );
  }

  Widget _buildKesenianGrouped(List<KesenianBudaya> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final Map<String, List<KesenianBudaya>> grouped = {};
    for (final k in items) {
      if (k.namaKesenian.trim().isEmpty) continue;
      final String key = 'nama:${(k.jenis ?? 'Kesenian').trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => <KesenianBudaya>[]).add(k);
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kesenian dan Budaya',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor)),
        const SizedBox(height: 12),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              () {
                final name = entry.key.substring(5);
                return name.isNotEmpty
                    ? name[0].toUpperCase() + name.substring(1)
                    : 'Kesenian';
              }(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ),
          for (final item in entry.value)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  if ((item.photoUrl ?? '').trim().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _resolveStorageUrl(item.photoUrl) ?? item.photoUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fallbackImage(Icons.theaters),
                      ),
                    )
                  else
                    _fallbackImage(Icons.theaters),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.namaKesenian,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAbdesGrouped(List<Abdes> items) {
    if (items.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 32),
          Text('ABDES',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor)),
          SizedBox(height: 8),
          Text('Belum ada data ABDES',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
        ],
      );
    }

    final Map<String, List<String>> grouped = {};
    for (final a in items) {
      final String jenis = (a.jenis.isNotEmpty ? a.jenis : 'ABDES');
      final String label = () {
        final String kat = a.kategori;
        final String? anggaran = a.jumlahAnggaran;
        if (anggaran != null && anggaran.isNotEmpty) {
          return '$kat — Rp $anggaran';
        }
        return kat;
      }();
      final String key = 'nama:${jenis.trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => <String>[]).add(label);
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text('ABDES',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor)),
        const SizedBox(height: 12),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              () {
                final name = entry.key.substring(5);
                return name.isNotEmpty
                    ? name[0].toUpperCase() + name.substring(1)
                    : 'ABDES';
              }(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ),
          for (final nama in entry.value)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nama,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF333333)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _fallbackImage(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF9E9E9E)),
    );
  }

  // ---------------------------------------------------------------------------
  // Chart Builders & Data Helpers
  // ---------------------------------------------------------------------------

  Widget _buildPieChart() {
    return Container(
      width: 120,
      height: 120,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  return;
                }
                final touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
                if (_touchedIndex == touchedIndex) {
                  _touchedIndex = -1;
                } else {
                  _touchedIndex = touchedIndex;
                }
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 20,
          sections: _showingSections(),
        ),
      ),
    );
  }

  List<PieChartSectionData> _showingSections() {
    final lakiLaki = _pemdes?.statistikPenduduk?.male ?? 0;
    final perempuan = _pemdes?.statistikPenduduk?.female ?? 0;
    final total = lakiLaki + perempuan;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: const Color(0xFF2196F3),
          value: 1,
          title: '',
          radius: 40,
        ),
      ];
    }
    final lakiLakiPercent = (lakiLaki / total * 100).round();
    final perempuanPercent = (perempuan / total * 100).round();

    return List.generate(2, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 14.0 : 12.0;
      final radius = isTouched ? 50.0 : 40.0;

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: const Color(0xFF2196F3),
            value: lakiLaki.toDouble(),
            title: '$lakiLakiPercent%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        case 1:
          return PieChartSectionData(
            color: const Color(0xFFE91E63),
            value: perempuan.toDouble(),
            title: '$perempuanPercent%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        default:
          throw Exception('Invalid section index');
      }
    });
  }

  Widget _buildAgePieChart() {
    final statistikUmur = _pemdes?.statistikUmur;
    if (statistikUmur == null) {
      return const SizedBox(width: 120, height: 120);
    }

    final total = statistikUmur.totalWithAge;
    if (total == 0) return const SizedBox(width: 120, height: 120);

    return Container(
      width: 120,
      height: 120,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  return;
                }
                final touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
                if (_touchedAgeIndex == touchedIndex) {
                  _touchedAgeIndex = -1;
                } else {
                  _touchedAgeIndex = touchedIndex;
                }
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 20,
          sections: _showingAgeSections(
              statistikUmur.usia0_17,
              statistikUmur.usia18_30,
              statistikUmur.usia31_45,
              statistikUmur.usia46_60,
              statistikUmur.usia61_plus,
              total),
        ),
      ),
    );
  }

  List<PieChartSectionData> _showingAgeSections(int usia0_17, int usia18_30,
      int usia31_45, int usia46_60, int usia61_plus, int total) {
    if (total == 0) {
      return [
        PieChartSectionData(
            color: const Color(0xFF2196F3), value: 1, title: '', radius: 40),
      ];
    }

    return List.generate(5, (i) {
      final isTouched = i == _touchedAgeIndex;
      final radius = isTouched ? 50.0 : 40.0;
      final fontSize =
          isTouched ? 12.0 : 0.0; // Sembunyikan jika tidak di-touch agar rapi

      switch (i) {
        case 0:
          return PieChartSectionData(
              color: const Color(0xFF2196F3),
              value: usia0_17.toDouble(),
              title: '${(usia0_17 / total * 100).round()}%',
              radius: radius,
              titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white));
        case 1:
          return PieChartSectionData(
              color: const Color(0xFF4CAF50),
              value: usia18_30.toDouble(),
              title: '${(usia18_30 / total * 100).round()}%',
              radius: radius,
              titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white));
        case 2:
          return PieChartSectionData(
              color: const Color(0xFFFF9800),
              value: usia31_45.toDouble(),
              title: '${(usia31_45 / total * 100).round()}%',
              radius: radius,
              titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white));
        case 3:
          return PieChartSectionData(
              color: const Color(0xFF9C27B0),
              value: usia46_60.toDouble(),
              title: '${(usia46_60 / total * 100).round()}%',
              radius: radius,
              titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white));
        case 4:
          return PieChartSectionData(
              color: const Color(0xFFE91E63),
              value: usia61_plus.toDouble(),
              title: '${(usia61_plus / total * 100).round()}%',
              radius: radius,
              titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white));
        default:
          throw Error();
      }
    });
  }

  Widget _buildAgeInfoColumn() {
    return Column(
      children: [
        _buildLegendItem(
            '0-17 thn',
            (_pemdes!.statistikUmur?.usia0_17 ?? 0).toString(),
            const Color(0xFF2196F3)),
        _buildLegendItem(
            '18-30 thn',
            (_pemdes!.statistikUmur?.usia18_30 ?? 0).toString(),
            const Color(0xFF4CAF50)),
        _buildLegendItem(
            '31-45 thn',
            (_pemdes!.statistikUmur?.usia31_45 ?? 0).toString(),
            const Color(0xFFFF9800)),
        _buildLegendItem(
            '46-60 thn',
            (_pemdes!.statistikUmur?.usia46_60 ?? 0).toString(),
            const Color(0xFF9C27B0)),
        _buildLegendItem(
            '61+ thn',
            (_pemdes!.statistikUmur?.usia61_plus ?? 0).toString(),
            const Color(0xFFE91E63)),
        const Divider(height: 16),
        _buildLegendItem(
            'Total',
            (_pemdes!.statistikUmur?.totalWithAge ?? 0).toString(),
            Colors.grey),
      ],
    );
  }

  Widget _buildEducationPieChart() {
    final statistikPendidikan = _pemdes?.statistikPendidikan;
    if (statistikPendidikan == null) return const SizedBox();
    final total = statistikPendidikan.totalWithEducation;
    if (total == 0) return const SizedBox();

    return Container(
      width: 160,
      height: 160,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) return;
                final touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
                _touchedEducationIndex =
                    _touchedEducationIndex == touchedIndex ? -1 : touchedIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: _showingEducationSections(statistikPendidikan, total),
        ),
      ),
    );
  }

  List<PieChartSectionData> _showingEducationSections(
      StatistikPendidikan pendidikan, int total) {
    if (total == 0) {
      return [
        PieChartSectionData(
            color: const Color(0xFF2196F3), value: 1, title: '', radius: 40),
      ];
    }
    final data = [
      (pendidikan.tidakSekolah, const Color(0xFF2196F3)),
      (pendidikan.belumTamatSD, const Color(0xFF4CAF50)),
      (pendidikan.tamatSD, const Color(0xFFFF9800)),
      (pendidikan.sltp, const Color(0xFF9C27B0)),
      (pendidikan.slta, const Color(0xFFE91E63)),
      (pendidikan.diplomaI, const Color(0xFF00BCD4)),
      (pendidikan.diplomaIII, const Color(0xFF795548)),
      (pendidikan.diplomaIV, const Color(0xFF607D8B)),
      (pendidikan.strataIII, const Color(0xFF3F51B5)),
      (pendidikan.lainnya, const Color(0xFF9E9E9E)),
    ].where((item) => item.$1 > 0).toList();

    return List.generate(data.length, (i) {
      final item = data[i];
      final isTouched = i == _touchedEducationIndex;
      final radius = isTouched ? 60.0 : 50.0;
      final percent = (item.$1 / total * 100).round();

      return PieChartSectionData(
        color: item.$2,
        value: item.$1.toDouble(),
        title: isTouched ? '$percent%' : '',
        radius: radius,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  Widget _buildEducationInfoColumn() {
    final p = _pemdes?.statistikPendidikan;
    if (p == null) return const SizedBox();

    return Column(
      children: [
        _buildLegendItem('Tidak Sekolah', p.tidakSekolah.toString(),
            const Color(0xFF2196F3)),
        _buildLegendItem(
            'Belum SD', p.belumTamatSD.toString(), const Color(0xFF4CAF50)),
        _buildLegendItem(
            'Tamat SD', p.tamatSD.toString(), const Color(0xFFFF9800)),
        _buildLegendItem(
            'SMP/Sederajat', p.sltp.toString(), const Color(0xFF9C27B0)),
        _buildLegendItem(
            'SMA/Sederajat', p.slta.toString(), const Color(0xFFE91E63)),
        _buildLegendItem(
            'Diploma I/II', p.diplomaI.toString(), const Color(0xFF00BCD4)),
        _buildLegendItem(
            'Diploma III', p.diplomaIII.toString(), const Color(0xFF795548)),
        _buildLegendItem(
            'S1/D4', p.diplomaIV.toString(), const Color(0xFF607D8B)),
        _buildLegendItem(
            'S2/S3', p.strataIII.toString(), const Color(0xFF3F51B5)),
        _buildLegendItem(
            'Lainnya', p.lainnya.toString(), const Color(0xFF9E9E9E)),
        const Divider(height: 16),
        _buildLegendItem('Total', p.totalWithEducation.toString(), Colors.grey),
      ],
    );
  }

  Widget _buildReligionPieChart() {
    final agama = _pemdes?.statistikAgama;
    if (agama == null) return const SizedBox(width: 120, height: 120);
    final total = agama.totalWithReligion;
    if (total == 0) return const SizedBox(width: 120, height: 120);

    return Container(
      width: 120,
      height: 120,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) return;
                final touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
                _touchedReligionIndex =
                    _touchedReligionIndex == touchedIndex ? -1 : touchedIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 20,
          sections: _showingReligionSections(agama, total),
        ),
      ),
    );
  }

  List<PieChartSectionData> _showingReligionSections(
      StatistikAgama agama, int total) {
    final data = [
      (agama.islam, const Color(0xFF2196F3)),
      (agama.kristen, const Color(0xFF4CAF50)),
      (agama.katolik, const Color(0xFF9C27B0)),
      (agama.hindu, const Color(0xFFFF9800)),
      (agama.buddha, const Color(0xFFE91E63)),
      (agama.konghucu, const Color(0xFF00BCD4)),
      (agama.lainnya, const Color(0xFF9E9E9E)),
    ].where((item) => item.$1 > 0).toList();

    return List.generate(data.length, (i) {
      final item = data[i];
      final isTouched = i == _touchedReligionIndex;
      final radius = isTouched ? 50.0 : 40.0;
      final percent = (item.$1 / total * 100).round();

      return PieChartSectionData(
        color: item.$2,
        value: item.$1.toDouble(),
        title: isTouched ? '$percent%' : '',
        radius: radius,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  Widget _buildReligionInfoColumn() {
    final a = _pemdes?.statistikAgama;
    if (a == null) return const SizedBox();

    return Column(
      children: [
        _buildLegendItem('Islam', a.islam.toString(), const Color(0xFF2196F3)),
        _buildLegendItem(
            'Kristen', a.kristen.toString(), const Color(0xFF4CAF50)),
        _buildLegendItem(
            'Katolik', a.katolik.toString(), const Color(0xFF9C27B0)),
        _buildLegendItem('Hindu', a.hindu.toString(), const Color(0xFFFF9800)),
        _buildLegendItem(
            'Buddha', a.buddha.toString(), const Color(0xFFE91E63)),
        _buildLegendItem(
            'Konghucu', a.konghucu.toString(), const Color(0xFF00BCD4)),
        _buildLegendItem(
            'Lainnya', a.lainnya.toString(), const Color(0xFF9E9E9E)),
      ],
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }
}
