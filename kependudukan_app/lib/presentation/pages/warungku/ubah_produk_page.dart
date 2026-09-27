import 'package:flutter/material.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/dataku/dataku_page.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/warungku_api_service.dart';
import 'package:ladimas/core/constants/app_constants.dart';

class UbahProdukPage extends StatefulWidget {
  final Penduduk penduduk;
  final Map<String, dynamic> productData;
  final int? productId;

  const UbahProdukPage({
    Key? key,
    required this.penduduk,
    required this.productData,
    this.productId,
  }) : super(key: key);

  @override
  State<UbahProdukPage> createState() => _UbahProdukPageState();
}

class _UbahProdukPageState extends State<UbahProdukPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaProdukController;
  late TextEditingController _hargaController;
  late TextEditingController _stokController;
  late TextEditingController _deskripsiController;

  late String _selectedKlasifikasi;

  final WarungkuApiService _api = WarungkuApiService(
      client: http.Client(), authLocalStorage: AuthLocalStorage());
  bool _submitting = false;
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  // Opsi dari API
  List<String> _klassOptions = [];
  List<Map<String, dynamic>> _jenisOptions = [];
  int? _selectedJenisId;

  String? _detailImageUrl;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data (gunakan nilai mentah jika ada)
    _namaProdukController =
        TextEditingController(text: widget.productData['name'] ?? '');
    final dynamic hargaRaw = widget.productData['harga'];
    final String hargaInit = (hargaRaw is num)
        ? hargaRaw.toInt().toString()
        : (widget.productData['price']
                ?.toString()
                .replaceAll(RegExp(r'[^\d]'), '') ??
            '');
    _hargaController = TextEditingController(text: hargaInit);
    final dynamic stokRaw = widget.productData['stok'];
    final String stokInit = (stokRaw is num)
        ? stokRaw.toInt().toString()
        : (widget.productData['stock']
                ?.toString()
                .replaceAll(RegExp(r'[^\d]'), '') ??
            '');
    _stokController = TextEditingController(text: stokInit);
    _deskripsiController =
        TextEditingController(text: widget.productData['description'] ?? '');

    _selectedKlasifikasi = widget.productData['klasifikasi'] ?? '';

    _detailImageUrl = widget.productData['imageUrl']?.toString();

    // Load data secara berurutan untuk memastikan dropdown menampilkan data yang benar
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Jika ada productId, gunakan endpoint edit yang mengembalikan data + filter
    if (widget.productId != null) {
      await _loadEditData(widget.productId!);
    } else {
      // Jika tidak ada productId, load filter biasa
      await _loadFilters();
    }
  }

  Future<void> _loadEditData(int id) async {
    try {
      print('🔄 Loading edit data for product ID: $id');
      final editData = await _api.getEditData(id);
      print('📦 Edit data response: $editData');

      final data = editData['data'] as Map<String, dynamic>? ?? {};
      final filters = editData['filters'] as Map<String, dynamic>? ?? {};

      // Extract product data with safe type casting
      final String? jenis = data['jenis']?.toString();
      final String? klas = data['klasifikasi']?.toString();

      // Safe casting for numeric values
      final int? harga = () {
        final value = data['harga'];
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }();

      final int? stok = () {
        final value = data['stok'];
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }();

      final String? foto = data['foto_url']?.toString();

      final int? jenisMasterId = () {
        final value = data['jenis_master_id'];
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }();

      print(
          '📦 Product data - Jenis: $jenis, Klasifikasi: $klas, Harga: $harga, Stok: $stok, JenisMasterId: $jenisMasterId');

      // Extract filter data
      final List<dynamic> klassList =
          filters['klasifikasi'] as List<dynamic>? ?? [];
      final List<dynamic> jenisList = filters['jenis'] as List<dynamic>? ?? [];

      print('📋 Filter data - Klasifikasi: $klassList, Jenis: $jenisList');

      // Normalize klasifikasi
      final List<String> normalizedKlas = [];
      for (final k in klassList.map((e) => e.toString())) {
        final exists =
            normalizedKlas.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalizedKlas.add(k);
      }

      // Filter jenis berdasarkan klasifikasi yang dipilih
      List<Map<String, dynamic>> filteredJenis = [];
      if (klas != null && klas.isNotEmpty) {
        filteredJenis = jenisList
            .whereType<Map>()
            .where((j) =>
                (j['klasifikasi']?.toString().toLowerCase() ?? '') ==
                klas.toLowerCase())
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }

      print('📋 Filtered jenis for klasifikasi "$klas": $filteredJenis');

      setState(() {
        // Update product data
        if (klas != null && klas.isNotEmpty) _selectedKlasifikasi = klas;
        if (harga != null) _hargaController.text = harga.toString();
        if (stok != null) _stokController.text = stok.toString();
        if (foto != null && foto.isNotEmpty) _detailImageUrl = foto;

        // Update filter options
        _klassOptions = normalizedKlas;
        _jenisOptions = filteredJenis;

        // Set jenis ID yang benar
        if (jenisMasterId != null) {
          _selectedJenisId = jenisMasterId;
          print('✅ Set selectedJenisId to: $jenisMasterId');
        } else {
          _selectedJenisId = null;
          print('⚠️ Reset selectedJenisId to null');
        }
      });

      print('✅ Edit data loaded successfully');
    } catch (e) {
      print('❌ Error loading edit data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data edit: $e')),
        );
      }
    }
  }

  Future<void> _loadFilters() async {
    try {
      final klass = await _api.getKlasifikasiList();
      // normalisasi unique
      final List<String> normalized = [];
      for (final k in klass.map((e) => e.toString())) {
        final exists =
            normalized.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalized.add(k);
      }

      setState(() {
        _klassOptions = normalized;
        // Reset jenis options saat pertama kali load
        _jenisOptions = [];
        _selectedJenisId = null;
      });
    } catch (e) {
      print('❌ Error loading filters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat klasifikasi: $e')),
        );
      }
    }
  }

  Future<void> _loadJenisByKlasifikasi(String klasifikasi) async {
    try {
      print('🔄 Loading jenis for klasifikasi: $klasifikasi');
      final jenisList =
          await _api.getJenisByKlasifikasi(klasifikasi.toLowerCase());
      print('📋 Jenis response: $jenisList');

      if (!mounted) return;

      setState(() {
        _jenisOptions = jenisList;
        _selectedJenisId = null; // Reset selection
      });
      print('✅ Jenis loaded successfully');
    } catch (e) {
      print('❌ Error loading jenis: $e');
      setState(() {
        _jenisOptions = [];
        _selectedJenisId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat jenis: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filteredJenisByKlasifikasi() {
    if (_selectedKlasifikasi.isEmpty) return _jenisOptions;
    final sel = _selectedKlasifikasi.toLowerCase();
    return _jenisOptions.where((j) {
      final jk = (j['klasifikasi'] ??
              j['klasifikasi_nama'] ??
              j['classification'] ??
              j['klasifikasiName'] ??
              '')
          .toString()
          .toLowerCase();
      if (jk.isNotEmpty) return jk == sel;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _hargaController.dispose();
    _stokController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  String? _resolveUrl(String? url) {
    if (url == null) return null;
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final String noSlash =
        trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '${AppConstants.storageUrl}/$noSlash';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A47DC)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title like Usaha Saya page
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 10, 0, 20),
                child: Center(
                  child: Text(
                    'Ubah Produk',
                    style: TextStyle(
                      color: Color(0xFF4A47DC),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              // Foto Barang
              _buildFotoBarang(),
              const SizedBox(height: 20),

              // Nama Produk
              _buildTextField(
                label: 'Nama Produk',
                controller: _namaProdukController,
                hintText: 'Masukkan nama produk',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama produk harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Klasifikasi
              _buildDropdownField(
                label: 'Klasifikasi',
                value:
                    _selectedKlasifikasi.isEmpty ? null : _selectedKlasifikasi,
                items:
                    _klassOptions.isEmpty ? ['Barang', 'Jasa'] : _klassOptions,
                onChanged: (value) async {
                  final newKlas = (value ?? '').toString();
                  setState(() {
                    _selectedKlasifikasi = newKlas;
                    _jenisOptions = [];
                    _selectedJenisId = null;
                  });

                  if (newKlas.isNotEmpty) {
                    await _loadJenisByKlasifikasi(newKlas);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Jenis
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonFormField<int>(
                  value: _selectedJenisId,
                  isExpanded: true,
                  selectedItemBuilder: (context) {
                    final list = _filteredJenisByKlasifikasi();
                    return list.map((j) {
                      final String label =
                          (j['jenis'] ?? j['nama'] ?? j['name'] ?? '-')
                              .toString();
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList();
                  },
                  items: [
                    ..._filteredJenisByKlasifikasi().map((j) {
                      final dynamic idVal =
                          j['id'] ?? j['jenis_master_id'] ?? j['jenisId'];
                      final int? parsedId = (idVal is num)
                          ? idVal.toInt()
                          : int.tryParse(idVal?.toString() ?? '');
                      final String label =
                          (j['jenis'] ?? j['nama'] ?? j['name'] ?? '-')
                              .toString();
                      if (parsedId == null)
                        return const DropdownMenuItem<int>(
                            value: null, child: Text('-'));
                      return DropdownMenuItem<int>(
                        value: parsedId,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                  ],
                  onChanged: (v) => setState(() => _selectedJenisId = v),
                  decoration: const InputDecoration(
                    labelText: 'Jenis',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                  ),
                  hint: const Text('Pilih jenis'),
                ),
              ),
              const SizedBox(height: 16),

              // Deskripsi
              _buildTextAreaField(
                label: 'Deskripsi',
                controller: _deskripsiController,
                hintText: 'Masukkan deskripsi produk',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Deskripsi harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Harga
              _buildTextField(
                label: 'Harga',
                controller: _hargaController,
                hintText: 'Masukkan harga',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Harga harus diisi';
                  }
                  if (int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ==
                      null) {
                    return 'Harga harus berupa angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Stok
              _buildTextField(
                label: 'Stok',
                controller: _stokController,
                hintText: 'Masukkan jumlah stok',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Stok harus diisi';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Stok harus berupa angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF4A47DC),
        unselectedItemColor: Colors.grey,
        currentIndex: 1, // Ubah Produk
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.storefront_sharp, size: 28),
              label: 'Ubah Produk'),
          BottomNavigationBarItem(
              icon: Icon(Icons.apps, size: 28), label: 'Informasi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long, size: 28), label: 'Tagihan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.info_outline, size: 28), label: 'Portal'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_2, size: 28), label: 'Dataku'),
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
              // Current page - Ubah Produk
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PendudukHomePage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TagihanPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DocumentServicesWebViewPage(penduduk: widget.penduduk),
                ),
              );
              break;
            case 5:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DatakuPage(penduduk: widget.penduduk),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildFotoBarang() {
    String? rawUrl = _detailImageUrl;
    final String? initialUrl = _resolveUrl(rawUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Barang',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final XFile? xfile =
                    await _picker.pickImage(source: ImageSource.gallery);
                if (xfile != null) {
                  setState(() => _pickedImage = File(xfile.path));
                }
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: () {
                  if (_pickedImage != null) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_pickedImage!, fit: BoxFit.cover),
                    );
                  }
                  final showUrl =
                      _resolveUrl(_detailImageUrl ?? (initialUrl ?? ''));
                  if (showUrl != null && showUrl.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        showUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }
                  return const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 32,
                      color: Colors.grey,
                    ),
                  );
                }(),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ubah Foto',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A47DC),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A47DC)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A47DC)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final List<String> uniqueItems = [
      ...{for (final s in items) s}
    ].toList();
    final String? safeValue = (value != null &&
            uniqueItems.any((x) => x.toLowerCase() == value.toLowerCase()))
        ? uniqueItems.firstWhere((x) => x.toLowerCase() == value.toLowerCase())
        : value; // pertahankan value lama untuk placeholder
    // Jika items kosong tapi ada nilai lama, tampilkan sebagai placeholder agar user melihat nilai saat ini
    final List<String> effectiveItems =
        uniqueItems.isEmpty && (safeValue != null && safeValue.isNotEmpty)
            ? [safeValue]
            : uniqueItems;
    final String? effectiveValue = (safeValue != null &&
            effectiveItems
                .any((x) => x.toLowerCase() == safeValue.toLowerCase()))
        ? effectiveItems
            .firstWhere((x) => x.toLowerCase() == safeValue.toLowerCase())
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: effectiveValue,
            onChanged: onChanged,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
            items: effectiveItems.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Hapus Produk Button
        Expanded(
          child: ElevatedButton(
            onPressed: _submitting
                ? null
                : () {
                    _showDeleteConfirmation();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Hapus Produk',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Ubah Button
        Expanded(
          child: ElevatedButton(
            onPressed: _submitting
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      if (_selectedJenisId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Silakan pilih Jenis terlebih dahulu')),
                        );
                        return;
                      }
                      setState(() => _submitting = true);
                      try {
                        final id = widget.productData['id'] is int
                            ? widget.productData['id'] as int
                            : int.tryParse(
                                    '${widget.productData['id'] ?? '0'}') ??
                                0;
                        final ok = await _api.updateProduct(
                          id: id,
                          namaProduk: _namaProdukController.text.trim(),
                          deskripsi: _deskripsiController.text.trim(),
                          harga: int.parse(_hargaController.text
                              .replaceAll(RegExp(r'[^\d]'), '')),
                          stok: int.parse(_stokController.text),
                          jenisMasterId: _selectedJenisId,
                          klasifikasiMasterId: () {
                            // cari salah satu jenis yang cocok untuk ambil id klasifikasi jika API memerlukannya
                            final all = _jenisOptions;
                            if (all.isEmpty) return null;
                            final match = all.firstWhere(
                              (j) =>
                                  (j['id'] as num?)?.toInt() ==
                                  _selectedJenisId,
                              orElse: () => {},
                            );
                            if (match.isEmpty) return null;
                            // jika backend memerlukan id klasifikasi terpisah, sering tidak ada; jika ada gunakan field 'klasifikasi_master_id' atau mapping khusus
                            final dynamic klasId =
                                match['klasifikasi_master_id'];
                            return (klasId is num)
                                ? klasId.toInt()
                                : int.tryParse('${klasId ?? ''}');
                          }(),
                          foto: _pickedImage,
                        );
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Produk berhasil diubah!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal mengubah produk: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A47DC),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Ubah',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text('Apakah Anda yakin ingin menghapus produk ini?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _submitting = true);
                try {
                  final id = widget.productData['id'] is int
                      ? widget.productData['id'] as int
                      : int.tryParse('${widget.productData['id'] ?? '0'}') ?? 0;
                  final ok = await _api.deleteProduct(id);
                  if (ok) {
                    final rootContext = mounted ? this.context : null;
                    if (rootContext != null) {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(
                          content: Text('Produk berhasil dihapus!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    if (mounted) Navigator.pop(this.context, true);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus produk: $e')),
                  );
                } finally {
                  if (mounted) setState(() => _submitting = false);
                }
              },
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
