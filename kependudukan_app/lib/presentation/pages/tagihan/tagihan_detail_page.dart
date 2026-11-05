import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/data/models/tagihan_model.dart';
import 'package:ladimas/data/services/tagihan_service.dart';

class TagihanDetailPage extends StatefulWidget {
  final TagihanModel tagihan;
  final Penduduk penduduk;

  const TagihanDetailPage({
    Key? key,
    required this.tagihan,
    required this.penduduk,
  }) : super(key: key);

  @override
  State<TagihanDetailPage> createState() => _TagihanDetailPageState();
}

class _TagihanDetailPageState extends State<TagihanDetailPage> {
  TagihanService? _tagihanService;
  TagihanModel? _tagihanDetail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tagihanService = TagihanService(token: widget.penduduk.token);
    _loadTagihanDetail();
  }

  Future<void> _loadTagihanDetail() async {
    if (_tagihanService == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response =
          await _tagihanService!.getTagihanDetail(widget.tagihan.id);

      if (mounted) {
        setState(() {
          _tagihanDetail = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      final message = e.toString();
      if (mounted) {
        // Jika forbidden (tagihan milik anggota keluarga), fallback gunakan data list
        if (message.contains('Forbidden')) {
          setState(() {
            _tagihanDetail = widget.tagihan;
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = message;
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Detail Tagihan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadTagihanDetail,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final tagihan = _tagihanDetail ?? widget.tagihan;

    // Determine status and color based on date and API status
    String displayStatus;
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    if (tagihan.status.toLowerCase() == 'lunas' ||
        tagihan.status.toLowerCase() == 'sudah_bayar') {
      displayStatus = 'Lunas';
      statusColor = const Color(0xFF059669);
      statusBgColor = const Color(0xFFD1FAE5);
      statusIcon = Icons.check_circle_rounded;
    } else {
      final DateTime today = DateTime.now();
      final DateTime tagihanDate = DateTime.parse(tagihan.tanggal);
      final bool isOverdue = tagihanDate.isBefore(today);

      if (isOverdue) {
        displayStatus = 'Jatuh Tempo';
        statusColor = const Color(0xFFD97706);
        statusBgColor = const Color(0xFFFEF3C7);
        statusIcon = Icons.warning_amber_rounded;
      } else {
        displayStatus = 'Belum Lunas';
        statusColor = const Color(0xFFDC2626);
        statusBgColor = const Color(0xFFFEE2E2);
        statusIcon = Icons.error_outline_rounded;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Nominal Card
          _buildStatusCard(
            tagihan: tagihan,
            statusColor: statusColor,
            statusBgColor: statusBgColor,
            statusIcon: statusIcon,
            displayStatus: displayStatus,
          ),
          const SizedBox(height: 14),

          // Detail Information
          _buildDetailCard(tagihan, displayStatus, statusColor),
          const SizedBox(height: 14),

          // Information Notice Box
          _buildNoticeCard(displayStatus),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required TagihanModel tagihan,
    required Color statusColor,
    required Color statusBgColor,
    required IconData statusIcon,
    required String displayStatus,
  }) {
    final kategoriNama = tagihan.kategori?.nama ?? 'Tagihan';
    final subKategoriNama = tagihan.subKategori?.nama;
    final subtitle = (subKategoriNama != null && subKategoriNama.isNotEmpty)
        ? '$kategoriNama • $subKategoriNama'
        : kategoriNama;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 5),
                Text(
                  displayStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tagihan.nominalFormatted ??
                'Rp ${tagihan.nominal.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
      TagihanModel tagihan, String displayStatus, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Tagihan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          // Nama & NIK pemilik tagihan
          if ((tagihan.fullName ?? '').isNotEmpty)
            _buildDetailRow('Nama Lengkap', tagihan.fullName!),
          if ((tagihan.nik ?? '').isNotEmpty)
            _buildDetailRow('NIK', tagihan.nik!),

          _buildDetailRow(
              'Tanggal Tagihan',
              _tagihanService?.formatTanggal(tagihan.tanggal) ??
                  tagihan.tanggal),
          _buildDetailRow('Kategori', tagihan.kategori?.nama ?? '-'),
          _buildDetailRow('Sub Kategori', tagihan.subKategori?.nama ?? '-'),
          _buildDetailRow('Status', displayStatus, valueColor: statusColor),
          if (tagihan.keterangan != null && tagihan.keterangan!.isNotEmpty)
            _buildDetailRow('Keterangan', tagihan.keterangan!),
          _buildDetailRow(
              'Waktu Dibuat',
              tagihan.createdAt != null
                  ? _formatDateTime(tagihan.createdAt!)
                  : '-'),
          if (tagihan.updatedAt != null)
            _buildDetailRow(
                'Terakhir Diperbarui', _formatDateTime(tagihan.updatedAt!)),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(String displayStatus) {
    final isLunas = displayStatus == 'Lunas';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLunas ? const Color(0xFFF0FDF4) : const Color(0xFFFEFCE8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLunas ? const Color(0xFFBBF7D0) : const Color(0xFFFEF08A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLunas
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: isLunas ? const Color(0xFF16A34A) : const Color(0xFFCA8A04),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLunas
                  ? 'Tagihan ini telah dinyatakan lunas dan tercatat secara resmi di sistem kas desa.'
                  : 'Untuk melakukan pembayaran atau konfirmasi, silakan hubungi bendahara desa atau kunjungi kantor pelayanan desa.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color:
                    isLunas ? const Color(0xFF166534) : const Color(0xFF854D0E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      final DateTime date = DateTime.parse(dateTime);
      final List<String> bulan = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];

      return '${date.day} ${bulan[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB';
    } catch (e) {
      return dateTime;
    }
  }
}
