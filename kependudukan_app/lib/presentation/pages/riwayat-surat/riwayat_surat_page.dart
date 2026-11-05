import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/riwayat_surat_api_service.dart';
import '../../../data/models/riwayat_surat_model.dart';

class RiwayatSuratPage extends StatefulWidget {
  const RiwayatSuratPage({Key? key}) : super(key: key);

  @override
  State<RiwayatSuratPage> createState() => _RiwayatSuratPageState();
}

class _RiwayatSuratPageState extends State<RiwayatSuratPage> {
  late final RiwayatSuratApiService _riwayatSuratApiService;
  List<RiwayatSuratModel> _riwayatSurat = [];
  bool _isLoading = true;
  String? _error;
  int?
      _selectedStatusFilter; // null = Semua, 0 = Menunggu, 1 = Diterima, 2 = Ditolak

  @override
  void initState() {
    super.initState();
    _riwayatSuratApiService = RiwayatSuratApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _loadRiwayatSurat();
  }

  Future<void> _loadRiwayatSurat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final riwayat = await _riwayatSuratApiService.getRiwayatSurat();
      if (mounted) {
        setState(() {
          _riwayatSurat = riwayat;
          _riwayatSurat.sort((a, b) => DateTime.parse(b.created_at)
              .compareTo(DateTime.parse(a.created_at)));
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } on ServerException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Terjadi kesalahan: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getStatusText(int isAccepted) {
    switch (isAccepted) {
      case 0:
        return 'Menunggu';
      case 1:
        return 'Diterima';
      case 2:
        return 'Ditolak';
      default:
        return 'Tidak Diketahui';
    }
  }

  Color _getStatusTextColor(int isAccepted) {
    switch (isAccepted) {
      case 0:
        return const Color(0xFFD97706); // Amber 600
      case 1:
        return const Color(0xFF059669); // Emerald 600
      case 2:
        return const Color(0xFFDC2626); // Red 600
      default:
        return const Color(0xFF64748B); // Slate 500
    }
  }

  Color _getStatusBgColor(int isAccepted) {
    switch (isAccepted) {
      case 0:
        return const Color(0xFFFEF3C7); // Amber 100
      case 1:
        return const Color(0xFFD1FAE5); // Emerald 100
      case 2:
        return const Color(0xFFFEE2E2); // Red 100
      default:
        return const Color(0xFFF1F5F9); // Slate 100
    }
  }

  IconData _getStatusIcon(int isAccepted) {
    switch (isAccepted) {
      case 0:
        return Icons.schedule_rounded;
      case 1:
        return Icons.check_circle_rounded;
      case 2:
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  List<RiwayatSuratModel> get _filteredRiwayat {
    if (_selectedStatusFilter == null) return _riwayatSurat;
    return _riwayatSurat
        .where((surat) => surat.is_accepted == _selectedStatusFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredRiwayat;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Riwayat Surat',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
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
                          'Gagal Memuat Riwayat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadRiwayatSurat,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRiwayatSurat,
                  color: AppTheme.primaryColor,
                  child: Column(
                    children: [
                      // Filter Status Tabs
                      _buildFilterChips(),

                      // List Riwayat Surat
                      Expanded(
                        child: filteredList.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 4,
                                  bottom: 24,
                                ),
                                itemCount: filteredList.length,
                                itemBuilder: (context, index) {
                                  final surat = filteredList[index];
                                  return _buildSuratCard(surat);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterChips() {
    final counts = {
      null: _riwayatSurat.length,
      0: _riwayatSurat.where((s) => s.is_accepted == 0).length,
      1: _riwayatSurat.where((s) => s.is_accepted == 1).length,
      2: _riwayatSurat.where((s) => s.is_accepted == 2).length,
    };

    final filters = [
      {'label': 'Semua', 'value': null},
      {'label': 'Menunggu', 'value': 0},
      {'label': 'Diterima', 'value': 1},
      {'label': 'Ditolak', 'value': 2},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final value = f['value'] as int?;
            final label = f['label'] as String;
            final isSelected = _selectedStatusFilter == value;
            final count = counts[value] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Material(
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = value;
                    });
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 36,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Riwayat Surat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedStatusFilter != null
                      ? 'Tidak ada pengajuan surat dengan status "${_getStatusText(_selectedStatusFilter!)}".'
                      : 'Pengajuan surat yang Anda buat akan tercatat di sini.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuratCard(RiwayatSuratModel surat) {
    final formattedType = surat.letter_type.replaceAll('_', ' ').toUpperCase();
    final statusColor = _getStatusTextColor(surat.is_accepted);
    final statusBg = _getStatusBgColor(surat.is_accepted);
    final statusIcon = _getStatusIcon(surat.is_accepted);
    final statusText = _getStatusText(surat.is_accepted);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Type & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (surat.letter_number != null &&
                          surat.letter_number!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'No: ${surat.letter_number}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Purpose Section
            if (surat.purpose != null && surat.purpose!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keperluan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      surat.purpose!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Footer: Date
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 5),
                Text(
                  _formatDate(surat.created_at),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
