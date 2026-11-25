import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/warungku_api_service.dart';
import 'package:ladimas/presentation/pages/warungku/product_detail_page.dart';

class SemuaProdukPage extends StatefulWidget {
  const SemuaProdukPage({Key? key}) : super(key: key);

  @override
  State<SemuaProdukPage> createState() => _SemuaProdukPageState();
}

class _SemuaProdukPageState extends State<SemuaProdukPage> {
  final WarungkuApiService _api = WarungkuApiService(
    client: http.Client(),
    authLocalStorage: AuthLocalStorage(),
  );

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Ambil SELURUH data dari API
  Future<void> _fetchAllProducts() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getAll(
        perPage: 1000,
      );

      final items = (result['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (mounted) {
        setState(() {
          _allItems = items;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat semua produk: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _allItems;
    final query = _searchQuery.toLowerCase();
    return _allItems.where((item) {
      final name = (item['nama_produk'] ?? item['namaProduk'] ?? '')
          .toString()
          .toLowerCase();
      final desc = (item['deskripsi'] ?? '').toString().toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Semua Produk',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllProducts,
        color: AppTheme.primaryColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
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
                                hintText: 'Cari di semua produk...',
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
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.0),
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
                    const SizedBox(height: 14),

                    // Counter badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Produk (${filtered.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: const Text(
                              'Reset Pencarian',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.remove_shopping_cart_outlined,
                              size: 48,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak Ada Produk Ditemukan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ditemukan produk dengan kata kunci "$_searchQuery".'
                                  : 'Belum ada produk yang terdaftar saat ini.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final informasiUsaha =
                              item['informasi_usaha'] ?? item['informasiUsaha'];
                          final pemilik = informasiUsaha != null
                              ? (informasiUsaha['pemilik'] ??
                                  informasiUsaha['penduduk'])
                              : null;
                          final phone = pemilik != null
                              ? (pemilik['no_hp'] ?? pemilik['noHp'] ?? '')
                              : '';
                          final name =
                              item['nama_produk'] ?? item['namaProduk'] ?? '-';
                          final desc = item['deskripsi'] ?? '';
                          final harga = item['harga'];
                          int hargaNum;
                          if (harga is num) {
                            hargaNum = harga.toInt();
                          } else {
                            final String hStr = '${harga ?? ''}'.trim();
                            final num? tryNum =
                                num.tryParse(hStr.replaceAll(',', '.'));
                            if (tryNum != null) {
                              hargaNum = tryNum.toDouble().round();
                            } else {
                              hargaNum = int.tryParse(
                                      hStr.replaceAll(RegExp(r'[^\d]'), '')) ??
                                  0;
                            }
                          }
                          final priceStr = NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(hargaNum);
                          final imageUrl = item['foto_url'] ?? '';
                          final namaUsaha = informasiUsaha != null
                              ? (informasiUsaha['nama_usaha'] ??
                                  informasiUsaha['namaUsaha'])
                              : null;

                          return _buildProductCard(
                            id: (item['id'] as num?)?.toInt(),
                            name: name,
                            description: desc,
                            price: priceStr,
                            phoneNumber: phone,
                            imageUrl: imageUrl,
                            storeName: namaUsaha?.toString(),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
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
