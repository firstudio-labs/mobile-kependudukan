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
      appBar: AppBar(
        title: const Text(
          'Detail Aset',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocBuilder<AssetCubit, AssetState>(
        bloc: _assetCubit,
        builder: (context, state) {
          if (state is AssetLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (state is AssetError) {
            return Center(
              child: Text(
                'Error: ${state.message}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (state is AssetDetailLoaded) {
            return _buildAssetDetail(state.asset);
          }

          return const Center(
            child: Text('Tidak ada data yang tersedia'),
          );
        },
      ),
    );
  }

  Widget _buildAssetDetail(AssetModel asset) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Asset images
          _buildImageSection(asset),

          const SizedBox(height: 24),

          // Owner Information
          _buildSectionTitle('Informasi Pemilik'),
          _buildCard([
            _buildInfoRow('NIK Pemilik', asset.nikPemilik),
            _buildInfoRow('Nama Pemilik', asset.namaPemilik),
          ]),

          const SizedBox(height: 24),

          // Asset Information
          _buildSectionTitle('Informasi Aset'),
          _buildCard([
            _buildInfoRow('Nama Aset', asset.namaAset),
            _buildInfoRow('Klasifikasi',
                '${asset.klasifikasiDetail.kode} - ${asset.klasifikasiDetail.jenisKlasifikasi}'),
            _buildInfoRow('Jenis Aset',
                '${asset.jenisAsetDetail.kode} - ${asset.jenisAsetDetail.jenisAset}'),
            if (asset.createdAt != null)
              _buildInfoRow('Tanggal Registrasi',
                  DateFormat('dd MMMM yyyy').format(asset.createdAt!)),
          ]),

          const SizedBox(height: 24),

          _buildSectionTitle('Informasi Alamat'),
          _buildCard([
            _buildInfoRow('Alamat', asset.alamat),
            if (asset.rt != null && asset.rt!.isNotEmpty)
              _buildInfoRow('RT', asset.rt!),
            if (asset.rw != null && asset.rw!.isNotEmpty)
              _buildInfoRow('RW', asset.rw!),
            if (asset.villageName != null && asset.villageName!.isNotEmpty)
              _buildInfoRow('Desa/Kelurahan', asset.villageName!),
            if (asset.subdistrictName != null &&
                asset.subdistrictName!.isNotEmpty)
              _buildInfoRow('Kecamatan', asset.subdistrictName!),
            if (asset.districtName != null && asset.districtName!.isNotEmpty)
              _buildInfoRow('Kabupaten/Kota', asset.districtName!),
            if (asset.provinceName != null && asset.provinceName!.isNotEmpty)
              _buildInfoRow('Provinsi', asset.provinceName!),
          ]),

          const SizedBox(height: 24),

          // Location Information
          if (asset.tagLokasi != null && asset.tagLokasi!.isNotEmpty) ...[
            _buildSectionTitle('Lokasi'),
            _buildLocationSection(asset.tagLokasi!),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildImageSection(AssetModel asset) {
    if (asset.fotoDepan == null && asset.fotoSamping == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Foto Aset'),
            const SizedBox(height: 12),
            Row(
              children: [
                if (asset.fotoDepan != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto Depan',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            AppConstants.storageFileUrl(asset.fotoDepan),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.red),
                                    SizedBox(height: 4),
                                    Text('Gambar tidak dapat dimuat',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (asset.fotoDepan != null && asset.fotoSamping != null)
                  const SizedBox(width: 12),
                if (asset.fotoSamping != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto Samping',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            AppConstants.storageFileUrl(asset.fotoSamping),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.red),
                                    SizedBox(height: 4),
                                    Text('Gambar tidak dapat dimuat',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(String coordinates) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Koordinat', coordinates),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openCoordinatesInMap(coordinates),
                icon: const Icon(Icons.map),
                label: const Text('Lihat di Peta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
