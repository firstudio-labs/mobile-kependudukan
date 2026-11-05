import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/data/models/asset_model.dart';
import 'package:ladimas/presentation/cubits/asset/asset_cubit.dart';
import 'package:ladimas/presentation/cubits/asset/asset_state.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AssetDetailPage extends StatefulWidget {
  final int assetId;

  const AssetDetailPage({Key? key, required this.assetId}) : super(key: key);

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  late AssetCubit _assetCubit;

  @override
  void initState() {
    super.initState();
    _assetCubit = GetIt.instance<AssetCubit>();
    _loadAssetDetail();
  }

  Future<void> _loadAssetDetail() async {
    await _assetCubit.loadAssetDetail(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Detail Aset',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: _loadAssetDetail,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocBuilder<AssetCubit, AssetState>(
        bloc: _assetCubit,
        builder: (context, state) {
          if (state is AssetLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Memuat detail aset...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is AssetError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memuat Detail',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loadAssetDetail,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state is AssetDetailLoaded) {
            return _buildAssetDetail(state.asset);
          }

          return const Center(
            child: Text(
              'Tidak ada data yang tersedia',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetDetail(AssetModel asset) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Asset Banner
          _buildHeroHeader(asset),

          const SizedBox(height: 16),

          // Asset images if available
          if (asset.fotoDepan != null || asset.fotoSamping != null) ...[
            _buildImageSection(asset),
            const SizedBox(height: 16),
          ],

          // Owner Information Card
          _buildSectionCard(
            title: 'Informasi Pemilik',
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            rows: [
              _buildInfoRow(
                  'NIK Pemilik', asset.nikPemilik, Icons.badge_outlined),
              _buildInfoRow(
                  'Nama Pemilik', asset.namaPemilik, Icons.person_rounded),
            ],
          ),

          const SizedBox(height: 16),

          // Asset Information Card
          _buildSectionCard(
            title: 'Informasi Aset',
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFEDE9FE),
            rows: [
              _buildInfoRow('Nama Aset', asset.namaAset,
                  Icons.label_important_outline_rounded),
              _buildInfoRow(
                'Klasifikasi',
                '${asset.klasifikasiDetail.kode} - ${asset.klasifikasiDetail.jenisKlasifikasi}',
                Icons.category_outlined,
              ),
              _buildInfoRow(
                'Jenis Aset',
                '${asset.jenisAsetDetail.kode} - ${asset.jenisAsetDetail.jenisAset}',
                Icons.class_outlined,
              ),
              if (asset.createdAt != null)
                _buildInfoRow(
                  'Tanggal Registrasi',
                  DateFormat('dd MMMM yyyy').format(asset.createdAt!),
                  Icons.calendar_today_outlined,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Address Information Card
          _buildSectionCard(
            title: 'Informasi Alamat',
            icon: Icons.home_work_outlined,
            iconColor: const Color(0xFF0D9488),
            bgColor: const Color(0xFFCCFBF1),
            rows: [
              _buildInfoRow('Alamat', asset.alamat, Icons.place_outlined),
              if (asset.rt != null && asset.rt!.isNotEmpty)
                _buildInfoRow('RT', asset.rt!, Icons.signpost_outlined),
              if (asset.rw != null && asset.rw!.isNotEmpty)
                _buildInfoRow('RW', asset.rw!, Icons.signpost_outlined),
              if (asset.villageName != null && asset.villageName!.isNotEmpty)
                _buildInfoRow('Desa/Kelurahan', asset.villageName!,
                    Icons.location_city_rounded),
              if (asset.subdistrictName != null &&
                  asset.subdistrictName!.isNotEmpty)
                _buildInfoRow(
                    'Kecamatan', asset.subdistrictName!, Icons.map_outlined),
              if (asset.districtName != null && asset.districtName!.isNotEmpty)
                _buildInfoRow('Kabupaten/Kota', asset.districtName!,
                    Icons.apartment_rounded),
              if (asset.provinceName != null && asset.provinceName!.isNotEmpty)
                _buildInfoRow(
                    'Provinsi', asset.provinceName!, Icons.public_rounded),
            ],
          ),

          // Location Section Card
          if (asset.tagLokasi != null && asset.tagLokasi!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLocationSection(asset.tagLokasi!),
          ],
        ],
      ),
    );
  }

  /// Top hero card summarizing asset
  Widget _buildHeroHeader(AssetModel asset) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.namaAset,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Pemilik: ${asset.namaPemilik}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        asset.klasifikasi,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        asset.jenisAset,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Photo gallery card
  Widget _buildImageSection(AssetModel asset) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Foto Aset',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (asset.fotoDepan != null && asset.fotoDepan!.isNotEmpty)
                Expanded(
                  child: _buildPhotoCard(
                    title: 'Foto Depan',
                    imageUrl: AppConstants.storageFileUrl(asset.fotoDepan),
                  ),
                ),
              if (asset.fotoDepan != null &&
                  asset.fotoDepan!.isNotEmpty &&
                  asset.fotoSamping != null &&
                  asset.fotoSamping!.isNotEmpty)
                const SizedBox(width: 12),
              if (asset.fotoSamping != null && asset.fotoSamping!.isNotEmpty)
                Expanded(
                  child: _buildPhotoCard(
                    title: 'Foto Samping',
                    imageUrl: AppConstants.storageFileUrl(asset.fotoSamping),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard({required String title, required String imageUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            color: const Color(0xFFF8FAFC),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          size: 32,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gagal memuat',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Modern Section Card with Header Icon and Key-Value rows
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(String coordinates) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Titik Lokasi Peta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Koordinat',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coordinates,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openCoordinatesInMap(coordinates),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Buka di Google Maps'),
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
        ],
      ),
    );
  }

  Future<void> _openCoordinatesInMap(String coordinates) async {
    try {
      final parts = coordinates.split(',');
      if (parts.length != 2) return;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat == null || lng == null) return;

      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka peta')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
