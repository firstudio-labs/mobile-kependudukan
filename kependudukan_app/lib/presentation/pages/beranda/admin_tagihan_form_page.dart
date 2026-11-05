import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/data/datasources/admin_tagihan_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/penduduk_api_service.dart';

class AdminTagihanFormPage extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final Map<String, dynamic>? current;

  const AdminTagihanFormPage({Key? key, required this.adminData, this.current})
      : super(key: key);

  @override
  State<AdminTagihanFormPage> createState() => _AdminTagihanFormPageState();
}

class _AdminTagihanFormPageState extends State<AdminTagihanFormPage> {
  late final AdminTagihanApiService _api;
  late final PendudukApiService _pendudukApi;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _pendudukDropdown = [];
  List<dynamic> _kategoriDropdown = [];
  List<dynamic> _subKategoriDropdown = [];

  String? _selectedNik;
  String _nikSearch = '';
  final Set<String> _selectedNiks = <String>{};
  int? _selectedKategoriId;
  int? _selectedSubKategoriId;
  final TextEditingController _nominalCtrl = TextEditingController();
  final TextEditingController _ketCtrl = TextEditingController();
  final TextEditingController _tanggalCtrl = TextEditingController();
  String _statusVal = 'pending';
  String _pendudukFilter = 'all'; // all | kk

  @override
  void initState() {
    super.initState();
    _api = AdminTagihanApiService(
        client: http.Client(), authLocalStorage: AuthLocalStorage());
    _pendudukApi = PendudukApiService(client: http.Client());
    _bootstrap();
  }

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _ketCtrl.dispose();
    _tanggalCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredPenduduk() {
    Iterable<Map<String, dynamic>> source = _pendudukDropdown;
    if (_pendudukFilter == 'kk') {
      source = source.where((e) =>
          ((e['family_status'] ?? e['familyStatus'] ?? '')
                  .toString()
                  .toUpperCase() ==
              'KEPALA KELUARGA'));
    }
    if (_nikSearch.isEmpty) return source.toList();
    return source.where((e) {
      final nik = (e['nik'] ?? '').toString().toLowerCase();
      final nama = (e['full_name'] ?? '').toString().toLowerCase();
      return nik.contains(_nikSearch) || nama.contains(_nikSearch);
    }).toList();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadPendudukByVillage();
      await _loadKategoriDropdown();

      if (widget.current != null) {
        _selectedNik = (widget.current!['nik'] ?? '').toString().isEmpty
            ? null
            : widget.current!['nik'] as String;
        if (_selectedNik != null) {
          _selectedNiks
            ..clear()
            ..add(_selectedNik!);
        }
        _selectedKategoriId = widget.current!['kategori_id'] as int?;
        _selectedSubKategoriId = widget.current!['sub_kategori_id'] as int?;
        _nominalCtrl.text = (widget.current!['nominal'] ?? '').toString();
        _ketCtrl.text = (widget.current!['keterangan'] ?? '').toString();
        _tanggalCtrl.text = _toLocalYmd(_extractDateString(widget.current!));
        _statusVal = (widget.current!['status'] ?? 'pending').toString();
      }

      if (_selectedKategoriId != null) {
        await _loadSubKategoriDropdown(_selectedKategoriId!);
      }

      if (widget.current == null && _tanggalCtrl.text.trim().isEmpty) {
        final now = DateTime.now();
        final y = now.year.toString().padLeft(4, '0');
        final m = now.month.toString().padLeft(2, '0');
        final d = now.day.toString().padLeft(2, '0');
        _tanggalCtrl.text = '$y-$m-$d';
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPendudukByVillage() async {
    final villageId = _extractVillageId(widget.adminData);
    List<Map<String, dynamic>> list = [];
    if (villageId != null) {
      try {
        list = await _pendudukApi.getCitizensByVillageIdLiteExtended(villageId);
      } catch (_) {
        list = await _pendudukApi.getCitizensByVillageId(villageId);
      }
    } else {
      try {
        list = await _pendudukApi.getAllCitizensLiteExtended();
      } catch (_) {
        list = await _pendudukApi.getAllCitizensLite();
      }
    }
    list.sort((a, b) => (a['full_name'] ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b['full_name'] ?? '').toString().toLowerCase()));
    _pendudukDropdown = list;
  }

  Future<void> _loadKategoriDropdown() async {
    try {
      _kategoriDropdown = await _api.dropdownKategori();
      if (_kategoriDropdown.isEmpty) {
        final list = await _api.kategori();
        _kategoriDropdown = list
            .whereType<Map<String, dynamic>>()
            .map((m) => {
                  'id': m['id'],
                  'nama_kategori': m['nama_kategori'],
                  'subKategoris': m['sub_kategoris'] ?? m['subKategoris']
                })
            .toList();
      }
    } catch (_) {
      final list = await _api.kategori();
      _kategoriDropdown = list
          .whereType<Map<String, dynamic>>()
          .map((m) => {
                'id': m['id'],
                'nama_kategori': m['nama_kategori'],
                'subKategoris': m['sub_kategoris'] ?? m['subKategoris']
              })
          .toList();
    }
  }

  Future<void> _loadSubKategoriDropdown(int kategoriId) async {
    try {
      _subKategoriDropdown = await _api.dropdownSubKategori(kategoriId);
      if (_subKategoriDropdown.isEmpty) {
        Map<String, dynamic>? found;
        for (final e in _kategoriDropdown) {
          if (e is Map && (e['id'] as num?)?.toInt() == kategoriId) {
            found = Map<String, dynamic>.from(e);
            break;
          }
        }
        if (found != null && found['subKategoris'] is List) {
          _subKategoriDropdown = (found['subKategoris'] as List)
              .whereType<Map<String, dynamic>>()
              .map((s) =>
                  {'id': s['id'], 'nama_sub_kategori': s['nama_sub_kategori']})
              .toList();
        }
      }
    } catch (_) {
      Map<String, dynamic>? found;
      for (final e in _kategoriDropdown) {
        if (e is Map && (e['id'] as num?)?.toInt() == kategoriId) {
          found = Map<String, dynamic>.from(e);
          break;
        }
      }
      if (found != null && found['subKategoris'] is List) {
        _subKategoriDropdown = (found['subKategoris'] as List)
            .whereType<Map<String, dynamic>>()
            .map((s) =>
                {'id': s['id'], 'nama_sub_kategori': s['nama_sub_kategori']})
            .toList();
      } else {
        _subKategoriDropdown = [];
      }
    }
  }

  int? _extractVillageId(Map<String, dynamic> adminData) {
    try {
      final user = adminData['data']?['user'] ?? adminData['user'] ?? {};
      final pemdes = adminData['data']?['pemerintah_desa'] ??
          adminData['pemerintah_desa'] ??
          {};
      final candidates = [
        user['village_id'],
        user['villageId'],
        user['villages_id'],
        pemdes['village_id'],
        pemdes['villageId'],
        pemdes['villages_id'],
        (user is Map && user['village'] is Map) ? user['village']['id'] : null,
        (pemdes is Map && pemdes['village'] is Map)
            ? pemdes['village']['id']
            : null,
      ];
      for (final c in candidates) {
        if (c == null) continue;
        final v = int.tryParse(c.toString());
        if (v != null) return v;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_selectedKategoriId == null || _selectedSubKategoriId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kategori dan Sub Kategori wajib diisi')));
      return;
    }
    final parsedNominal = _parseNominal(_nominalCtrl.text);
    if (parsedNominal == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nominal tidak valid')));
      return;
    }
    final ymd = _normalizeDateYmd(_tanggalCtrl.text.trim());
    try {
      if (widget.current == null) {
        final selected =
            _selectedNiks.where((e) => e.trim().isNotEmpty).toList();
        if (selected.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih minimal satu NIK')));
          return;
        }
        if (selected.length == 1) {
          final payload = {
            'nik': selected.first,
            'kategori_id': _selectedKategoriId,
            'sub_kategori_id': _selectedSubKategoriId,
            'nominal': parsedNominal,
            'keterangan': _ketCtrl.text.trim(),
            'status': _statusVal,
            'tanggal': ymd,
          };
          await _api.createTagihan(payload);
        } else {
          await _api.createMultipleTagihan(
            selectedNiks: selected,
            kategoriId: _selectedKategoriId!,
            subKategoriId: _selectedSubKategoriId!,
            nominal: parsedNominal,
            keterangan:
                _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
            status: _statusVal,
            tanggal: ymd,
          );
        }
      } else {
        if (_selectedNik == null || _selectedNik!.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih NIK terlebih dahulu')));
          return;
        }
        final payload = {
          'nik': _selectedNik,
          'kategori_id': _selectedKategoriId,
          'sub_kategori_id': _selectedSubKategoriId,
          'nominal': parsedNominal,
          'keterangan': _ketCtrl.text.trim(),
          'status': _statusVal,
          'tanggal': ymd,
        };
        await _api.updateTagihan(
            (widget.current!['id'] as num).toInt(), payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: ${e.toString()}')));
    }
  }

  DateTime _parseDateOr(DateTime fallback) {
    try {
      if (_tanggalCtrl.text.trim().isEmpty) return fallback;
      final parts = _tanggalCtrl.text.trim().split('-');
      if (parts.length != 3) return fallback;
      final y = int.tryParse(parts[0]) ?? fallback.year;
      final m = int.tryParse(parts[1]) ?? fallback.month;
      final d = int.tryParse(parts[2]) ?? fallback.day;
      return DateTime(y, m, d);
    } catch (_) {
      return fallback;
    }
  }

  String _normalizeDateYmd(String input) {
    try {
      String s = input.trim();
      if (s.isEmpty) return s;
      if (s.endsWith('Z')) s = s.substring(0, s.length - 1);
      if (s.contains('T')) s = s.split('T').first;
      if (s.contains(' ')) s = s.split(' ').first;
      final parts = s.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          final yy = y.toString().padLeft(4, '0');
          final mm = m.toString().padLeft(2, '0');
          final dd = d.toString().padLeft(2, '0');
          return '$yy-$mm-$dd';
        }
      }
      final dt = DateTime.tryParse(input);
      if (dt != null) {
        final yy = dt.year.toString().padLeft(4, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final dd = dt.day.toString().padLeft(2, '0');
        return '$yy-$mm-$dd';
      }
      return input;
    } catch (_) {
      return input;
    }
  }

  String _toLocalYmd(String input) {
    try {
      String s = input.trim();
      if (s.isEmpty) return s;
      DateTime? dt;
      if (s.contains('T') || s.endsWith('Z')) {
        dt = DateTime.tryParse(s)?.toLocal();
      } else {
        final parts = s.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) dt = DateTime(y, m, d);
        }
      }
      dt ??= DateTime.tryParse(s)?.toLocal();
      if (dt == null) return _normalizeDateYmd(input);
      final yy = dt.year.toString().padLeft(4, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      return '$yy-$mm-$dd';
    } catch (_) {
      return _normalizeDateYmd(input);
    }
  }

  String _extractDateString(Map<String, dynamic> m) {
    final candidates = [
      m['tanggal'],
      m['tanggal_tagihan'],
      m['due_date'],
      m['tgl'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString();
      if (s.trim().isNotEmpty) return s;
    }
    return '';
  }

  double? _parseNominal(String input) {
    try {
      String v = input.trim();
      if (v.isEmpty) return null;
      final dotCount = '.'.allMatches(v).length;
      final commaCount = ','.allMatches(v).length;

      if (commaCount > 0) {
        v = v.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(v);
      }

      if (dotCount == 0) {
        return double.tryParse(v);
      } else if (dotCount == 1) {
        return double.tryParse(v);
      } else {
        v = v.replaceAll('.', '');
        return double.tryParse(v);
      }
    } catch (_) {
      return null;
    }
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    IconData? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: AppTheme.primaryColor, size: 20),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: const Color(0xFF64748B), size: 18)
          : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.current == null ? 'Tambah Tagihan' : 'Ubah Tagihan',
          style: const TextStyle(
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
        actionsIconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang penduduk',
            onPressed: () async {
              await _loadPendudukByVillage();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _bootstrap,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
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
                                    color: const Color(0xFFE6F4F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Informasi Tagihan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (widget.current != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_pin_rounded,
                                        color: AppTheme.primaryColor, size: 22),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('NIK Penduduk (Tetap)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedNik ?? '-',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            DropdownButtonFormField<int>(
                              value: _selectedKategoriId,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                labelText: 'Kategori',
                                hintText: 'Pilih Kategori',
                                prefixIcon: Icons.category_outlined,
                              ),
                              items: _kategoriDropdown
                                  .map((e) => DropdownMenuItem<int>(
                                        value: e['id'] as int,
                                        child: Text(
                                          (e['nama_kategori'] ?? '-')
                                              .toString(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  _selectedKategoriId = v;
                                  _selectedSubKategoriId = null;
                                  _subKategoriDropdown = [];
                                });
                                if (v != null) {
                                  await _loadSubKategoriDropdown(v);
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              value: _selectedSubKategoriId,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                labelText: 'Sub Kategori',
                                hintText: 'Pilih Sub Kategori',
                                prefixIcon:
                                    Icons.subdirectory_arrow_right_outlined,
                              ),
                              items: _subKategoriDropdown
                                  .map((e) => DropdownMenuItem<int>(
                                        value: e['id'] as int,
                                        child: Text(
                                          (e['nama_sub_kategori'] ?? '-')
                                              .toString(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _selectedSubKategoriId = v;
                              }),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nominalCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: _inputDecoration(
                                labelText: 'Nominal',
                                hintText: 'Masukkan jumlah nominal',
                                prefixIcon: Icons.payments_outlined,
                                prefixText: 'Rp ',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _tanggalCtrl,
                              readOnly: true,
                              decoration: _inputDecoration(
                                labelText: 'Tanggal Tagihan',
                                hintText: 'YYYY-MM-DD',
                                prefixIcon: Icons.calendar_today_outlined,
                                suffixIcon: Icons.edit_calendar_outlined,
                              ),
                              onTap: () async {
                                final now = DateTime.now();
                                final initial = _parseDateOr(now);
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(now.year + 5, 12, 31),
                                  helpText: 'Pilih Tanggal Tagihan',
                                  cancelText: 'Batal',
                                  confirmText: 'Pilih',
                                );
                                if (picked != null) {
                                  final y =
                                      picked.year.toString().padLeft(4, '0');
                                  final m =
                                      picked.month.toString().padLeft(2, '0');
                                  final d =
                                      picked.day.toString().padLeft(2, '0');
                                  setState(() {
                                    _tanggalCtrl.text = '$y-$m-$d';
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _statusVal,
                              decoration: _inputDecoration(
                                labelText: 'Status Pembayaran',
                                prefixIcon: Icons.flag_outlined,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule_rounded,
                                          size: 16, color: Color(0xFFD97706)),
                                      SizedBox(width: 8),
                                      Text('Pending (Menunggu)'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'lunas',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          size: 16, color: Color(0xFF059669)),
                                      SizedBox(width: 8),
                                      Text('Lunas'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'belum_lunas',
                                  child: Row(
                                    children: [
                                      Icon(Icons.highlight_off_rounded,
                                          size: 16, color: Color(0xFFDC2626)),
                                      SizedBox(width: 8),
                                      Text('Belum Lunas'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _statusVal = v ?? 'pending';
                              }),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _ketCtrl,
                              maxLines: 2,
                              decoration: _inputDecoration(
                                labelText: 'Keterangan',
                                hintText:
                                    'Catatan atau rincian tagihan (opsional)',
                                prefixIcon: Icons.notes_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.current == null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
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
                                      color: const Color(0xFFE6F4F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.people_alt_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pilih Sasaran Penduduk',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          'Bisa memilih lebih dari satu penduduk',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Muat ulang penduduk',
                                    icon: const Icon(Icons.refresh_rounded,
                                        color: AppTheme.primaryColor),
                                    onPressed: () async {
                                      await _loadPendudukByVillage();
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(9),
                                        onTap: () {
                                          setState(() {
                                            _pendudukFilter = 'all';
                                            final visibleNiks =
                                                _filteredPenduduk()
                                                    .map((e) => (e['nik'] ?? '')
                                                        .toString())
                                                    .toSet();
                                            _selectedNiks.removeWhere((nik) =>
                                                !visibleNiks.contains(nik));
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _pendudukFilter == 'all'
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            boxShadow: _pendudukFilter == 'all'
                                                ? const [
                                                    BoxShadow(
                                                      color: Color(0x0A000000),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Semua Penduduk',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  _pendudukFilter == 'all'
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                              color: _pendudukFilter == 'all'
                                                  ? AppTheme.primaryColor
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(9),
                                        onTap: () {
                                          setState(() {
                                            _pendudukFilter = 'kk';
                                            final visibleNiks =
                                                _filteredPenduduk()
                                                    .map((e) => (e['nik'] ?? '')
                                                        .toString())
                                                    .toSet();
                                            _selectedNiks.removeWhere((nik) =>
                                                !visibleNiks.contains(nik));
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _pendudukFilter == 'kk'
                                                ? Colors.white
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            boxShadow: _pendudukFilter == 'kk'
                                                ? const [
                                                    BoxShadow(
                                                      color: Color(0x0A000000),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Kepala Keluarga',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  _pendudukFilter == 'kk'
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                              color: _pendudukFilter == 'kk'
                                                  ? AppTheme.primaryColor
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Cari NIK atau Nama...',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      color: Color(0xFF64748B), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 1.4),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (v) => setState(() {
                                  _nikSearch = v.trim().toLowerCase();
                                }),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _filteredPenduduk().isNotEmpty &&
                                          _filteredPenduduk().every((e) =>
                                              _selectedNiks.contains(
                                                  (e['nik'] ?? '').toString())),
                                      activeColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            for (final e
                                                in _filteredPenduduk()) {
                                              final nik =
                                                  (e['nik'] ?? '').toString();
                                              if (nik.isNotEmpty) {
                                                _selectedNiks.add(nik);
                                              }
                                            }
                                          } else {
                                            for (final e
                                                in _filteredPenduduk()) {
                                              final nik =
                                                  (e['nik'] ?? '').toString();
                                              _selectedNiks.remove(nik);
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _pendudukFilter == 'kk'
                                        ? 'Pilih semua (Kepala Keluarga)'
                                        : 'Pilih semua hasil',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Terpilih: ${_selectedNiks.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 320),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _filteredPenduduk().isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24.0),
                                          child: Text(
                                            'Tidak ada data penduduk yang cocok',
                                            style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 13),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        shrinkWrap: true,
                                        itemCount: _filteredPenduduk().length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                height: 1,
                                                color: Color(0xFFF1F5F9)),
                                        itemBuilder: (ctx, i) {
                                          final e = _filteredPenduduk()[i];
                                          final nik =
                                              (e['nik'] ?? '').toString();
                                          final nama = (e['full_name'] ?? '-')
                                              .toString();
                                          final familyStatus =
                                              (e['family_status'] ??
                                                      e['familyStatus'] ??
                                                      '')
                                                  .toString();
                                          final checked =
                                              _selectedNiks.contains(nik);
                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (checked) {
                                                  _selectedNiks.remove(nik);
                                                } else {
                                                  _selectedNiks.add(nik);
                                                }
                                              });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: Checkbox(
                                                      value: checked,
                                                      activeColor:
                                                          AppTheme.primaryColor,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4)),
                                                      onChanged: (val) {
                                                        setState(() {
                                                          if (val == true) {
                                                            _selectedNiks
                                                                .add(nik);
                                                          } else {
                                                            _selectedNiks
                                                                .remove(nik);
                                                          }
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          nama,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF1E293B),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              nik,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                color: Color(
                                                                    0xFF64748B),
                                                              ),
                                                            ),
                                                            if (familyStatus
                                                                .isNotEmpty) ...[
                                                              const SizedBox(
                                                                  width: 6),
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        5,
                                                                    vertical:
                                                                        1),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                      0xFFE2E8F0),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: Text(
                                                                  familyStatus,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Color(
                                                                        0xFF475569),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 20),
                          label: const Text(
                            'Simpan Tagihan',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _submit,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}
