import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/warungku_api_service.dart';

class TambahProdukPage extends StatefulWidget {
  final Penduduk penduduk;

  const TambahProdukPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<TambahProdukPage> createState() => _TambahProdukPageState();
}

class _TambahProdukPageState extends State<TambahProdukPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaProdukController = TextEditingController();
  final _hargaController = TextEditingController();
  final _stokController = TextEditingController();
  final _deskripsiController = TextEditingController();

  final WarungkuApiService _api = WarungkuApiService(
      client: http.Client(), authLocalStorage: AuthLocalStorage());
  bool _submitting = false;
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  // Opsi dari API
  List<String> _klassOptions = [];
  List<Map<String, dynamic>> _jenisOptions = [];
  String _selectedKlasifikasi = '';
  int? _selectedJenisId;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final klass = await _api.getKlasifikasiList();
      // normalisasi & unique (case-insensitive)
      final List<String> normalized = [];
      for (final k in klass.map((e) => e.toString())) {
        final exists =
            normalized.any((x) => x.toLowerCase() == k.toLowerCase());
        if (!exists) normalized.add(k);
      }
      setState(() {
        _klassOptions = normalized;
        // jangan auto-select
        _selectedKlasifikasi = '';
        _jenisOptions = [];
        _selectedJenisId = null;
      });
    } catch (_) {}
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
      return true; // jika API tidak menyediakan label klasifikasi pada jenis, tampilkan semua
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.whiteColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tambah Produk',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              // Pilih Kategori (Klasifikasi)
              _buildDropdownKlasifikasi(),
              const SizedBox(height: 16),

              // Pilih Jenis
              _buildDropdownJenis(),
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
              const SizedBox(height: 28),

              // Tombol Tambah
              _buildTambahButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Upload Foto
  Widget _buildFotoBarang() {
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
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: _pickedImage == null
                ? Column(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8BAEFA)),
                        ),
                        child: const Text(
                          'Explore File',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pickedImage!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
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

  // Dropdown Pilih Kategori dengan Menu Popup Ter-Styling
  Widget _buildDropdownKlasifikasi() {
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
            value: _selectedKlasifikasi.isEmpty ? null : _selectedKlasifikasi,
            dropdownColor: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            menuMaxHeight: 250,
            items: _klassOptions
                .map((k) => DropdownMenuItem<String>(
                      value: k,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ))
                .toList(),
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
              try {
                final jenis =
                    await _api.getJenisByKlasifikasi(newKlas.toLowerCase());
                if (!mounted) return;
                setState(() {
                  _jenisOptions = jenis;
                  _selectedJenisId = jenis.isNotEmpty
                      ? ((jenis.first['id'] as num?)?.toInt())
                      : null;
                });
              } catch (_) {}
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

  // Dropdown Pilih Jenis dengan Menu Popup Ter-Styling
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

  // Tombol Tambah Produk Full-Width
  Widget _buildTambahButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitting
            ? null
            : () async {
                if (_formKey.currentState!.validate()) {
                  setState(() => _submitting = true);
                  try {
                    final ok = await _api.createProduct(
                      namaProduk: _namaProdukController.text.trim(),
                      deskripsi: _deskripsiController.text.trim(),
                      harga: int.parse(_hargaController.text
                          .replaceAll(RegExp(r'[^\d]'), '')),
                      stok: int.parse(_stokController.text),
                      jenisMasterId: _selectedJenisId,
                      foto: _pickedImage,
                    );
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Produk berhasil ditambahkan!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menambah produk: $e')),
                    );
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
                'Tambah',
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
