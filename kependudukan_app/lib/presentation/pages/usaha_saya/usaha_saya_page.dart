import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/dataku/dataku_page.dart';
import 'package:ladimas/presentation/pages/warungku/tambah_produk_page.dart';
import 'package:ladimas/presentation/pages/warungku/ubah_produk_page.dart';
import 'package:ladimas/presentation/pages/profile/profile_edit_page.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/warungku_api_service.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class UsahaSayaPage extends StatefulWidget {
  final Penduduk penduduk;

  const UsahaSayaPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<UsahaSayaPage> createState() => _UsahaSayaPageState();
}

class _UsahaSayaPageState extends State<UsahaSayaPage> {
  final WarungkuApiService _api = WarungkuApiService(
      client: http.Client(), authLocalStorage: AuthLocalStorage());
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  bool _changed = false;

  Future<bool> _hasBusinessInformation() async {
    try {
      final token = await AuthLocalStorage().getStoredToken();
      if (token == null || token.isEmpty) return false;

      final actualToken = token.contains('|') ? token.split('|')[1] : token;

      final response = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/biodata'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $actualToken',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResp = json.decode(response.body);
        if (jsonResp['status'] == 'SUCCESS' && jsonResp['data'] != null) {
          final data = jsonResp['data'];
          final informasiUsaha =
              data['informasi_usaha'] as Map<String, dynamic>?;

          if (informasiUsaha != null) {
            final namaUsaha = informasiUsaha['nama_usaha']?.toString() ?? '';
            final alamatUsaha = informasiUsaha['alamat']?.toString() ?? '';
            final kelompokUsaha =
                informasiUsaha['kelompok_usaha']?.toString() ?? '';

            return namaUsaha.isNotEmpty ||
                alamatUsaha.isNotEmpty ||
                kelompokUsaha.isNotEmpty;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBusinessInformationAndLoadItems();
  }

  Future<void> _checkBusinessInformationAndLoadItems() async {
    final hasBusinessInfo = await _hasBusinessInformation();
    if (!hasBusinessInfo) {
      _showBusinessInfoMissingDialog();
    } else {
      _loadItems();
    }
  }

  void _showBusinessInfoMissingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Informasi Usaha Belum Lengkap',
            style: TextStyle(
              color: Color(0xFF2C3259),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Anda belum memiliki informasi usaha. Silakan lengkapi informasi usaha terlebih dahulu sebelum menambahkan produk.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToProfileEditPage();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2C3259),
              ),
              child: const Text(
                'LENGKAPI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text(
                'BATAL',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToProfileEditPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditPage(penduduk: widget.penduduk),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _checkBusinessInformationAndLoadItems();
      }
    });
  }

  Future<void> _loadItems({String? search}) async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getMy(search: search, perPage: 20);
      final items = (result['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _items = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat produk saya: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(int productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: const Text('Apakah Anda yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteProduct(productId);
        _changed = true;
        _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus produk: $e')),
          );
        }
      }
    }
  }

  void _navigateToEditProduct(Map<String, dynamic> productMap) {
    final id = productMap['id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UbahProdukPage(
          penduduk: widget.penduduk,
          productId: id,
          productData: productMap,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _changed = true;
        _loadItems();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: const Text(
            'Semua Produk Saya',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchSection(),
              const SizedBox(height: 10),
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildProductList(),
            ],
          ),
        ),
        // Tombol Tambah Produk di Kanan Bawah
        floatingActionButton: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.only(bottom: 12, right: 8),
          child: FloatingActionButton(
            onPressed: () async {
              final hasBusinessInfo = await _hasBusinessInformation();
              if (!hasBusinessInfo) {
                _showBusinessInfoMissingDialog();
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TambahProdukPage(penduduk: widget.penduduk),
                ),
              ).then((result) {
                if (result == true) {
                  _changed = true;
                  _loadItems();
                }
              });
            },
            backgroundColor: AppTheme.primaryColor,
            elevation: 0,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2C3259)),
              decoration: const InputDecoration(
                hintText: 'Cari Produk',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (value) async {
                final hasBusinessInfo = await _hasBusinessInformation();
                if (!hasBusinessInfo) {
                  _showBusinessInfoMissingDialog();
                  return;
                }
                _loadItems(search: value);
              },
            ),
          ),
          const Icon(
            Icons.search,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('Belum ada produk')),
      );
    }

    return Column(
      children: _items.map((item) {
        final id = item['id'] is int
            ? item['id'] as int
            : int.tryParse('${item['id'] ?? '0'}') ?? 0;
        final name = item['nama_produk'] ?? '-';
        final description = item['deskripsi'] ?? '';
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
        final price = NumberFormat.currency(
                locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
            .format(hargaNum);
        final qty = item['stok'];
        int stokNum;
        if (qty is num) {
          stokNum = qty.toInt();
        } else {
          final String sStr = '${qty ?? ''}'.trim();
          final num? tryNum = num.tryParse(sStr.replaceAll(',', '.'));
          if (tryNum != null) {
            stokNum = tryNum.toDouble().round();
          } else {
            stokNum = int.tryParse(sStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
          }
        }
        final quantity = stokNum.toString();
        final imageUrl = item['foto_url'] ?? '';

        final Map<String, dynamic> productDataMap = {
          'id': id,
          'name': name,
          'description': description,
          'price': price,
          'harga': hargaNum,
          'stock': quantity,
          'stok': stokNum,
          'imageUrl': imageUrl,
        };

        return _buildProductCard(
          id: id,
          name: name,
          price: price,
          quantity: quantity,
          imageUrl: imageUrl,
          productDataMap: productDataMap,
        );
      }).toList(),
    );
  }

  Widget _buildProductCard({
    required int id,
    required String name,
    required String price,
    required String quantity,
    required Map<String, dynamic> productDataMap,
    String? imageUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto Produk
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.image_outlined,
                            color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child:
                          const Icon(Icons.image_outlined, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Detail Produk
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3259),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Stok: $quantity',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Pop-up Menu Titik Tiga Modern
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: Colors.white,
            ),
            child: PopupMenuButton<String>(
              color: AppTheme.backgroundColor,
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditProduct(productDataMap);
                } else if (value == 'delete') {
                  _deleteProduct(id);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  height: 40,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Color(0xFF2C3259),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem<String>(
                  value: 'delete',
                  height: 40,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Hapus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
