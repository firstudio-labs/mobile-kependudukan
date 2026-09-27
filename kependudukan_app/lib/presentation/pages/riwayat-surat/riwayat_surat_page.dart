import 'package:flutter/material.dart';
import '../../../data/datasources/riwayat_surat_api_service.dart';
import '../../../data/models/riwayat_surat_model.dart';
import '../../../core/error/exceptions.dart';
import 'package:intl/intl.dart';
import '../../../data/datasources/auth_local_storage.dart';
import 'package:http/http.dart' as http;

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
      setState(() {
        _riwayatSurat = riwayat;
        _riwayatSurat.sort((a, b) => DateTime.parse(b.created_at)
            .compareTo(DateTime.parse(a.created_at)));
        _isLoading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on ServerException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getStatusText(int isAccepted) {
    switch (isAccepted) {
      case 0:
        return 'Menunggu Persetujuan';
      case 1:
        return 'Diterima';
      case 2:
        return 'Ditolak';
      default:
        return 'Status Tidak Diketahui';
    }
  }

  Color _getStatusColor(int isAccepted) {
    switch (isAccepted) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Surat'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRiwayatSurat,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _riwayatSurat.isEmpty
                  ? const Center(
                      child: Text('Belum ada riwayat surat'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRiwayatSurat,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _riwayatSurat.length,
                        itemBuilder: (context, index) {
                          final surat = _riwayatSurat[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        surat.letter_type.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _getStatusColor(surat.is_accepted)
                                                  .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(surat.is_accepted),
                                          style: TextStyle(
                                            color: _getStatusColor(
                                                surat.is_accepted),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (surat.purpose != null) ...[
                                    Text(
                                      'Tujuan: ${surat.purpose}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    'Tanggal: ${_formatDate(surat.created_at)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
