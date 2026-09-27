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
                    'Tambah Produk',
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedKlasifikasi.isEmpty
                      ? null
                      : _selectedKlasifikasi,
                  items: _klassOptions
                      .map((k) => DropdownMenuItem<String>(
                            value: k,
                            child: Text(k),
                          ))
                      .toList(),
                  hint: const Text('Pilih klasifikasi'),
                  onChanged: (value) async {
                    final newKlas = (value ?? '').toString();
                    setState(() {
                      _selectedKlasifikasi = newKlas;
                      _jenisOptions = [];
                      _selectedJenisId = null;
                    });
                    try {
                      final jenis = await _api
                          .getJenisByKlasifikasi(newKlas.toLowerCase());
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
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
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

              // Tombol Tambah
              _buildTambahButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF4A47DC),
        unselectedItemColor: Colors.grey,
        currentIndex: 1, // Tambah Produk
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.storefront_sharp, size: 28),
              label: 'Tambah Produk'),
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
              // Current page - Tambah Produk
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
                child: _pickedImage == null
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: Colors.grey,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_pickedImage!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Tambah Foto',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A47DC),
                    fontWeight: FontWeight.w500,
                  )),
            )
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
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
            items: items.map((String item) {
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

  Widget _buildTambahButton() {
    return Align(
      alignment: Alignment.centerRight,
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
          backgroundColor: const Color(0xFF4A47DC),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
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
