import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

      // Set default tanggal ke hari ini saat mode tambah (create)
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
      // gunakan extended agar ada family_status untuk filter KK
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
            found = Map<String, dynamic>.from(e as Map);
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
          found = Map<String, dynamic>.from(e as Map);
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
        // create mode: gunakan bulk jika multi, single jika 1
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
        // edit mode: tetap single
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
      // fallback tryParse
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

  String _asMiddayIso8601(String input) {
    final ymd = _normalizeDateYmd(input);
    if (ymd.isEmpty) return ymd;
    // gunakan 12:00:00Z untuk menghindari pergeseran tanggal saat di-UTC-kan di server
    return '${ymd}T12:00:00.000Z';
  }

  String _asMiddayDateTime(String input) {
    final ymd = _normalizeDateYmd(input);
    if (ymd.isEmpty) return ymd;
    return '$ymd 12:00:00';
  }

  String _asMiddayLocalString(String ymd) {
    if (ymd.isEmpty) return ymd;
    // string tanpa zona waktu (DB akan menyimpan apa adanya pada kolom DATETIME/DATE)
    return '$ymd 12:00:00';
  }

  String _toIsoWithLocalOffset(String input) {
    final ymd = _normalizeDateYmd(input);
    if (ymd.isEmpty) return ymd;
    final nowOffset = DateTime.now().timeZoneOffset; // e.g., 7:00:00.000000
    final sign = nowOffset.isNegative ? '-' : '+';
    final totalMinutes = nowOffset.inMinutes.abs();
    final hh = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final mm = (totalMinutes % 60).toString().padLeft(2, '0');
    // gunakan jam 00:00 lokal dengan offset eksplisit
    return '${ymd}T00:00:00$sign$hh:$mm';
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

      // Jika ada koma, anggap koma sebagai decimal dan titik ribuan
      if (commaCount > 0) {
        v = v.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(v);
      }

      // Tidak ada koma
      if (dotCount == 0) {
        // Murni angka
        return double.tryParse(v);
      } else if (dotCount == 1) {
        // Satu titik: anggap sebagai decimal, jangan hapus
        return double.tryParse(v);
      } else {
        // Banyak titik: anggap ribuan, hapus semua titik
        v = v.replaceAll('.', '');
        return double.tryParse(v);
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.current == null ? 'Tambah Tagihan' : 'Ubah Tagihan',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4A47DC),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang penduduk',
            onPressed: () async {
              await _loadPendudukByVillage();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.current != null) ...[
                          // Mode edit: tampilkan NIK read-only
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'NIK Penduduk',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              _selectedNik ?? '-',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<int>(
                          value: _selectedKategoriId,
                          decoration:
                              const InputDecoration(labelText: 'Kategori'),
                          isExpanded: true,
                          hint: const Text('Pilih Kategori'),
                          items: _kategoriDropdown
                              .map((e) => DropdownMenuItem<int>(
                                    value: e['id'] as int,
                                    child: Text(
                                      (e['nama_kategori'] ?? '-').toString(),
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedSubKategoriId,
                          decoration:
                              const InputDecoration(labelText: 'Sub Kategori'),
                          isExpanded: true,
                          hint: const Text('Pilih Sub Kategori'),
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
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nominalCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Nominal'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ketCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Keterangan'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tanggalCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Tanggal (YYYY-MM-DD)',
                            suffixIcon: Icon(Icons.calendar_today),
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
                              final y = picked.year.toString().padLeft(4, '0');
                              final m = picked.month.toString().padLeft(2, '0');
                              final d = picked.day.toString().padLeft(2, '0');
                              setState(() {
                                _tanggalCtrl.text = '$y-$m-$d';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _statusVal,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(
                                value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(
                                value: 'lunas', child: Text('Lunas')),
                            DropdownMenuItem(
                                value: 'belum_lunas',
                                child: Text('Belum Lunas')),
                          ],
                          onChanged: (v) => setState(() {
                            _statusVal = v ?? 'pending';
                          }),
                        ),
                        const SizedBox(height: 16),
                        if (widget.current == null) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 'all',
                                        label: Text('Semua penduduk')),
                                    ButtonSegment(
                                        value: 'kk',
                                        label: Text('Kepala keluarga')),
                                  ],
                                  selected: {_pendudukFilter},
                                  onSelectionChanged: (sel) {
                                    final val = sel.first;
                                    setState(() {
                                      _pendudukFilter = val;
                                      // reset seleksi yang tidak muncul setelah filter
                                      final visibleNiks = _filteredPenduduk()
                                          .map((e) =>
                                              (e['nik'] ?? '').toString())
                                          .toSet();
                                      _selectedNiks.removeWhere(
                                          (nik) => !visibleNiks.contains(nik));
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Muat ulang',
                                icon: const Icon(Icons.refresh),
                                onPressed: () async {
                                  await _loadPendudukByVillage();
                                  if (mounted) setState(() {});
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pilih Penduduk (bisa lebih dari satu)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Cari NIK / Nama',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() {
                              _nikSearch = v.trim().toLowerCase();
                            }),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _filteredPenduduk().isNotEmpty &&
                                    _filteredPenduduk().every((e) =>
                                        _selectedNiks.contains(
                                            (e['nik'] ?? '').toString())),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      for (final e in _filteredPenduduk()) {
                                        final nik = (e['nik'] ?? '').toString();
                                        if (nik.isNotEmpty) {
                                          _selectedNiks.add(nik);
                                        }
                                      }
                                    } else {
                                      for (final e in _filteredPenduduk()) {
                                        final nik = (e['nik'] ?? '').toString();
                                        _selectedNiks.remove(nik);
                                      }
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _pendudukFilter == 'kk'
                                    ? 'Pilih semua (Kepala keluarga)'
                                    : 'Pilih semua hasil',
                              ),
                              const Spacer(),
                              Text('Terpilih: ${_selectedNiks.length}')
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 320),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _filteredPenduduk().isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text('Tidak ada data'),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredPenduduk().length,
                                    itemBuilder: (ctx, i) {
                                      final e = _filteredPenduduk()[i];
                                      final nik = (e['nik'] ?? '').toString();
                                      final nama =
                                          (e['full_name'] ?? '-').toString();
                                      final checked =
                                          _selectedNiks.contains(nik);
                                      return CheckboxListTile(
                                        dense: true,
                                        value: checked,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedNiks.add(nik);
                                            } else {
                                              _selectedNiks.remove(nik);
                                            }
                                          });
                                        },
                                        title: Text('$nama ($nik)'),
                                      );
                                    },
                                  ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Simpan'),
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
