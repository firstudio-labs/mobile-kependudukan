import 'package:flutter/material.dart';
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

      setState(() {
        _tagihanDetail = response.data;
        _isLoading = false;
      });
    } catch (e) {
      final message = e.toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF4A47DC)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A47DC)),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat detail tagihan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTagihanDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A47DC),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
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

    if (tagihan.status.toLowerCase() == 'lunas' ||
        tagihan.status.toLowerCase() == 'sudah_bayar') {
      displayStatus = 'Lunas';
      statusColor = Colors.green;
    } else {
      // Check if tagihan is overdue
      final DateTime today = DateTime.now();
      final DateTime tagihanDate = DateTime.parse(tagihan.tanggal);
      final bool isOverdue = tagihanDate.isBefore(today);

      if (isOverdue) {
        displayStatus = 'Jatuh Tempo';
        statusColor = Colors.orange;
      } else {
        displayStatus = 'Belum Lunas';
        statusColor = Colors.red;
      }
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header title seperti di halaman Tagihan, dengan jarak lebih ringkas
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 20),
              child: Center(
                child: Text(
                  'Detail Tagihan',
                  style: TextStyle(
                    color: Color(0xFF4A47DC),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Status Card
            _buildStatusCard(tagihan, statusColor, displayStatus),
            const SizedBox(height: 20),

            // Detail Information
            _buildDetailCard(tagihan, displayStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      TagihanModel tagihan, Color statusColor, String displayStatus) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayStatus,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tagihan.nominalFormatted ??
                'Rp ${tagihan.nominal.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A47DC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagihan.kategori?.nama ?? 'Tagihan',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(TagihanModel tagihan, String displayStatus) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Tagihan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          // Nama & NIK pemilik tagihan
          if ((tagihan.fullName ?? '').isNotEmpty)
            _buildDetailRow('Nama', tagihan.fullName!),
          if ((tagihan.nik ?? '').isNotEmpty)
            _buildDetailRow('NIK', tagihan.nik!),

          _buildDetailRow(
              'Tanggal',
              _tagihanService?.formatTanggal(tagihan.tanggal) ??
                  tagihan.tanggal),
          _buildDetailRow('Kategori', tagihan.kategori?.nama ?? '-'),
          _buildDetailRow('Sub Kategori', tagihan.subKategori?.nama ?? '-'),
          _buildDetailRow('Status', displayStatus),
          if (tagihan.keterangan != null && tagihan.keterangan!.isNotEmpty)
            _buildDetailRow('Keterangan', tagihan.keterangan!),
          _buildDetailRow(
              'Dibuat',
              tagihan.createdAt != null
                  ? _formatDateTime(tagihan.createdAt!)
                  : '-'),
          if (tagihan.updatedAt != null)
            _buildDetailRow('Diperbarui', _formatDateTime(tagihan.updatedAt!)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'belum_bayar':
      case 'belum_lunas':
        return Colors.red;
      case 'sudah_bayar':
      case 'lunas':
        return Colors.green;
      case 'terlambat':
        return Colors.orange;
      case 'dibatalkan':
        return Colors.grey;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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

      return '${date.day} ${bulan[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }
}
