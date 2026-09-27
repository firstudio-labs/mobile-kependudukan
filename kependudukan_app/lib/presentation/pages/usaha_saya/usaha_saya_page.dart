import 'package:flutter/material.dart';
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
  final Map<String, bool> _miniPressed = {'Tambah': false};

  // Check if user has business information
  Future<bool> _hasBusinessInformation() async {
    try {
      final token = await AuthLocalStorage().getStoredToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      // Some tokens have format "id|token"
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
            // Check if any business information fields are filled
            final namaUsaha = informasiUsaha['nama_usaha']?.toString() ?? '';
            final alamatUsaha = informasiUsaha['alamat']?.toString() ?? '';
            final kelompokUsaha =
                informasiUsaha['kelompok_usaha']?.toString() ?? '';

            // Return true if any of the business fields are filled
            return namaUsaha.isNotEmpty ||
                alamatUsaha.isNotEmpty ||
                kelompokUsaha.isNotEmpty;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking business information: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Check business information before loading items
    _checkBusinessInformationAndLoadItems();
  }

  Future<void> _checkBusinessInformationAndLoadItems() async {
    final hasBusinessInfo = await _hasBusinessInformation();
    if (!hasBusinessInfo) {
      // Show dialog to inform user about missing business information
      _showBusinessInfoMissingDialog();
    } else {
      // Business info exists, load items normally
      _loadItems();
    }
  }

  void _showBusinessInfoMissingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Informasi Usaha Belum Lengkap',
            style: TextStyle(
              color: Color(0xFF4A47DC),
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
                Navigator.of(context).pop(); // Close dialog
                // Navigate to profile edit page to add business information
                _navigateToProfileEditPage();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A47DC),
              ),
              child: const Text(
                'LENGKAPI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Simply return to previous page
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
      // After returning from profile edit, check again if business info exists
      if (result == true && mounted) {
        // Refresh the business information check
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F6FA),
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4A47DC)),
            onPressed: () {
              Navigator.pop(context, _changed);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title like Warungku
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 10, 0, 20),
                child: Center(
                  child: Text(
                    'Usaha Saya',
                    style: TextStyle(
                      color: Color(0xFF4A47DC),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              // Search Section
              _buildSearchSection(),

              // Product List
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildProductList(),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: const Color(0xFF4A47DC),
          unselectedItemColor: Colors.grey,
          currentIndex: 1, // Usaha Saya
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 28), label: 'Beranda'),
            BottomNavigationBarItem(
                icon: Icon(Icons.storefront_sharp, size: 28),
                label: 'Usaha Saya'),
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
                // Current page - Usaha Saya
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
          ),
          const SizedBox(width: 12),
          _buildMiniMenu(
            icon: Icons.add_shopping_cart,
            label: 'Tambah',
            onTap: () async {
              // Check if user has business information before allowing to add product
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
          ),
        ],
      ),
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
                locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 0)
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
        return _buildProductCard(
          id: id,
          name: name,
          description: description,
          price: price,
          quantity: quantity,
          imageUrl: imageUrl,
          hargaRaw: hargaNum,
          stokRaw: stokNum,
        );
      }).toList(),
    );
  }

  Widget _buildProductCard({
    required int id,
    required String name,
    required String description,
    required String price,
    required String quantity,
    String? imageUrl,
    int? hargaRaw,
    int? stokRaw,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to Ubah Produk page with product data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UbahProdukPage(
              penduduk: widget.penduduk,
              productId: id,
              productData: {
                'id': id,
                'name': name,
                'description': description,
                'price': price,
                'harga': hargaRaw,
                'stock': quantity,
                'stok': stokRaw,
                'imageUrl': imageUrl,
              },
            ),
          ),
        ).then((result) {
          if (result == true) {
            _changed = true;
            _loadItems();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 32, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A47DC),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$quantity pcs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow Icon
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
