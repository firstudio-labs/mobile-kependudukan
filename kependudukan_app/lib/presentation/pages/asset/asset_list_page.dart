import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/cubits/asset/asset_cubit.dart';
import 'package:ladimas/presentation/cubits/asset/asset_state.dart';
import 'package:ladimas/data/models/asset_model.dart';
import 'package:ladimas/presentation/pages/asset/asset_detail_page.dart';
import 'package:ladimas/presentation/pages/asset/asset_form_page.dart';

class AssetListPage extends StatefulWidget {
  const AssetListPage({Key? key}) : super(key: key);

  @override
  State<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends State<AssetListPage> {
  late AssetCubit _assetCubit;

  @override
  void initState() {
    super.initState();
    _assetCubit = context.read<AssetCubit>();
    _loadAssets();
  }



  Future<void> _loadAssets() async {
    await _assetCubit.loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Daftar Aset',
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
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: _loadAssets,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocBuilder<AssetCubit, AssetState>(
        builder: (context, state) {
          if (state is AssetLoading && state.assets.isEmpty) {
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
                    'Memuat data aset...',
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
              child: SingleChildScrollView(
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
                        'Gagal Memuat Data',
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
                          onPressed: _loadAssets,
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

          final assets = state is AssetLoaded ? state.assets : [];

          if (assets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 50,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Belum Ada Data Aset',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tekan tombol tambah (+) di bawah untuk mendaftarkan aset baru.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAssets,
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
              itemCount: assets.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummaryCard(assets.length);
                }
                final asset = assets[index - 1];
                return _buildAssetCard(asset);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AssetFormPage()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah Aset',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  /// Summary header banner
  Widget _buildSummaryCard(int totalAssets) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aset Warga Terdaftar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kelola dan pantau pendataan aset fisik',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalAssets Aset',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(AssetModel asset) {
    final hasFront = asset.fotoDepan != null && asset.fotoDepan!.isNotEmpty;
    final hasSide = asset.fotoSamping != null && asset.fotoSamping!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssetDetailPage(assetId: asset.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Title, actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.namaAset,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  asset.namaPemilik,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AssetFormPage(assetId: asset.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _confirmDelete(asset),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tags for classification & type
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPillTag(
                      asset.klasifikasi,
                      bgColor: const Color(0xFFEDE9FE),
                      textColor: const Color(0xFF6D28D9),
                    ),
                    _buildPillTag(
                      asset.jenisAset,
                      bgColor: const Color(0xFFE0E7FF),
                      textColor: const Color(0xFF4338CA),
                    ),
                  ],
                ),

                // Location info if exists
                if (asset.tagLokasi != null && asset.tagLokasi!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          asset.tagLokasi!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Photos thumbnails row if available
                if (hasFront || hasSide) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (hasFront)
                        _buildThumbnail(
                          imageUrl: asset.fotoDepan!,
                          label: 'Depan',
                          onTap: () => _showImageDialog(
                            context,
                            asset.fotoDepan!,
                            'Foto Depan Aset',
                          ),
                        ),
                      if (hasFront && hasSide) const SizedBox(width: 10),
                      if (hasSide)
                        _buildThumbnail(
                          imageUrl: asset.fotoSamping!,
                          label: 'Samping',
                          onTap: () => _showImageDialog(
                            context,
                            asset.fotoSamping!,
                            'Foto Samping Aset',
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Card Footer
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ketuk untuk melihat detail lengkap',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail({
    required String imageUrl,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                _buildImageUrl(imageUrl),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(
                      Icons.broken_image_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillTag(
    String text, {
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _confirmDelete(AssetModel asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Aset?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data aset "${asset.namaAset}" milik ${asset.namaPemilik}?',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _assetCubit.deleteAsset(asset.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Hapus Aset'),
          ),
        ],
      ),
    );
  }

  String _buildImageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    String path = imagePath;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    return AppConstants.storageFileUrl(path);
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 420,
              maxHeight: 520,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                // Image
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _buildImageUrl(imageUrl),
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 280,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 280,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 44,
                                    color: Color(0xFFDC2626),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Gagal memuat gambar',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
