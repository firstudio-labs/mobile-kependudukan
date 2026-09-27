import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';

class ProductDetailPage extends StatefulWidget {
  final int? productId;
  final String name;
  final String price;
  final String description;
  final String phoneNumber;
  final String? imageUrl;

  const ProductDetailPage({
    Key? key,
    this.productId,
    required this.name,
    required this.price,
    required this.description,
    required this.phoneNumber,
    this.imageUrl,
  }) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _statistikToko;
  String? _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    String base = AppConstants.storageUrl;
    if (base.isEmpty) return trimmed;
    if (!base.endsWith('/')) base = '$base/';
    final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$base$path';
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    // Format nomor telepon untuk WhatsApp
    final phone =
        (_detail?['informasi_usaha']?['pemilik']?['no_hp']?.toString() ??
            widget.phoneNumber);
    String originalNumber = phone;
    print('Original phone number: $originalNumber');

    // Menghilangkan karakter non-digit (spasi, dash, dll)
    String formattedNumber = phone.replaceAll(RegExp(r'[^\d]'), '');
    print('After removing non-digits: $formattedNumber');

    // Pastikan nomor dimulai dengan kode negara Indonesia (62)
    if (!formattedNumber.startsWith('62')) {
      if (formattedNumber.startsWith('0')) {
        // Jika dimulai dengan 0, ganti dengan 62 (contoh: 081239281 -> 6281239281)
        formattedNumber = '62${formattedNumber.substring(1)}';
        print('Converted from 0 to 62: $formattedNumber');
      } else {
        // Jika tidak dimulai dengan 0 atau 62, tambahkan 62 di depan
        formattedNumber = '62$formattedNumber';
        print('Added 62 prefix: $formattedNumber');
      }
    } else {
      print('Already has 62 prefix: $formattedNumber');
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedNumber');
    print('Final WhatsApp URL: $whatsappUri');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback ke browser jika WhatsApp tidak tersedia
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching WhatsApp: $e');
      // Tampilkan snackbar error ke user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka WhatsApp: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final token = await AuthLocalStorage().getStoredToken();
      final uri = Uri.parse(
          '${AppConstants.authApiUrl}/user/warungku/${widget.productId}?format=json');
      final headers = {
        'Accept': 'application/json',
        'X-API-Key': AppConstants.apiKey,
        if (token != null && token.isNotEmpty)
          'Authorization':
              'Bearer ${token.contains('|') ? token.split('|').last : token}',
      };
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        setState(() {
          _detail = data;
          _statistikToko = data?['statistik_toko'] as Map<String, dynamic>?;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name = _detail?['nama_produk']?.toString() ?? widget.name;
    final harga = _detail?['harga'];
    int _parseHargaRobust(dynamic h) {
      if (h is num) return h.toInt();
      final String s = '${h ?? ''}'.trim();
      final num? tryNum = num.tryParse(s.replaceAll(',', '.'));
      if (tryNum != null) return tryNum.toDouble().round();
      return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    final int hargaNum = (harga != null)
        ? _parseHargaRobust(harga)
        : _parseHargaRobust(widget.price);
    final String displayPrice =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 0)
            .format(hargaNum);
    final description = _detail?['deskripsi']?.toString() ?? widget.description;
    final imgUrl = _detail?['foto_url']?.toString() ?? widget.imageUrl;
    final jenis = _detail?['jenis']?.toString();
    final klasifikasi = _detail?['klasifikasi']?.toString();
    final infoUsaha = _detail?['informasi_usaha'] as Map<String, dynamic>?;
    final namaUsaha = infoUsaha?['nama_usaha']?.toString();
    final alamatStr = infoUsaha != null &&
            (infoUsaha['alamat']?.toString().isNotEmpty ?? false)
        ? infoUsaha['alamat']?.toString()
        : infoUsaha?['tag_lokasi']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4A47DC)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: imgUrl != null && imgUrl.isNotEmpty
                    ? Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 56, color: Colors.white70),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_outlined,
                              size: 56, color: Colors.white70),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Price and name
            Text(
              displayPrice,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),

            // Shop card
            GestureDetector(
              onTap: () => _openWhatsApp(context),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: (() {
                              final rawFotoUsaha = (infoUsaha?['foto_url'] ??
                                      infoUsaha?['foto'] ??
                                      infoUsaha?['logo'] ??
                                      infoUsaha?['gambar'])
                                  ?.toString();
                              final usahaFoto = _resolveUrl(rawFotoUsaha);
                              if (usahaFoto != null && usahaFoto.isNotEmpty) {
                                return ClipOval(
                                  child: Image.network(
                                    usahaFoto,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.store_mall_directory,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }
                              return const Icon(
                                Icons.store_mall_directory,
                                color: Colors.grey,
                              );
                            })(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  namaUsaha ?? 'Nama Toko',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(_detail?['informasi_usaha']?['pemilik']?['no_hp']?.toString() ?? widget.phoneNumber)}\n${alamatStr ?? 'Alamat'}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF666666)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chat,
                              color: Color(0xFF4A47DC), size: 32),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          if (_statistikToko != null)
                            Text(
                                '${_statistikToko!['total_produk'] ?? 0} total produk',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Detail & Deskripsi Produk dalam satu kotak
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Detail Produk
                    const Text(
                      'Detail Produk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Klasifikasi',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF666666))),
                              SizedBox(height: 4),
                              const Text('Jenis',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF666666))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(klasifikasi ?? '-',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF333333))),
                              SizedBox(height: 4),
                              Text(jenis ?? '-',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF333333))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi Produk
                    const Text(
                      'Deskripsi Produk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF555555)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
