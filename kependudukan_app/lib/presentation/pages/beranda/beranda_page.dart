import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/dataku/dataku_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/presentation/pages/formulir/formulir_detail_page.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:ladimas/data/datasources/pemerintah_desa_api_service.dart';
import 'package:ladimas/data/models/pemerintah_desa_model.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ladimas/data/models/formulir_model.dart';
import 'package:ladimas/data/datasources/formulir_api_service.dart';
import 'dart:async';
import 'dart:convert';

class BerandaPage extends StatefulWidget {
  final Penduduk penduduk;

  const BerandaPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  // bool _isProfilDesaExpanded = false; // COMMENTED OUT - untuk Profil Desa
  bool _isPerangkatDesaExpanded = false;

  // Data state
  PemerintahDesaModel? _pemdes;
  bool _isLoadingPemdes = true;
  List<FormulirModel> _formulirs = [];
  bool _isLoadingFormulirs = true;
  String _pendudukName = '';
  int _touchedIndex = -1;
  int _touchedAgeIndex = -1;
  int _touchedEducationIndex = -1;
  int _touchedReligionIndex = -1;
  final Set<String> _hoveredPerangkat = <String>{};

  // API Services
  late final PemerintahDesaApiService _pemdesApiService;
  late final FormulirApiService _formulirApiService;
  String? _villageName;

  @override
  void initState() {
    super.initState();
    _pemdesApiService = PemerintahDesaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _formulirApiService = FormulirApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _loadData();
    _loadPendudukName();
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

  // Sarana Umum: kelompokkan berdasarkan kategori -> daftar item dengan foto (jika ada)
  Widget _buildSaranaUmumGrouped(List<SaranaUmum> sarana) {
    if (sarana.isEmpty) return const SizedBox.shrink();

    // Kelompokkan berdasarkan kategori_sarana_id bila ada, jika tidak, pakai nama kategori
    final Map<String, List<SaranaUmum>> grouped = {};
    for (final s in sarana) {
      if (s.namaSarana.trim().isEmpty) continue;
      final String key = (s.kategoriId != null)
          ? 'id:${s.kategoriId}'
          : 'nama:${(s.kategori ?? 'Sarana Umum').trim().toLowerCase()}';
      if (!grouped.containsKey(key)) grouped[key] = <SaranaUmum>[];
      grouped[key]!.add(s);
    }

    if (grouped.isEmpty) return const SizedBox.shrink();

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
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    // Label kategori: jika key berupa id gunakan fallback nama jika tersedia
                    () {
                      if (entry.key.startsWith('id:')) {
                        final idStr = entry.key.substring(3);
                        return 'Kategori $idStr';
                      }
                      final name = entry.key.substring(5);
                      return name.isNotEmpty
                          ? name[0].toUpperCase() + name.substring(1)
                          : 'Sarana Umum';
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
                                child: const Icon(Icons.place,
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
                            child: const Icon(Icons.place,
                                size: 18, color: Color(0xFF9E9E9E)),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.namaSarana,
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

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoadingPemdes = true;
      });
    }

    await Future.wait([
      _loadPemdes(forceRefresh: forceRefresh),
      _loadFormulirs(),
    ]);
  }

  Future<void> _loadFormulirs() async {
    if (mounted) {
      setState(() {
        _isLoadingFormulirs = true;
      });
    }

    try {
      final data = await _formulirApiService.getActiveFormulirs();
      if (mounted) {
        setState(() {
          // Only show forms that are NOT filled yet
          _formulirs = data.where((f) => !f.isFilled).toList();
          _isLoadingFormulirs = false;
        });
      }
    } catch (e) {
      print('❌ [Beranda] Error loading Formulirs: $e');
      if (mounted) {
        setState(() {
          _isLoadingFormulirs = false;
        });
      }
    }
  }

  Future<void> _loadPendudukName() async {
    // Jika nama sudah ada dari widget.penduduk, gunakan itu
    if (widget.penduduk.name.isNotEmpty) {
      setState(() {
        _pendudukName = widget.penduduk.name;
      });
      return;
    }

    // Jika nama kosong, coba ambil dari API detail penduduk
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.goBaseUrl}/api/citizens/${widget.penduduk.nik}'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final fullName = data['data']?['full_name'] ?? '';

        if (mounted && fullName.isNotEmpty) {
          setState(() {
            _pendudukName = fullName;
          });
        }
      }
    } catch (e) {
      // Jika gagal, gunakan NIK sebagai fallback
      if (mounted) {
        setState(() {
          _pendudukName = widget.penduduk.nik;
        });
      }
    }
  }

  Future<void> _loadPemdes({bool forceRefresh = false}) async {
    final startTime = DateTime.now();

    if (forceRefresh) {
      print('🔄 [Beranda] Force refresh - akan load data baru dari API...');
    } else {
      print('🔵 [Beranda] Loading Pemerintah Desa data...');
    }

    try {
      // PemerintahDesaApiService menggunakan cache permanent (1 tahun)
      // Cache hanya di-clear saat forceRefresh = true (pull-to-refresh)
      final data =
          await _pemdesApiService.getPemerintahDesa(forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _pemdes = data;
          _isLoadingPemdes = false;
        });
      }

      // Load nama desa di background (non-blocking)
      _loadVillageNameFromData(data);

      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      if (forceRefresh) {
        print('✅ [Beranda] Force refresh completed in ${loadTime}ms');
      } else {
        print('✅ [Beranda] Total load time: ${loadTime}ms');
      }
    } catch (e) {
      print('❌ [Beranda] Error loading Pemerintah Desa: $e');
      if (mounted) {
        setState(() {
          _pemdes = null;
          _isLoadingPemdes = false;
        });
      }
    }
  }

  /// Load nama desa dari data pemerintah desa
  void _loadVillageNameFromData(PemerintahDesaModel data) {
    final String? villageIdStr =
        (data.pemerintahVillagesId ?? data.villageId)?.toString();
    if (villageIdStr != null) {
      // Load nama desa di background (non-blocking)
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
            print('✅ [Beranda] Village name loaded: $_villageName');
          }
        } catch (e) {
          print('❌ [Beranda] Error loading village name: $e');
        }
      });
    }
  }

  Future<int?> _getVillageId() async {
    try {
      final authLocalStorage = AuthLocalStorage();
      final userData = await authLocalStorage.getUserCredentials();
      print('Beranda - User data: $userData');

      if (userData != null && userData['village_id'] != null) {
        final villageId = int.tryParse(userData['village_id'].toString());
        print('Beranda - Village ID from user data: $villageId');
        return villageId;
      }
      print('Beranda - No village_id in user data');
    } catch (e) {
      print('Beranda - Error getting village ID: $e');
    }
    return null;
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

                      // Kuesioner / Formulir Section (Hanya jika ada kuesioner aktif & belum diisi)
                      if (_formulirs.isNotEmpty) ...[
                        _buildKuesionerCard(),
                        const SizedBox(height: 16),
                      ],

                      // Profil Desa Card - COMMENTED OUT
                      // _buildProfilDesaCard(),
                      // const SizedBox(height: 16),
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
            AppBottomNavBar.item(icon: Icons.storefront, label: 'Warungku'),
            AppBottomNavBar.item(icon: Icons.grid_view, label: 'Informasi'),
            AppBottomNavBar.item(
                icon: Icons.account_balance_outlined, label: 'Profil Desa'),
            AppBottomNavBar.item(
                icon: Icons.receipt_long_outlined, label: 'Tagihan'),
            AppBottomNavBar.item(
                icon: Icons.description_outlined, label: 'Portal'),
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
                      initialTabIndex: 0, // Berita Desa tab
                    ),
                  ),
                );
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilDesaPage(penduduk: widget.penduduk),
                  ),
                );
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

    final displayName =
        _pendudukName.isNotEmpty ? _pendudukName : widget.penduduk.name;

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
              // Top Bar: Avatar, Greeting, and Dataku Button
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
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DatakuPage(penduduk: widget.penduduk),
                          ),
                        );
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Welcome Banner Card
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
                              'LADIMAS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Layanan Digital Masyarakat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Akses layanan kependudukan dan informasi desa secara mudah dan terpadu.',
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
                        Icons.apartment_rounded,
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
                      // Ambil dari pemerintah_desa (user) jika tersedia via sarana kategori? gunakan pemdes->pemerintah_desa tidak dimodelkan spesifik,
                      // fallback: gunakan alamat dari kepala/perangkat bila ada field. Jika tidak ada, pakai '-' (akan diisi saat model diperluas)
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
            // Hilangkan ringkasan wilayah di sini sesuai permintaan (hanya tampil di bagian Wilayah pada Profil Desa)

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

  // COMMENTED OUT - Profil Desa Card
  /*
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
  */

  Widget _buildKuesionerCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kuesioner Aktif',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_formulirs.length}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _formulirs.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final form = _formulirs[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.8,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 10,
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
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Kuesioner Warga',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      form.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pendapat Anda berharga',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FormulirDetailPage(
                                  formulir: form,
                                  penduduk: widget.penduduk,
                                ),
                              ),
                            ).then((value) {
                              if (value == true) {
                                _loadData();
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Mulai',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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

class Indicator extends StatelessWidget {
  const Indicator({
    super.key,
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor = const Color(0xFF505050),
  });
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        )
      ],
    );
  }
}
