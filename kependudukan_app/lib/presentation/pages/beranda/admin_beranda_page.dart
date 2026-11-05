import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/data/datasources/admin_pemerintah_desa_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/village_stats_api_service.dart';
import 'package:ladimas/data/models/pemerintah_desa_model.dart';
import 'package:ladimas/presentation/pages/beranda/admin_tagihan_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_biodata_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class AdminBerandaPage extends StatefulWidget {
  final Map<String, dynamic> adminData; // berisi user, role, access_token

  const AdminBerandaPage({Key? key, required this.adminData}) : super(key: key);

  @override
  State<AdminBerandaPage> createState() => _AdminBerandaPageState();

  // Generate unique key berdasarkan adminData untuk memastikan widget rebuild
  static Key generateKey(Map<String, dynamic> adminData) {
    final user = adminData['user'] as Map<String, dynamic>?;
    final userId = user?['id']?.toString() ?? '';
    final username = user?['username']?.toString() ?? '';
    final token = adminData['access_token']?.toString() ?? '';
    return ValueKey('admin_beranda_${userId}_${username}_${token.hashCode}');
  }
}

class _AdminBerandaPageState extends State<AdminBerandaPage> {
  bool _isProfilDesaExpanded = false;
  bool _isPerangkatDesaExpanded = false;

  // Data state
  PemerintahDesaModel? _pemdes;
  bool _isLoadingPemdes = true;
  bool _isLoadingGoStats = false;
  String _adminName = '';
  int _touchedIndex = -1;
  int _touchedAgeIndex = -1;
  int _touchedEducationIndex = -1;
  int _touchedReligionIndex = -1;
  final Set<String> _hoveredPerangkat = <String>{};

  // API Services
  late final AdminPemerintahDesaApiService _pemdesApiService;
  String? _villageName;

  @override
  void initState() {
    super.initState();
    _pemdesApiService = AdminPemerintahDesaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _loadDataWithOverlay();
    _loadAdminName();
  }

  @override
  void didUpdateWidget(AdminBerandaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cek apakah adminData berubah (misalnya login dengan desa berbeda)
    if (_hasAdminDataChanged(oldWidget.adminData, widget.adminData)) {
      _resetAndReloadData();
    }
  }

  // Method untuk reset dan reload data
  void _resetAndReloadData() {
    // Reset semua data dan loading state
    setState(() {
      _pemdes = null;
      _isLoadingPemdes = true;
      _villageName = null;
      _adminName = '';
    });

    // Load data baru
    _loadDataWithOverlay();
    _loadAdminName();
  }

  // Helper method untuk membandingkan adminData
  bool _hasAdminDataChanged(
      Map<String, dynamic>? oldData, Map<String, dynamic>? newData) {
    if (oldData == null && newData == null) return false;
    if (oldData == null || newData == null) return true;

    // Bandingkan access_token dan user data
    final oldToken = oldData['access_token']?.toString();
    final newToken = newData['access_token']?.toString();

    final oldUser = oldData['user'] as Map<String, dynamic>?;
    final newUser = newData['user'] as Map<String, dynamic>?;

    if (oldToken != newToken) return true;
    if (oldUser == null && newUser == null) return false;
    if (oldUser == null || newUser == null) return true;

    // Bandingkan ID user atau username
    final oldUserId = oldUser['id']?.toString();
    final newUserId = newUser['id']?.toString();
    final oldUsername = oldUser['username']?.toString();
    final newUsername = newUser['username']?.toString();

    return oldUserId != newUserId || oldUsername != newUsername;
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    print('🔄 Starting pull to refresh...');
    if (mounted) {
      setState(() {
        _isLoadingPemdes = true;
      });
    }

    try {
      await _loadPemdes();
      print('✅ Pull to refresh completed successfully');
    } catch (e) {
      print('❌ Error during pull to refresh: $e');
    }
  }

  // Method untuk initial loading tanpa overlay
  Future<void> _loadDataWithOverlay() async {
    if (mounted) {
      setState(() {
        _isLoadingPemdes = true;
      });
    }

    try {
      await _loadPemdes();
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadAdminName() async {
    final user = (widget.adminData['user'] as Map<String, dynamic>?);
    final username = (user?['username'] ?? user?['nama'] ?? 'Admin').toString();

    setState(() {
      _adminName = username;
    });
  }

  @override
  void dispose() {
    // Clean up resources jika diperlukan
    super.dispose();
  }

  Future<void> _loadPemdes() async {
    try {
      final data = await _pemdesApiService.show();
      if (mounted) {
        setState(() {
          _pemdes = PemerintahDesaModel.fromJson(data);
          _isLoadingPemdes = false;
        });
      }

      // Optimasi: ambil statistik langsung dari Go (lebih cepat & konsisten).
      final pemdes = _pemdes;
      if (pemdes != null) {
        _loadGoVillageStatsFromPemdes(pemdes);
      }

      // Setelah data didapat, coba ambil nama desa berdasarkan villages_id
      final String? villageIdStr = _pemdes?.pemerintahVillagesId?.toString();
      if (villageIdStr != null) {
        try {
          final village = await WilayahService().getVillage(
              villageIdStr,
              _pemdes?.pemerintahSubDistrictId?.toString(),
              _pemdes?.pemerintahDistrictId?.toString());
          if (mounted && village != null) {
            setState(() {
              _villageName =
                  (village['name'] ?? village['nama'] ?? '').toString();
            });
          }
        } catch (_) {}
      }
    } catch (e) {
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
    if (_isLoadingGoStats) return;
    _isLoadingGoStats = true;
    try {
      final svc = VillageStatsApiService(client: http.Client());
      final bundle = await svc.fetchVillageStats(villageId);

      if (!mounted) return;
      if (_pemdes == null) {
        _isLoadingGoStats = false;
        return;
      }

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
      });
    } catch (e) {
      if (mounted) {
        // Jangan ganggu UI utama: biarkan fallback Laravel tetap tampil.
        // ignore: avoid_print
        print('❌ [AdminBeranda] Go stats error: $e');
      }
    } finally {
      _isLoadingGoStats = false;
    }
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
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true),
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header Section with LADIMAS
                _buildHeaderSection(),

                // Main Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pemerintah Desa Card
                      _buildPemerintahDesaCard(),
                      const SizedBox(height: 16),

                      // Profil Desa Card
                      _buildProfilDesaCard(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: 0, // Beranda
          items: [
            AppBottomNavBar.item(icon: Icons.home, label: 'Beranda'),
            AppBottomNavBar.item(icon: Icons.receipt_long_outlined, label: 'Tagihan'),
            AppBottomNavBar.item(icon: Icons.person_outline, label: 'Biodata'),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                // Current page - Beranda
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminTagihanPage(adminData: widget.adminData),
                  ),
                );
                break;
              case 2:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminBiodataPage(adminData: widget.adminData),
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }

  // Menampilkan batas wilayah per arah dalam bentuk list rapi
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

  // Helper list bullet sederhana untuk menampilkan daftar string
  Widget _buildBulletSection(String title, List<String> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
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
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.primaryColor)),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF333333)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Usaha Desa: kelompokkan berdasarkan jenis -> daftar item dengan foto (jika ada)
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
                // Jenis (heading kecil)
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
                // Daftar usaha dengan thumbnail jika ada
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

  // Sarana Umum (baru): kelompok dari sarana_umum_by_kategori → Jenis Sarana → Kategori → daftar item dengan foto (jika ada)
  Widget _buildSaranaUmumByKategori(List<SaranaUmumByKategori> groups) {
    if (groups.isEmpty) return const SizedBox.shrink();

    // Kelompokkan ulang: jenis_sarana -> { kategori -> [SaranaRingkas] }
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

  // Kesenian dan Budaya: kelompokkan berdasarkan kolom jenis (tanpa id) dan tampilkan foto jika ada
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

  // ABDES (APBDes) : kelompokkan berdasarkan jenis
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
                                fontSize: 14, color: AppTheme.primaryColor)),
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

  String _stripHtml(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Normalisasi URL foto yang mungkin berupa path relatif atau file://
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
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour < 18) {
      greeting = 'Selamat Siang';
    } else {
      greeting = 'Selamat Malam';
    }

    final displayName = _adminName.isNotEmpty ? _adminName : 'Admin';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Avatar, Greeting, and Logout Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/app_icon.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showLogoutDialog(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Admin Welcome Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20087EAB),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PORTAL ADMINISTRATOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Kelola Layanan Desa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pantau statistik kependudukan, biodata warga, dan administrasi desa terintegrasi.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPemerintahDesaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLoadingPemdes
                ? 'Memuat...'
                : (() {
                    final vn = _villageName;
                    return (vn != null && vn.isNotEmpty)
                        ? 'Pemerintah Desa ' + vn
                        : 'Pemerintah Desa';
                  })(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingPemdes)
            const Center(child: CircularProgressIndicator())
          else if (_pemdes == null)
            const Text('Gagal memuat data pemerintah desa',
                style: TextStyle(color: Color(0xFF666666)))
          else ...[
            // Alamat & Kontak dari pemerintah_desa (ambil entri pertama)
            if (_pemdes!.perangkatDesa.isNotEmpty ||
                _pemdes!.kepalaDesa.isNotEmpty) ...[
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
                    _buildInfoRow(
                      'Alamat',
                      (_pemdes?.pemerintahAlamat ?? '-'),
                    ),
                    _buildInfoRow(
                      'Kontak',
                      (_pemdes?.pemerintahKontak ?? '-'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Kepala dan Perangkat Desa
            const Text('Perangkat Desa',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333))),
            const SizedBox(height: 12),
            if (_pemdes!.kepalaDesa.isNotEmpty)
              _buildPerangkatDesaItem(
                'Kepala Desa',
                _pemdes!.kepalaDesa.first.nama,
                photoUrl: _pemdes!.kepalaDesa.first.photoUrl,
              ),
            ..._pemdes!.perangkatDesa.take(3).map(
                  (p) => _buildPerangkatDesaItem(
                    p.jabatan,
                    p.nama,
                    photoUrl: p.photoUrl,
                  ),
                ),

            // Tampilkan perangkat desa tambahan jika ada dan dalam mode expanded
            if (_isPerangkatDesaExpanded && _pemdes!.perangkatDesa.length > 3)
              ..._pemdes!.perangkatDesa.skip(3).map(
                    (p) => _buildPerangkatDesaItem(
                      p.jabatan,
                      p.nama,
                      photoUrl: p.photoUrl,
                    ),
                  ),

            // Tombol dropdown untuk perangkat desa jika ada lebih dari 3
            if (_pemdes!.perangkatDesa.length > 3) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPerangkatDesaExpanded = !_isPerangkatDesaExpanded;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPerangkatDesaExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
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
            color: Color(0x06000000),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLoadingPemdes
                ? 'Memuat...'
                : (() {
                    final vn = _villageName;
                    return (vn != null && vn.isNotEmpty)
                        ? 'Profil Desa ' + vn
                        : 'Profil Desa';
                  })(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),

          ...(_isLoadingPemdes
              ? [const Center(child: CircularProgressIndicator())]
              : _pemdes == null
                  ? []
                  : [
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
                              ? (_pemdes!.dataWilayah.first.jumlahDusun ?? 0)
                                  .toString()
                              : '-'),
                      _buildInfoRow(
                          'Jumlah RT',
                          _pemdes!.dataWilayah.isNotEmpty
                              ? (_pemdes!.dataWilayah.first.jumlahRT ?? 0)
                                  .toString()
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
                                            (_pemdes!.statistikPenduduk
                                                        ?.female ??
                                                    0)
                                                .toString()),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                            'Laki-laki',
                                            (_pemdes!.statistikPenduduk?.male ??
                                                    0)
                                                .toString()),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                            'Total',
                                            (_pemdes!.statistikPenduduk
                                                        ?.total ??
                                                    0)
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
                                    in (_pemdes?.warungkuKlasifikasiJenis ??
                                        const [])) {
                                  final raw = w.jenis.trim();
                                  final key = raw.isEmpty
                                      ? 'lainnya'
                                      : raw.toLowerCase();
                                  final int val = (w.totalBarang is int &&
                                          w.totalBarang > 0)
                                      ? w.totalBarang
                                      : 1;
                                  counts[key] = (counts[key] ?? 0) + val;
                                  if (!display.containsKey(key)) {
                                    display[key] = key.isEmpty
                                        ? 'Lainnya'
                                        : key[0].toUpperCase() +
                                            key.substring(1);
                                  }
                                }
                                if (counts.isEmpty) {
                                  return <Widget>[
                                    const Text('Belum ada data potensi',
                                        style:
                                            TextStyle(color: Color(0xFF666666)))
                                  ];
                                }
                                final keys = counts.keys.toList()
                                  ..sort((a, b) =>
                                      counts[b]!.compareTo(counts[a]!));
                                return keys
                                    .map((k) => _buildInfoRow(
                                        display[k] ?? k, counts[k]!.toString()))
                                    .toList();
                              }()),
                              const SizedBox(height: 16),
                              _buildUsahaDesaGrouped(_pemdes!.usahaDesa),
                              const SizedBox(height: 16),
                              _buildSaranaUmumByKategori(
                                  _pemdes!.saranaUmumByKategori),
                              const SizedBox(height: 16),
                              _buildKesenianGrouped(_pemdes!.kesenianBudaya),
                              const SizedBox(height: 16),
                              _buildAbdesGrouped(_pemdes!.abdes),
                            ]
                          : []),
                    ]),

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
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPengumumanCard() {
    return const SizedBox.shrink();
  }

  Widget _buildBeritaCard() {
    return const SizedBox.shrink();
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

  Widget _buildPerangkatDesaItem(String position, String name,
      {String? photoUrl}) {
    final String? finalPhoto = _resolveStorageUrl(photoUrl);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() {
              _hoveredPerangkat.add(name);
            }),
            onExit: (_) => setState(() {
              _hoveredPerangkat.remove(name);
            }),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _hoveredPerangkat.contains(name) ? 1.06 : 1.0,
              curve: Curves.easeOut,
              child: GestureDetector(
                onTap: () {
                  if (finalPhoto != null && finalPhoto.trim().isNotEmpty) {
                    _showPhotoDetail(finalPhoto);
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage:
                        (finalPhoto != null && finalPhoto.trim().isNotEmpty)
                            ? CachedNetworkImageProvider(finalPhoto)
                            : null,
                    child: (finalPhoto == null || finalPhoto.trim().isEmpty)
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 32)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  position,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoDetail(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: SizedBox.expand(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent),
                ),
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  right: 24,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

                // Toggle behavior: jika yang sama diklik lagi, reset ke -1
                if (_touchedAgeIndex == touchedIndex) {
                  _touchedAgeIndex = -1;
                } else {
                  _touchedAgeIndex = touchedIndex;
                }
              });
            },
          ),
          borderData: FlBorderData(
            show: false,
          ),
          sectionsSpace: 0,
          centerSpaceRadius: 0,
          sections: _showingAgeSections(
              usia0_17, usia18_30, usia31_45, usia46_60, usia61_plus, total),
        ),
      ),
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

    // Ambil data yang tidak 0 dan urutkan berdasarkan jumlah
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

    // Ambil data yang tidak 0 dan urutkan berdasarkan jumlah
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

                // Toggle behavior: jika yang sama diklik lagi, reset ke -1
                if (_touchedIndex == touchedIndex) {
                  _touchedIndex = -1;
                } else {
                  _touchedIndex = touchedIndex;
                }
              });
            },
          ),
          borderData: FlBorderData(
            show: false,
          ),
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
            color: const Color(0xFF2196F3), // Biru untuk laki-laki
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
              borderColor: const Color(0xFF2196F3), // Biru untuk laki-laki
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
              borderColor: const Color(0xFFF8BBD9), // Pink muda untuk perempuan
            ),
            badgePositionPercentageOffset: .98,
          );
        default:
          throw Exception('Invalid section index');
      }
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi',
          style:
              TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
}

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
            color: Color(0x40000000),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({Key? key, required this.color, required this.label})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
