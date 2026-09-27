import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
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
    final double topPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight + 10;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFFF5F6FA)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
        child: Column(
          children: [
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
                color: Color(0xFF4A47DC),
                fontWeight: FontWeight.bold,
                fontSize: 20,
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
        backgroundColor: const Color(0xFFF5F6FA),
        // Tanpa AppBar agar konsisten dengan warungku page
        body: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: const Color(0xFF4A47DC),
          child: Column(
            children: [
              // Header Section
              _buildHeaderSection(),

              // Content
              Expanded(
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
                                  onPressed: () =>
                                      _loadData(forceRefresh: true),
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildProfilDesaCard(),
                            ),
                          ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: const Color(0xFF4A47DC),
          unselectedItemColor: Colors.grey,
          currentIndex: 3, // Profil Desa
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 28), label: 'Beranda'),
            BottomNavigationBarItem(
                icon: Icon(Icons.storefront_sharp, size: 28),
                label: 'Warungku'),
            BottomNavigationBarItem(
                icon: Icon(Icons.apps, size: 28), label: 'Informasi'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance, size: 28),
                label: 'Profil Desa'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long, size: 28), label: 'Tagihan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.description, size: 28), label: 'Portal'),
          ],
          onTap: (index) {
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
                // Current page - Profil Desa
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

  Widget _buildProfilDesaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tampilkan panel Wilayah SELALU di atas
          _buildSectionTitle('Wilayah'),
          _buildInfoRow(
              'Luas Wilayah',
              _pemdes!.dataWilayah.isNotEmpty
                  ? '${_pemdes!.dataWilayah.first.luasWilayah ?? '-'} m²'
                  : '-'),
          _buildBatasWilayah(_pemdes!.dataWilayah.isNotEmpty
              ? _pemdes!.dataWilayah.first.batasWilayah
              : null),
          _buildInfoRow(
              'Jumlah Dusun',
              _pemdes!.dataWilayah.isNotEmpty
                  ? (_pemdes!.dataWilayah.first.jumlahDusun ?? 0).toString()
                  : '-'),
          _buildInfoRow(
              'Jumlah RT',
              _pemdes!.dataWilayah.isNotEmpty
                  ? (_pemdes!.dataWilayah.first.jumlahRT ?? 0).toString()
                  : '-'),
          const SizedBox(height: 16),

          // Konten tambahan ditampilkan saat expand
          ...(_isProfilDesaExpanded
              ? [
                  _buildSectionTitle('Penduduk'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPieChart(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildInfoRow(
                                'Perempuan',
                                (_pemdes!.statistikPenduduk?.female ?? 0)
                                    .toString()),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                                'Laki-laki',
                                (_pemdes!.statistikPenduduk?.male ?? 0)
                                    .toString()),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                                'Total',
                                (_pemdes!.statistikPenduduk?.total ?? 0)
                                    .toString()),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Statistik Usia'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAgePieChart(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildAgeInfoColumn(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Statistik Pendidikan'),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _buildEducationPieChart()),
                      const SizedBox(height: 8),
                      _buildEducationInfoColumn(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Statistik Agama'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildReligionPieChart(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReligionInfoColumn(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Unit Usaha Masyarakat'),
                  ...(() {
                    final Map<String, int> counts = {};
                    final Map<String, String> display = {};
                    for (final w
                        in (_pemdes?.warungkuKlasifikasiJenis ?? const [])) {
                      final raw = w.jenis.trim();
                      final key = raw.isEmpty ? 'lainnya' : raw.toLowerCase();
                      final int val =
                          (w.totalBarang is int && w.totalBarang > 0)
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
                    return keys
                        .map((k) => _buildInfoRow(
                            display[k] ?? k, counts[k]!.toString()))
                        .toList();
                  }()),
                  const SizedBox(height: 16),
                  _buildUsahaDesaGrouped(_pemdes!.usahaDesa),
                  const SizedBox(height: 16),
                  _buildSaranaUmumByKategori(_pemdes!.saranaUmumByKategori),
                  const SizedBox(height: 16),
                  _buildKesenianGrouped(_pemdes!.kesenianBudaya),
                  const SizedBox(height: 16),
                  _buildAbdesGrouped(_pemdes!.abdes),
                ]
              : []),

          const SizedBox(height: 16),

          // Tombol dropdown sederhana
          GestureDetector(
            onTap: () {
              setState(() {
                _isProfilDesaExpanded = !_isProfilDesaExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isProfilDesaExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF4A47DC),
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets - Copied from beranda_page.dart

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '• $title',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label :',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatasWilayah(String? raw) {
    final String source = (raw ?? '').trim();
    if (source.isEmpty) {
      return _buildInfoRow('Batas Wilayah', '-');
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow('Batas Wilayah', ''),
          const SizedBox(height: 6),
          _buildInfoRow('  - Barat', v('barat')),
          _buildInfoRow('  - Timur', v('timur')),
          _buildInfoRow('  - Utara', v('utara')),
          _buildInfoRow('  - Selatan', v('selatan')),
        ],
      ),
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
        _buildSectionTitle('Usaha Desa'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                for (final item in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if ((item.photoUrl ?? '').trim().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              _resolveStorageUrl(item.photoUrl) ??
                                  item.photoUrl!,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 38,
                                height: 38,
                                color: Colors.grey[200],
                                child: const Icon(Icons.store,
                                    size: 18, color: Color(0xFF9E9E9E)),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDEEF3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.store,
                                size: 18, color: Color(0xFF9E9E9E)),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.namaUsaha,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF333333)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaranaUmumByKategori(List<SaranaUmumByKategori> groups) {
    if (groups.isEmpty) return const SizedBox.shrink();

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

    if (byJenis.isEmpty) return const SizedBox.shrink();

    final jenisKeys = byJenis.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Sarana Umum'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final jenis in jenisKeys) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    jenis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                ...(() {
                  final kategoriMap = byJenis[jenis]!;
                  final kategoriKeys = kategoriMap.keys.toList()..sort();
                  return kategoriKeys
                      .map((kat) => Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kat,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final item in kategoriMap[kat]!)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8, bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if ((item.photoUrl ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Image.network(
                                              _resolveStorageUrl(
                                                      item.photoUrl) ??
                                                  item.photoUrl!,
                                              width: 38,
                                              height: 38,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                width: 38,
                                                height: 38,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.place,
                                                    size: 18,
                                                    color: Color(0xFF9E9E9E)),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEDEEF3),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.place,
                                                size: 18,
                                                color: Color(0xFF9E9E9E)),
                                          ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.namaSarana,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF333333)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ))
                      .toList();
                }()),
              ],
            ],
          ),
        ),
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
        _buildSectionTitle('Kesenian Dan Budaya'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    () {
                      final name = entry.key.substring(5);
                      return name.isNotEmpty
                          ? name[0].toUpperCase() + name.substring(1)
                          : 'Kesenian';
                    }(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                for (final item in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if ((item.photoUrl ?? '').trim().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              _resolveStorageUrl(item.photoUrl) ??
                                  item.photoUrl!,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 38,
                                height: 38,
                                color: Colors.grey[200],
                                child: const Icon(Icons.theaters,
                                    size: 18, color: Color(0xFF9E9E9E)),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDEEF3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.theaters,
                                size: 18, color: Color(0xFF9E9E9E)),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.namaKesenian,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF333333)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbdesGrouped(List<Abdes> items) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 8),
          Text('ABDES',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333))),
          SizedBox(height: 6),
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

    if (grouped.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 8),
          Text('ABDES',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333))),
          SizedBox(height: 6),
          Text('Data ABDES belum dapat dikelompokkan',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ABDES'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    () {
                      final name = entry.key.substring(5);
                      return name.isNotEmpty
                          ? name[0].toUpperCase() + name.substring(1)
                          : 'ABDES';
                    }(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                for (final nama in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF4A47DC))),
                        Expanded(
                          child: Text(
                            nama,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF333333)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Pie Charts

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
          sectionsSpace: 0,
          centerSpaceRadius: 0,
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
          title: 'Tidak ada data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }
    final lakiLakiPercent = (lakiLaki / total * 100).round();
    final perempuanPercent = (perempuan / total * 100).round();

    return List.generate(2, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 12.0 : 10.0;
      final radius = isTouched ? 65.0 : 50.0;
      final badgeSize = isTouched ? 35.0 : 25.0;

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: const Color(0xFF2196F3),
            value: lakiLaki.toDouble(),
            title: '$lakiLaki\n($lakiLakiPercent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.male,
              size: badgeSize,
              borderColor: const Color(0xFF2196F3),
            ),
            badgePositionPercentageOffset: .98,
          );
        case 1:
          return PieChartSectionData(
            color: const Color(0xFFE91E63),
            value: perempuan.toDouble(),
            title: '$perempuan\n($perempuanPercent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.female,
              size: badgeSize,
              borderColor: const Color(0xFFF8BBD9),
            ),
            badgePositionPercentageOffset: .98,
          );
        default:
          throw Exception('Invalid section index');
      }
    });
  }

  Widget _buildAgePieChart() {
    final statistikUmur = _pemdes?.statistikUmur;
    if (statistikUmur == null) {
      return const Center(
        child: Text(
          'Data statistik usia tidak tersedia',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    final usia0_17 = statistikUmur.usia0_17;
    final usia18_30 = statistikUmur.usia18_30;
    final usia31_45 = statistikUmur.usia31_45;
    final usia46_60 = statistikUmur.usia46_60;
    final usia61_plus = statistikUmur.usia61_plus;
    final total = statistikUmur.totalWithAge;

    if (total == 0) {
      return const Center(
        child: Text(
          'Tidak ada data statistik usia',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return Container(
      width: 180,
      height: 180,
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
          sectionsSpace: 0,
          centerSpaceRadius: 0,
          sections: _showingAgeSections(
              usia0_17, usia18_30, usia31_45, usia46_60, usia61_plus, total),
        ),
      ),
    );
  }

  List<PieChartSectionData> _showingAgeSections(int usia0_17, int usia18_30,
      int usia31_45, int usia46_60, int usia61_plus, int total) {
    if (total == 0) {
      return [
        PieChartSectionData(
          color: const Color(0xFF2196F3),
          value: 1,
          title: 'Tidak ada data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    final usia0_17Percent = (usia0_17 / total * 100).round();
    final usia18_30Percent = (usia18_30 / total * 100).round();
    final usia31_45Percent = (usia31_45 / total * 100).round();
    final usia46_60Percent = (usia46_60 / total * 100).round();
    final usia61_plusPercent = (usia61_plus / total * 100).round();

    return List.generate(5, (i) {
      final isTouched = i == _touchedAgeIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 95.0 : 75.0;
      final badgeSize = isTouched ? 45.0 : 35.0;

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: const Color(0xFF2196F3),
            value: usia0_17.toDouble(),
            title: '$usia0_17\n($usia0_17Percent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.child_care,
              size: badgeSize,
              borderColor: const Color(0xFF2196F3),
            ),
            badgePositionPercentageOffset: .98,
          );
        case 1:
          return PieChartSectionData(
            color: const Color(0xFF4CAF50),
            value: usia18_30.toDouble(),
            title: '$usia18_30\n($usia18_30Percent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.person,
              size: badgeSize,
              borderColor: const Color(0xFF4CAF50),
            ),
            badgePositionPercentageOffset: .98,
          );
        case 2:
          return PieChartSectionData(
            color: const Color(0xFFFF9800),
            value: usia31_45.toDouble(),
            title: '$usia31_45\n($usia31_45Percent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.work,
              size: badgeSize,
              borderColor: const Color(0xFFFF9800),
            ),
            badgePositionPercentageOffset: .98,
          );
        case 3:
          return PieChartSectionData(
            color: const Color(0xFF9C27B0),
            value: usia46_60.toDouble(),
            title: '$usia46_60\n($usia46_60Percent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.person_outline,
              size: badgeSize,
              borderColor: const Color(0xFF9C27B0),
            ),
            badgePositionPercentageOffset: .98,
          );
        case 4:
          return PieChartSectionData(
            color: const Color(0xFFE91E63),
            value: usia61_plus.toDouble(),
            title: '$usia61_plus\n($usia61_plusPercent%)',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: _Badge(
              Icons.elderly,
              size: badgeSize,
              borderColor: const Color(0xFFE91E63),
            ),
            badgePositionPercentageOffset: .98,
          );
        default:
          throw Error();
      }
    });
  }

  Widget _buildAgeInfoColumn() {
    return Column(
      children: [
        _buildSmallInfoRow(
            '0-17 tahun', (_pemdes!.statistikUmur?.usia0_17 ?? 0).toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow(
            '18-30 tahun', (_pemdes!.statistikUmur?.usia18_30 ?? 0).toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow(
            '31-45 tahun', (_pemdes!.statistikUmur?.usia31_45 ?? 0).toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow(
            '46-60 tahun', (_pemdes!.statistikUmur?.usia46_60 ?? 0).toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow(
            '61+ tahun', (_pemdes!.statistikUmur?.usia61_plus ?? 0).toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow(
            'Total', (_pemdes!.statistikUmur?.totalWithAge ?? 0).toString()),
      ],
    );
  }

  Widget _buildSmallInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildEducationPieChart() {
    final statistikPendidikan = _pemdes?.statistikPendidikan;
    if (statistikPendidikan == null) {
      return const Center(
        child: Text(
          'Data statistik pendidikan tidak tersedia',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    final total = statistikPendidikan.totalWithEducation;
    if (total == 0) {
      return const Center(
        child: Text(
          'Tidak ada data statistik pendidikan',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return Container(
      width: 220,
      height: 220,
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

                if (_touchedEducationIndex == touchedIndex) {
                  _touchedEducationIndex = -1;
                } else {
                  _touchedEducationIndex = touchedIndex;
                }
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 0,
          centerSpaceRadius: 0,
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
          color: const Color(0xFF2196F3),
          value: 1,
          title: 'Tidak ada data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    final data = [
      (
        'Tidak/Belum Sekolah',
        pendidikan.tidakSekolah,
        const Color(0xFF2196F3),
        Icons.school
      ),
      (
        'Belum Tamat SD',
        pendidikan.belumTamatSD,
        const Color(0xFF4CAF50),
        Icons.school_outlined
      ),
      ('Tamat SD', pendidikan.tamatSD, const Color(0xFFFF9800), Icons.school),
      ('SLTP/SMP', pendidikan.sltp, const Color(0xFF9C27B0), Icons.school),
      ('SLTA/SMA', pendidikan.slta, const Color(0xFFE91E63), Icons.school),
      (
        'Diploma I/II',
        pendidikan.diplomaI,
        const Color(0xFF00BCD4),
        Icons.school
      ),
      (
        'Diploma III',
        pendidikan.diplomaIII,
        const Color(0xFF795548),
        Icons.school
      ),
      (
        'Diploma IV/S1/S2',
        pendidikan.diplomaIV,
        const Color(0xFF607D8B),
        Icons.school
      ),
      ('S3', pendidikan.strataIII, const Color(0xFF3F51B5), Icons.school),
      ('Lainnya', pendidikan.lainnya, const Color(0xFF9E9E9E), Icons.school),
    ].where((item) => item.$2 > 0).toList();

    if (data.isEmpty) {
      return [
        PieChartSectionData(
          color: const Color(0xFF2196F3),
          value: 1,
          title: 'Tidak ada data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    return List.generate(data.length, (i) {
      final item = data[i];
      final isTouched = i == _touchedEducationIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 115.0 : 95.0;
      final badgeSize = isTouched ? 55.0 : 45.0;
      final percent = (item.$2 / total * 100).round();

      return PieChartSectionData(
        color: item.$3,
        value: item.$2.toDouble(),
        title: '${item.$2}\n($percent%)',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _Badge(
          item.$4,
          size: badgeSize,
          borderColor: item.$3,
        ),
        badgePositionPercentageOffset: .98,
      );
    });
  }

  Widget _buildEducationInfoColumn() {
    final statistikPendidikan = _pemdes?.statistikPendidikan;
    if (statistikPendidikan == null) return const SizedBox();

    return Column(
      children: [
        _buildCompactInfoRow(
            'Tidak/Belum Sekolah', statistikPendidikan.tidakSekolah.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow(
            'Belum Tamat SD', statistikPendidikan.belumTamatSD.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow(
            'Tamat SD', statistikPendidikan.tamatSD.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow('SLTP/SMP', statistikPendidikan.sltp.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow('SLTA/SMA', statistikPendidikan.slta.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow(
            'Diploma I/II', statistikPendidikan.diplomaI.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow(
            'Diploma III', statistikPendidikan.diplomaIII.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow(
            'Diploma IV/S1/S2', statistikPendidikan.diplomaIV.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow('S3', statistikPendidikan.strataIII.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow('Lainnya', statistikPendidikan.lainnya.toString()),
        const SizedBox(height: 4),
        _buildCompactInfoRow(
            'Total', statistikPendidikan.totalWithEducation.toString()),
      ],
    );
  }

  Widget _buildCompactInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildReligionPieChart() {
    final statistikAgama = _pemdes?.statistikAgama;
    if (statistikAgama == null) {
      return const Center(
        child: Text(
          'Data statistik agama tidak tersedia',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    final total = statistikAgama.totalWithReligion;
    if (total == 0) {
      return const Center(
        child: Text(
          'Tidak ada data statistik agama',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return Container(
      width: 180,
      height: 180,
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

                if (_touchedReligionIndex == touchedIndex) {
                  _touchedReligionIndex = -1;
                } else {
                  _touchedReligionIndex = touchedIndex;
                }
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 0,
          centerSpaceRadius: 0,
          sections: _showingReligionSections(statistikAgama, total),
        ),
      ),
    );
  }

  List<PieChartSectionData> _showingReligionSections(
      StatistikAgama agama, int total) {
    if (total == 0) {
      return [
        PieChartSectionData(
          color: const Color(0xFF2196F3),
          value: 1,
          title: 'Tidak ada data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    final data = [
      ('Islam', agama.islam, const Color(0xFF2196F3), Icons.mosque),
      ('Kristen', agama.kristen, const Color(0xFF4CAF50), Icons.church),
      ('Katolik', agama.katolik, const Color(0xFF9C27B0), Icons.church),
      ('Hindu', agama.hindu, const Color(0xFFFF9800), Icons.temple_hindu),
      ('Buddha', agama.buddha, const Color(0xFFE91E63), Icons.temple_buddhist),
      (
        'Konghucu',
        agama.konghucu,
        const Color(0xFF00BCD4),
        Icons.temple_buddhist
      ),
      ('Lainnya', agama.lainnya, const Color(0xFF9E9E9E), Icons.help_outline),
    ].where((item) => item.$2 > 0).toList();

    if (data.isEmpty) {
      return [
        PieChartSectionData(
          color: const Color(0xFF2196F3),
          value: 1,
          title: 'Tidak ada data',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    return List.generate(data.length, (i) {
      final item = data[i];
      final isTouched = i == _touchedReligionIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 95.0 : 75.0;
      final badgeSize = isTouched ? 45.0 : 35.0;
      final percent = (item.$2 / total * 100).round();

      return PieChartSectionData(
        color: item.$3,
        value: item.$2.toDouble(),
        title: '${item.$2}\n($percent%)',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _Badge(
          item.$4,
          size: badgeSize,
          borderColor: item.$3,
        ),
        badgePositionPercentageOffset: .98,
      );
    });
  }

  Widget _buildReligionInfoColumn() {
    final statistikAgama = _pemdes?.statistikAgama;
    if (statistikAgama == null) return const SizedBox();

    return Column(
      children: [
        _buildSmallInfoRow('Islam', statistikAgama.islam.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow('Kristen', statistikAgama.kristen.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow('Katolik', statistikAgama.katolik.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow('Hindu', statistikAgama.hindu.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow('Buddha', statistikAgama.buddha.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow('Konghucu', statistikAgama.konghucu.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow('Lainnya', statistikAgama.lainnya.toString()),
        const SizedBox(height: 6),
        _buildSmallInfoRow(
            'Total', statistikAgama.totalWithReligion.toString()),
      ],
    );
  }
}

// Badge Widget untuk Pie Charts
class _Badge extends StatelessWidget {
  const _Badge(
    this.icon, {
    required this.size,
    required this.borderColor,
  });
  final IconData icon;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.3),
            offset: const Offset(2, 2),
            blurRadius: 3,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Icon(
          icon,
          color: borderColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}
