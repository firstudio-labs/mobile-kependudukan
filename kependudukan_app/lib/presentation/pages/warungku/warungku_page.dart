import 'package:flutter/material.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/presentation/pages/usaha_saya/usaha_saya_page.dart';
import 'package:ladimas/presentation/pages/warungku/product_detail_page.dart';
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
  // pressed state for mini menu icons
  final Map<String, bool> _miniPressed = {'Usaha': false, 'Filter': false};

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh data ketika app kembali ke foreground
      print('App resumed, refreshing data...');
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
      setState(() {
        _items = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat produk: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFilters() async {
    try {
      print('Loading filters...');

      // Load klasifikasi menggunakan endpoint terpisah
      final klass = await _api.getKlasifikasiList();
      print('Klasifikasi options: $klass');

      // Normalisasi unique
      final List<String> normalized = [];
      for (final k in klass.map((e) => e.toString())) {
        final exists =
            normalized.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalized.add(k);
      }

      setState(() {
        _klassOptions = normalized;
        _jenisOptions = []; // Reset jenis options
      });
    } catch (e) {
      print('Error loading filters: $e');
      // Show error to user
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
      setState(() => _provinces = data);
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
      // Cari province code berdasarkan ID
      final province = _provinces.firstWhere(
        (p) => p['id']?.toString() == provinceId,
        orElse: () => {},
      );
      final provinceCode = province['code']?.toString();

      if (provinceCode != null) {
        final data = await _api.getDistricts(provinceCode);
        setState(() => _districts = data);
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
      // Cari district code berdasarkan ID
      final district = _districts.firstWhere(
        (d) => d['id']?.toString() == districtId,
        orElse: () => {},
      );
      final districtCode = district['code']?.toString();

      if (districtCode != null) {
        final data = await _api.getSubDistricts(districtCode);
        setState(() => _subDistricts = data);
      }
    } catch (_) {}
  }

  Future<void> _loadVillages(String subDistrictId) async {
    setState(() {
      _villages = [];
      _selectedVillage = null;
    });
    try {
      // Cari sub district code berdasarkan ID
      final subDistrict = _subDistricts.firstWhere(
        (s) => s['id']?.toString() == subDistrictId,
        orElse: () => {},
      );
      final subDistrictCode = subDistrict['code']?.toString();

      if (subDistrictCode != null) {
        final data = await _api.getVillages(subDistrictCode);
        setState(() => _villages = data);
      }
    } catch (_) {}
  }

  Future<void> _loadJenisByKlasifikasi(String klasifikasi,
      {bool resetJenisId = true}) async {
    try {
      print('Loading jenis for klasifikasi: $klasifikasi');
      final jenis = await _api.getJenisByKlasifikasi(klasifikasi.toLowerCase());
      print('Jenis options: $jenis');

      // Validasi data jenis
      List<Map<String, dynamic>> validJenis = [];
      for (var item in jenis) {
        if (item['id'] != null && item['jenis'] != null) {
          validJenis.add(Map<String, dynamic>.from(item));
        }
      }

      setState(() {
        _jenisOptions = validJenis;
        if (resetJenisId) {
          _selectedJenisId = null; // Reset pilihan jenis
        }
      });
    } catch (e) {
      print('Error loading jenis: $e');
      setState(() {
        _jenisOptions = [];
        if (resetJenisId) {
          _selectedJenisId = null;
        }
      });
    }
  }

  // Ambil data jenis tanpa mengubah UI (untuk dipakai di modal dengan setModal)
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
    print('Refreshing all data...');
    setState(() {
      _isLoading = true;
    });

    try {
      // Load ulang semua data
      await Future.wait([
        _loadItems(search: _searchController.text.trim()),
        _loadFilters(),
        _loadProvinces(),
      ]);

      print('All data refreshed successfully');
    } catch (e) {
      print('Error refreshing data: $e');
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
      backgroundColor: const Color(0xFFF5F6FA),
      // Tanpa AppBar agar konsisten dengan penduduk home page
      body: Column(
        children: [
          // Header Section
          _buildHeaderSection(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Section
                  _buildSearchSection(),

                  // Grid Produk
                  _isLoading
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: CircularProgressIndicator(),
                        ))
                      : _buildProductsGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF4A47DC),
        unselectedItemColor: Colors.grey,
        currentIndex: 1, // Warungku
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.storefront_sharp, size: 28), label: 'Warungku'),
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
              // Current page - Warungku
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
    );
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
          children: const [
            Text(
              'Warungku',
              style: TextStyle(
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

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari Produk',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  suffixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                onSubmitted: (value) => _loadItems(search: value),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildMiniMenu(
            icon: Icons.store,
            label: 'Usaha',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UsahaSayaPage(penduduk: widget.penduduk),
                ),
              ).then((result) {
                if (result == true) {
                  // Refresh semua data termasuk filter
                  _refreshAllData();
                }
              });
            },
          ),
          const SizedBox(width: 8),
          _buildMiniMenu(
            icon: Icons.filter_list,
            label: 'Filter',
            onTap: _showFilterSheet,
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() async {
    // Load jenis jika ada klasifikasi yang dipilih tapi jenis options kosong
    if (_selectedKlasifikasi != null && _jenisOptions.isEmpty) {
      await _loadJenisByKlasifikasi(_selectedKlasifikasi!, resetJenisId: false);
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModal) {
          bool loadingJenis = false;
          bool loadingDistricts = false;
          bool loadingSubDistricts = false;
          bool loadingVillages = false;
          // Validasi dan reset nilai yang tidak valid
          String? validKlasifikasi = _selectedKlasifikasi;
          int? validJenisId = _selectedJenisId;

          // Pastikan klasifikasi yang dipilih ada dalam options
          if (validKlasifikasi != null &&
              !_klassOptions.contains(validKlasifikasi)) {
            validKlasifikasi = null;
          }

          // Pastikan jenis yang dipilih ada dalam options
          if (validJenisId != null && _jenisOptions.isNotEmpty) {
            final jenisExists = _jenisOptions
                .any((j) => (j['id'] as num).toInt() == validJenisId);
            if (!jenisExists) {
              validJenisId = null;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Klasifikasi
                  DropdownButtonFormField<String>(
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
                    decoration: const InputDecoration(labelText: 'Klasifikasi'),
                  ),
                  const SizedBox(height: 12),
                  // Jenis
                  DropdownButtonFormField<int>(
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
                    decoration: const InputDecoration(labelText: 'Jenis'),
                  ),
                  if (loadingJenis) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 12),
                  // Wilayah cascade
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Semua Provinsi')),
                      ..._provinces.map((p) => DropdownMenuItem<String>(
                          value: p['id']?.toString(), // ✅ Gunakan ID numerik
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
                    decoration: const InputDecoration(labelText: 'Provinsi'),
                  ),
                  if (loadingDistricts) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Semua Kabupaten/Kota')),
                      ..._districts.map((d) => DropdownMenuItem<String>(
                          value: d['id']?.toString(), // ✅ Gunakan ID numerik
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
                    decoration:
                        const InputDecoration(labelText: 'Kabupaten/Kota'),
                  ),
                  if (loadingSubDistricts) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedSubDistrict,
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Semua Kecamatan')),
                      ..._subDistricts.map((s) => DropdownMenuItem<String>(
                          value: s['id']?.toString(), // ✅ Gunakan ID numerik
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
                    decoration: const InputDecoration(labelText: 'Kecamatan'),
                  ),
                  if (loadingVillages) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedVillage,
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Semua Desa/Kelurahan')),
                      ..._villages.map((v) => DropdownMenuItem<String>(
                          value: v['id']?.toString(), // ✅ Gunakan ID numerik
                          child: Text(v['name']?.toString() ??
                              v['nama']?.toString() ??
                              '-')))
                    ],
                    onChanged: (v) => setModal(() => _selectedVillage = v),
                    decoration:
                        const InputDecoration(labelText: 'Desa/Kelurahan'),
                  ),
                  const SizedBox(height: 16),
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
                              _jenisOptions = []; // Reset jenis options juga
                            });
                            Navigator.pop(context);
                            _refreshAllData();
                          },
                          child: const Text('Reset'),
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
                            backgroundColor: const Color(0xFF4A47DC),
                          ),
                          child: const Text('Terapkan',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildMiniMenu({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isPressed = _miniPressed[label] == true;
    final Color iconColor =
        isPressed ? const Color(0xFF4A47DC) : (Colors.grey[700]!);
    return GestureDetector(
      onTapDown: (_) => setState(() => _miniPressed[label] = true),
      onTapUp: (_) => setState(() => _miniPressed[label] = false),
      onTapCancel: () => setState(() => _miniPressed[label] = false),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        child: Icon(
          icon,
          size: 28,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('Belum ada produk')),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
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
            hargaNum =
                int.tryParse(hStr.replaceAll(RegExp(r'[^\\d]'), '')) ?? 0;
          }
        }
        final priceStr = NumberFormat.currency(
                locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 0)
            .format(hargaNum);
        final imageUrl = item['foto_url'] ?? '';
        return _buildProductCard(
          name: name,
          description: desc,
          price: priceStr,
          phoneNumber: phone,
          imageUrl: imageUrl,
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A47DC),
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
}
