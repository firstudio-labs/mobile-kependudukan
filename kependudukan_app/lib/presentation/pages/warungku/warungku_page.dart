import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/presentation/pages/usaha_saya/usaha_saya_page.dart';
import 'package:ladimas/presentation/pages/warungku/product_detail_page.dart';
import 'package:ladimas/presentation/pages/warungku/semua_produk_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/warungku_api_service.dart';
import 'package:intl/intl.dart';

class WarungkuPage extends StatefulWidget {
  final Penduduk penduduk;

  const WarungkuPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<WarungkuPage> createState() => _WarungkuPageState();
}

class _WarungkuPageState extends State<WarungkuPage>
    with WidgetsBindingObserver {
  final WarungkuApiService _api = WarungkuApiService(
      client: http.Client(), authLocalStorage: AuthLocalStorage());
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  // Filter state
  List<String> _klassOptions = [];
  List<Map<String, dynamic>> _jenisOptions = [];
  String? _selectedKlasifikasi;
  int? _selectedJenisId;
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedSubDistrict;
  String? _selectedVillage;
  List<dynamic> _provinces = [];
  List<dynamic> _districts = [];
  List<dynamic> _subDistricts = [];
  List<dynamic> _villages = [];

  bool get _hasActiveFilters =>
      _selectedKlasifikasi != null ||
      _selectedJenisId != null ||
      _selectedProvince != null ||
      _selectedDistrict != null ||
      _selectedSubDistrict != null ||
      _selectedVillage != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadItems();
    _loadFilters();
    _loadProvinces();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshAllData();
    }
  }

  Future<void> _loadItems({String? search}) async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getAll(
        search: search,
        perPage: 12,
        klasifikasi: _selectedKlasifikasi,
        jenisId: _selectedJenisId,
        provinceId: _selectedProvince,
        districtId: _selectedDistrict,
        subDistrictId: _selectedSubDistrict,
        villageId: _selectedVillage,
      );
      final items = (result['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat produk: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFilters() async {
    try {
      final klass = await _api.getKlasifikasiList();
      final List<String> normalized = [];
      for (final k in klass.map((e) => e.toString())) {
        final exists =
            normalized.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalized.add(k);
      }

      if (mounted) {
        setState(() {
          _klassOptions = normalized;
          _jenisOptions = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat filter: $e')),
        );
      }
    }
  }

  Future<void> _loadProvinces() async {
    try {
      final data = await _api.getProvinces();
      if (mounted) {
        setState(() => _provinces = data);
      }
    } catch (_) {}
  }

  Future<void> _loadDistricts(String provinceId) async {
    setState(() {
      _districts = [];
      _subDistricts = [];
      _villages = [];
      _selectedDistrict = null;
      _selectedSubDistrict = null;
      _selectedVillage = null;
    });
    try {
      final province = _provinces.firstWhere(
        (p) => p['id']?.toString() == provinceId,
        orElse: () => {},
      );
      final provinceCode = province['code']?.toString();

      if (provinceCode != null) {
        final data = await _api.getDistricts(provinceCode);
        if (mounted) {
          setState(() => _districts = data);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSubDistricts(String districtId) async {
    setState(() {
      _subDistricts = [];
      _villages = [];
      _selectedSubDistrict = null;
      _selectedVillage = null;
    });
    try {
      final district = _districts.firstWhere(
        (d) => d['id']?.toString() == districtId,
        orElse: () => {},
      );
      final districtCode = district['code']?.toString();

      if (districtCode != null) {
        final data = await _api.getSubDistricts(districtCode);
        if (mounted) {
          setState(() => _subDistricts = data);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVillages(String subDistrictId) async {
    setState(() {
      _villages = [];
      _selectedVillage = null;
    });
    try {
      final subDistrict = _subDistricts.firstWhere(
        (s) => s['id']?.toString() == subDistrictId,
        orElse: () => {},
      );
      final subDistrictCode = subDistrict['code']?.toString();

      if (subDistrictCode != null) {
        final data = await _api.getVillages(subDistrictCode);
        if (mounted) {
          setState(() => _villages = data);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadJenisByKlasifikasi(String klasifikasi,
      {bool resetJenisId = true}) async {
    try {
      final jenis = await _api.getJenisByKlasifikasi(klasifikasi.toLowerCase());
      List<Map<String, dynamic>> validJenis = [];
      for (var item in jenis) {
        if (item['id'] != null && item['jenis'] != null) {
          validJenis.add(Map<String, dynamic>.from(item));
        }
      }

      if (mounted) {
        setState(() {
          _jenisOptions = validJenis;
          if (resetJenisId) {
            _selectedJenisId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jenisOptions = [];
          if (resetJenisId) {
            _selectedJenisId = null;
          }
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchJenisByKlasifikasi(
      String klasifikasi) async {
    try {
      final jenis = await _api.getJenisByKlasifikasi(klasifikasi.toLowerCase());
      List<Map<String, dynamic>> validJenis = [];
      for (var item in jenis) {
        if (item['id'] != null && item['jenis'] != null) {
          validJenis.add(Map<String, dynamic>.from(item));
        }
      }
      return validJenis;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadItems(search: _searchController.text.trim()),
        _loadFilters(),
        _loadProvinces(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat ulang data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Warungku',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchSection(),
              const SizedBox(height: 20),
              _buildSectionHeader(),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : _buildProductsGrid(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        items: [
          AppBottomNavBar.item(icon: Icons.home_outlined, label: 'Beranda'),
          AppBottomNavBar.item(
              icon: Icons.storefront_rounded, label: 'Warungku'),
          AppBottomNavBar.item(
              icon: Icons.grid_view_outlined, label: 'Informasi'),
          AppBottomNavBar.item(
              icon: Icons.account_balance_outlined, label: 'Profil Desa'),
          AppBottomNavBar.item(icon: Icons.receipt_long_outlined, label: 'Tagihan'),
          AppBottomNavBar.item(
              icon: Icons.description_outlined, label: 'Portal'),
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
    );
  }

  Widget _buildSearchSection() {
    return Row(
      children: [
        // Input Pencarian
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Cari produk di warung desa...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (value) => _loadItems(search: value),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _loadItems();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(
                        Icons.clear,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Tombol Usaha Saya
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UsahaSayaPage(penduduk: widget.penduduk),
                ),
              ).then((result) {
                if (result == true) {
                  _refreshAllData();
                }
              });
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Tombol Filter
        Material(
          color: _hasActiveFilters ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showFilterSheet,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasActiveFilters
                      ? AppTheme.primaryColor
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                color:
                    _hasActiveFilters ? Colors.white : const Color(0xFF475569),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Produk Tersedia',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SemuaProdukPage(),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() async {
    if (_selectedKlasifikasi != null && _jenisOptions.isEmpty) {
      await _loadJenisByKlasifikasi(_selectedKlasifikasi!, resetJenisId: false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModal) {
          bool loadingJenis = false;
          bool loadingDistricts = false;
          bool loadingSubDistricts = false;
          bool loadingVillages = false;
          String? validKlasifikasi = _selectedKlasifikasi;
          int? validJenisId = _selectedJenisId;

          if (validKlasifikasi != null &&
              !_klassOptions.contains(validKlasifikasi)) {
            validKlasifikasi = null;
          }

          if (validJenisId != null && _jenisOptions.isNotEmpty) {
            final jenisExists = _jenisOptions
                .any((j) => (j['id'] as num).toInt() == validJenisId);
            if (!jenisExists) {
              validJenisId = null;
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top drag indicator
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (_hasActiveFilters)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedKlasifikasi = null;
                                _selectedJenisId = null;
                                _selectedProvince = null;
                                _selectedDistrict = null;
                                _selectedSubDistrict = null;
                                _selectedVillage = null;
                                _jenisOptions = [];
                              });
                              Navigator.pop(context);
                              _refreshAllData();
                            },
                            child: const Text(
                              'Reset Filter',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField<String>(
                      label: 'Klasifikasi',
                      value: validKlasifikasi,
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Semua Klasifikasi')),
                        ..._klassOptions.map((k) =>
                            DropdownMenuItem<String>(value: k, child: Text(k)))
                      ],
                      onChanged: (v) async {
                        setModal(() {
                          _selectedKlasifikasi = v;
                          _selectedJenisId = null;
                          loadingJenis = true;
                        });
                        if (v != null) {
                          final list = await _fetchJenisByKlasifikasi(v);
                          setState(() {
                            _jenisOptions = list;
                          });
                          setModal(() {
                            loadingJenis = false;
                          });
                        } else {
                          setState(() {
                            _jenisOptions = [];
                          });
                          setModal(() {
                            loadingJenis = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField<int>(
                      label: 'Jenis',
                      value: validJenisId,
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('Semua Jenis')),
                        ..._jenisOptions.map((j) => DropdownMenuItem<int>(
                              value: (j['id'] as num).toInt(),
                              child: Text(j['jenis']?.toString() ?? '-'),
                            ))
                      ],
                      onChanged: (v) => setModal(() => _selectedJenisId = v),
                    ),
                    if (loadingJenis) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDropdownField<String>(
                      label: 'Provinsi',
                      value: _selectedProvince,
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Semua Provinsi')),
                        ..._provinces.map((p) => DropdownMenuItem<String>(
                            value: p['id']?.toString(),
                            child: Text(p['name']?.toString() ??
                                p['nama']?.toString() ??
                                '-')))
                      ],
                      onChanged: (v) async {
                        setModal(() {
                          _selectedProvince = v;
                          _selectedDistrict = null;
                          _selectedSubDistrict = null;
                          _selectedVillage = null;
                          loadingDistricts = true;
                          _districts = [];
                          _subDistricts = [];
                          _villages = [];
                        });
                        if (v != null) {
                          await _loadDistricts(v);
                        } else {
                          setState(() {
                            _districts = [];
                            _subDistricts = [];
                            _villages = [];
                          });
                        }
                        setModal(() {
                          loadingDistricts = false;
                        });
                      },
                    ),
                    if (loadingDistricts) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDropdownField<String>(
                      label: 'Kabupaten/Kota',
                      value: _selectedDistrict,
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Semua Kabupaten/Kota')),
                        ..._districts.map((d) => DropdownMenuItem<String>(
                            value: d['id']?.toString(),
                            child: Text(d['name']?.toString() ??
                                d['nama']?.toString() ??
                                '-')))
                      ],
                      onChanged: (v) async {
                        setModal(() {
                          _selectedDistrict = v;
                          _selectedSubDistrict = null;
                          _selectedVillage = null;
                          loadingSubDistricts = true;
                          _subDistricts = [];
                          _villages = [];
                        });
                        if (v != null) {
                          await _loadSubDistricts(v);
                        } else {
                          setState(() {
                            _subDistricts = [];
                            _villages = [];
                          });
                        }
                        setModal(() {
                          loadingSubDistricts = false;
                        });
                      },
                    ),
                    if (loadingSubDistricts) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDropdownField<String>(
                      label: 'Kecamatan',
                      value: _selectedSubDistrict,
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Semua Kecamatan')),
                        ..._subDistricts.map((s) => DropdownMenuItem<String>(
                            value: s['id']?.toString(),
                            child: Text(s['name']?.toString() ??
                                s['nama']?.toString() ??
                                '-')))
                      ],
                      onChanged: (v) async {
                        setModal(() {
                          _selectedSubDistrict = v;
                          _selectedVillage = null;
                          loadingVillages = true;
                          _villages = [];
                        });
                        if (v != null) {
                          await _loadVillages(v);
                        } else {
                          setState(() {
                            _villages = [];
                          });
                        }
                        setModal(() {
                          loadingVillages = false;
                        });
                      },
                    ),
                    if (loadingVillages) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDropdownField<String>(
                      label: 'Desa/Kelurahan',
                      value: _selectedVillage,
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Semua Desa/Kelurahan')),
                        ..._villages.map((v) => DropdownMenuItem<String>(
                            value: v['id']?.toString(),
                            child: Text(v['name']?.toString() ??
                                v['nama']?.toString() ??
                                '-')))
                      ],
                      onChanged: (v) => setModal(() => _selectedVillage = v),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedKlasifikasi = null;
                                _selectedJenisId = null;
                                _selectedProvince = null;
                                _selectedDistrict = null;
                                _selectedSubDistrict = null;
                                _selectedVillage = null;
                                _jenisOptions = [];
                              });
                              Navigator.pop(context);
                              _refreshAllData();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _refreshAllData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Terapkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
    );
  }

  Widget _buildProductsGrid() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 12),
            Text(
              'Belum Ada Produk',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tidak ada produk yang cocok dengan pencarian atau filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final displayItems = _items.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final informasiUsaha =
            item['informasi_usaha'] ?? item['informasiUsaha'];
        final pemilik = informasiUsaha != null
            ? (informasiUsaha['pemilik'] ?? informasiUsaha['penduduk'])
            : null;
        final phone =
            pemilik != null ? (pemilik['no_hp'] ?? pemilik['noHp'] ?? '') : '';
        final name = item['nama_produk'] ?? item['namaProduk'] ?? '-';
        final desc = item['deskripsi'] ?? '';
        final harga = item['harga'];
        int hargaNum;
        if (harga is num) {
          hargaNum = harga.toInt();
        } else {
          final String hStr = '${harga ?? ''}'.trim();
          final num? tryNum = num.tryParse(hStr.replaceAll(',', '.'));
          if (tryNum != null) {
            hargaNum = tryNum.toDouble().round();
          } else {
            hargaNum = int.tryParse(hStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
          }
        }
        final priceStr = NumberFormat.currency(
                locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
            .format(hargaNum);
        final imageUrl = item['foto_url'] ?? '';
        final namaUsaha = informasiUsaha != null
            ? (informasiUsaha['nama_usaha'] ?? informasiUsaha['namaUsaha'])
            : null;

        return _buildProductCard(
          name: name,
          description: desc,
          price: priceStr,
          phoneNumber: phone,
          imageUrl: imageUrl,
          storeName: namaUsaha?.toString(),
          id: (item['id'] as num?)?.toInt(),
        );
      },
    );
  }

  Widget _buildProductCard({
    required String name,
    required String description,
    required String price,
    required String phoneNumber,
    String? imageUrl,
    String? storeName,
    int? id,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              productId: id,
              name: name,
              price: price,
              description: description,
              phoneNumber: phoneNumber,
              imageUrl: imageUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF1F5F9),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 32,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 32,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (storeName != null && storeName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.store_outlined,
                          size: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
