import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/dataku/dataku_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
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
    // Initialize controllers dengan data yang ada
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

    _initializeData();
  }

  Future<void> _initializeData() async {
    if (widget.productId != null) {
      await _loadEditData(widget.productId!);
    } else {
      await _loadFilters();
    }
  }

  Future<void> _loadEditData(int id) async {
    try {
      final editData = await _api.getEditData(id);

      final data = editData['data'] as Map<String, dynamic>? ?? {};
      final filters = editData['filters'] as Map<String, dynamic>? ?? {};

      final String? klas = data['klasifikasi']?.toString();

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

      final List<dynamic> klassList =
          filters['klasifikasi'] as List<dynamic>? ?? [];
      final List<dynamic> jenisList = filters['jenis'] as List<dynamic>? ?? [];

      final List<String> normalizedKlas = [];
      for (final k in klassList.map((e) => e.toString())) {
        final exists =
            normalizedKlas.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalizedKlas.add(k);
      }

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

      setState(() {
        if (klas != null && klas.isNotEmpty) _selectedKlasifikasi = klas;
        if (harga != null) _hargaController.text = harga.toString();
        if (stok != null) _stokController.text = stok.toString();
        if (foto != null && foto.isNotEmpty) _detailImageUrl = foto;

        _klassOptions = normalizedKlas;
        _jenisOptions = filteredJenis;

        if (jenisMasterId != null) {
          _selectedJenisId = jenisMasterId;
        } else {
          _selectedJenisId = null;
        }
      });
    } catch (e) {
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
      final List<String> normalized = [];
      for (final k in klass.map((e) => e.toString())) {
        final exists =
            normalized.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalized.add(k);
      }

      setState(() {
        _klassOptions = normalized;
        _jenisOptions = [];
        _selectedJenisId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat klasifikasi: $e')),
        );
      }
    }
  }

  Future<void> _loadJenisByKlasifikasi(String klasifikasi) async {
    try {
      final jenisList =
          await _api.getJenisByKlasifikasi(klasifikasi.toLowerCase());

      if (!mounted) return;

      setState(() {
        _jenisOptions = jenisList;
        _selectedJenisId = null;
      });
    } catch (e) {
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.whiteColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ubah Produk',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFotoBarang(),
              const SizedBox(height: 20),

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

              _buildDropdownKlasifikasi(),
              const SizedBox(height: 16),

              _buildDropdownJenis(),
              const SizedBox(height: 16),

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

              _buildTextField(
                label: 'Harga',
                controller: _hargaController,
                hintText: 'Masukkan harga produk',
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
              const SizedBox(height: 28),

              // Tombol Ubah / Simpan Perubahan
              _buildActionButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Upload/Preview Foto Barang
  Widget _buildFotoBarang() {
    String? rawUrl = _detailImageUrl;
    final String? initialUrl = _resolveUrl(rawUrl);
    final String? showUrl = _resolveUrl(_detailImageUrl ?? (initialUrl ?? ''));
    final bool hasImage =
        _pickedImage != null || (showUrl != null && showUrl.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Barang',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final XFile? xfile =
                await _picker.pickImage(source: ImageSource.gallery);
            if (xfile != null) {
              setState(() => _pickedImage = File(xfile.path));
            }
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                vertical: hasImage ? 12 : 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: () {
              if (_pickedImage != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _pickedImage!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              }
              if (showUrl != null && showUrl.isNotEmpty) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    showUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose a photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'JPG, JPEG, PNG',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF8BAEFA)),
                    ),
                    child: const Text(
                      'Explore File',
                      style: TextStyle(
                        color: Color(0xFF4A74EA),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            }(),
          ),
        ),
      ],
    );
  }

  // Widget Input Text Custom
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  // Widget Text Area Custom
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  // Dropdown Pilih Kategori
  Widget _buildDropdownKlasifikasi() {
    final List<String> uniqueItems = [
      ...{
        for (final s
            in (_klassOptions.isEmpty ? ['Barang', 'Jasa'] : _klassOptions))
          s
      }
    ].toList();
    final String? value =
        _selectedKlasifikasi.isEmpty ? null : _selectedKlasifikasi;
    final String? safeValue = (value != null &&
            uniqueItems.any((x) => x.toLowerCase() == value.toLowerCase()))
        ? uniqueItems.firstWhere((x) => x.toLowerCase() == value.toLowerCase())
        : value;
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
        const Text(
          'Pilih Kategori',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            value: effectiveValue,
            dropdownColor: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            items: effectiveItems.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
            hint: Text('Pilih kategori',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
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
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // Dropdown Pilih Jenis
  Widget _buildDropdownJenis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Jenis',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<int>(
            value: _selectedJenisId,
            isExpanded: true,
            dropdownColor: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
            hint: Text('Pilih jenis',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            selectedItemBuilder: (context) {
              final list = _filteredJenisByKlasifikasi();
              return list.map((j) {
                final String label =
                    (j['jenis'] ?? j['nama'] ?? j['name'] ?? '-').toString();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
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
                    (j['jenis'] ?? j['nama'] ?? j['name'] ?? '-').toString();
                if (parsedId == null) {
                  return const DropdownMenuItem<int>(
                      value: null, child: Text('-'));
                }
                return DropdownMenuItem<int>(
                  value: parsedId,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              })
            ],
            onChanged: (v) => setState(() => _selectedJenisId = v),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // Tombol Simpan Perubahan Full-Width
  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitting
            ? null
            : () async {
                if (_formKey.currentState!.validate()) {
                  if (_selectedJenisId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Silakan pilih Jenis terlebih dahulu')),
                    );
                    return;
                  }
                  setState(() => _submitting = true);
                  try {
                    final id = widget.productData['id'] is int
                        ? widget.productData['id'] as int
                        : int.tryParse('${widget.productData['id'] ?? '0'}') ??
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
                        final all = _jenisOptions;
                        if (all.isEmpty) return null;
                        final match = all.firstWhere(
                          (j) => (j['id'] as num?)?.toInt() == _selectedJenisId,
                          orElse: () => {},
                        );
                        if (match.isEmpty) return null;
                        final dynamic klasId = match['klasifikasi_master_id'];
                        return (klasId is num)
                            ? klasId.toInt()
                            : int.tryParse('${klasId ?? ''}');
                      }(),
                      foto: _pickedImage,
                    );
                    if (ok) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Produk berhasil diubah!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context, true);
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal mengubah produk: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Simpan Perubahan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
