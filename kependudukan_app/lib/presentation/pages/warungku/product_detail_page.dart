import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/theme/app_theme.dart';
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

  Future<void> _openWhatsApp() async {
    final phone =
        (_detail?['informasi_usaha']?['pemilik']?['no_hp']?.toString() ??
            widget.phoneNumber);

    String formattedNumber = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (!formattedNumber.startsWith('62')) {
      if (formattedNumber.startsWith('0')) {
        formattedNumber = '62${formattedNumber.substring(1)}';
      } else {
        formattedNumber = '62$formattedNumber';
      }
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$formattedNumber');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
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
        if (mounted) {
          setState(() {
            _detail = data;
            _statistikToko = data?['statistik_toko'] as Map<String, dynamic>?;
          });
        }
      }
    } catch (_) {}
  }

  int _parseHargaRobust(dynamic h) {
    if (h is num) return h.toInt();
    final String s = '${h ?? ''}'.trim();
    final num? tryNum = num.tryParse(s.replaceAll(',', '.'));
    if (tryNum != null) return tryNum.toDouble().round();
    return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = _detail?['nama_produk']?.toString() ?? widget.name;
    final harga = _detail?['harga'];

    final int hargaNum = (harga != null)
        ? _parseHargaRobust(harga)
        : _parseHargaRobust(widget.price);
    final String displayPrice =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
            .format(hargaNum);
    final description = _detail?['deskripsi']?.toString() ?? widget.description;
    final imgUrl = _detail?['foto_url']?.toString() ?? widget.imageUrl;
    final jenis = _detail?['jenis']?.toString();
    final klasifikasi = _detail?['klasifikasi']?.toString();
    final infoUsaha = _detail?['informasi_usaha'] as Map<String, dynamic>?;
    final namaUsaha = infoUsaha?['nama_usaha']?.toString();
    final sellerPhone =
        _detail?['informasi_usaha']?['pemilik']?['no_hp']?.toString() ??
            widget.phoneNumber;
    final alamatStr = infoUsaha != null &&
            (infoUsaha['alamat']?.toString().isNotEmpty ?? false)
        ? infoUsaha['alamat']?.toString()
        : infoUsaha?['tag_lokasi']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Produk',
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: imgUrl != null && imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
            ),
            const SizedBox(height: 14),

            // Price & Name Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayPrice,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if ((klasifikasi != null && klasifikasi.isNotEmpty) ||
                      (jenis != null && jenis.isNotEmpty)) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (klasifikasi != null && klasifikasi.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              klasifikasi,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        if (jenis != null && jenis.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              jenis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Shop / Seller Card
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openWhatsApp,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Penjual',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: (() {
                            final rawFotoUsaha = (infoUsaha?['foto_url'] ??
                                    infoUsaha?['foto'] ??
                                    infoUsaha?['logo'] ??
                                    infoUsaha?['gambar'])
                                ?.toString();
                            final usahaFoto = _resolveUrl(rawFotoUsaha);
                            if (usahaFoto != null && usahaFoto.isNotEmpty) {
                              return Image.network(
                                usahaFoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.storefront_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 24,
                                ),
                              );
                            }
                            return const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFF94A3B8),
                              size: 24,
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (sellerPhone.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  sellerPhone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                              if (alamatStr != null && alamatStr.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        size: 13,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        alamatStr,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0x1A25D366),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF25D366),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    if (_statistikToko != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_statistikToko!['total_produk'] ?? 0} total produk terdaftar',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Spesifikasi & Deskripsi Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spesifikasi Produk',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSpecRow('Klasifikasi', klasifikasi ?? '-'),
                  const SizedBox(height: 8),
                  _buildSpecRow('Jenis', jenis ?? '-'),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),
                  const Text(
                    'Deskripsi Produk',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isNotEmpty
                        ? description
                        : 'Tidak ada deskripsi tambahan.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat_outlined, size: 20),
            label: const Text(
              'Hubungi Penjual via WhatsApp',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
