import 'package:flutter/material.dart';
import 'package:ladimas/presentation/pages/beranda/admin_beranda_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_biodata_page.dart';
import 'package:ladimas/data/datasources/admin_tagihan_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/data/datasources/penduduk_api_service.dart';
import 'package:ladimas/presentation/pages/beranda/admin_tagihan_form_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_tagihan_kategori_page.dart';
// import sub kategori page dihapus

class AdminTagihanPage extends StatefulWidget {
  final Map<String, dynamic> adminData;

  const AdminTagihanPage({Key? key, required this.adminData}) : super(key: key);

  @override
  State<AdminTagihanPage> createState() => _AdminTagihanPageState();
}

class _AdminTagihanPageState extends State<AdminTagihanPage> {
  late final AdminTagihanApiService _api;
  late final PendudukApiService _pendudukApi;
  bool _loading = true;
  List<dynamic> _items = [];
  int _page = 1;
  final int _perPage = 10;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showFilters = false;

  String? _status; // pending|lunas|belum_lunas
  String? _search;
  int? _bulan;
  int? _tahun;
  int? _selectedKategoriId;
  int? _selectedSubKategoriId;
  String? _startDate; // YYYY-MM-DD
  String? _endDate; // YYYY-MM-DD
  List<dynamic> _kategoriDropdown = [];
  List<dynamic> _subKategoriDropdown = [];
  List<Map<String, dynamic>> _pendudukDropdown = [];
  final Map<String, String> _nikNameCache = {};
  bool _loadingNames = false;
  final Set<String> _resolvingNiks = <String>{};

  @override
  void initState() {
    super.initState();
    _api = AdminTagihanApiService(
        client: http.Client(), authLocalStorage: AuthLocalStorage());
    _pendudukApi = PendudukApiService(client: http.Client());
    _load();
    // Muat daftar penduduk seperti di form agar nama tersedia cepat
    _loadingNames = true;
    _loadPendudukByVillage().then((_) {
      // isi cache nik->nama untuk render awal
      for (final e in _pendudukDropdown) {
        final nik = (e['nik'] ?? '').toString();
        final nama = (e['full_name'] ?? '').toString();
        if (nik.isNotEmpty && nama.isNotEmpty) {
          _nikNameCache[nik] = nama;
        }
      }
      if (mounted) setState(() => _loadingNames = false);
    });
    // Muat dropdown kategori untuk filter
    _loadKategoriDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final res = await _api.listTagihan(
        status: _status,
        search: _search,
        bulan: _bulan,
        tahun: _tahun,
        kategoriId: _selectedKategoriId,
        subKategoriId: _selectedSubKategoriId,
        startDate: _startDate,
        endDate: _endDate,
        page: _page,
        perPage: _perPage,
      );
      final data = res['data'];
      final List<dynamic> items = (data is Map && data['data'] is List)
          ? data['data']
          : (res['data'] as List? ?? []);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Gagal Memuat Data'),
                  content: const Text(
                      'Tidak dapat memuat data. Periksa koneksi internet Anda.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ));
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadKategoriDropdown() async {
    try {
      // 1) Coba endpoint dropdown
      _kategoriDropdown = await _api.dropdownKategori();
      if (_kategoriDropdown.isEmpty) {
        // 2) Fallback ke kategori() yang mengandung subKategoris
        final list = await _api.kategori();
        _kategoriDropdown = list
            .whereType<Map<String, dynamic>>()
            .map((m) => {
                  'id': m['id'],
                  'nama_kategori': m['nama_kategori'],
                  // sisipkan subKategoris untuk fallback sub dropdown
                  'subKategoris': m['sub_kategoris'] ?? m['subKategoris']
                })
            .toList();
      }
    } catch (_) {
      try {
        final list = await _api.kategori();
        _kategoriDropdown = list
            .whereType<Map<String, dynamic>>()
            .map((m) => {
                  'id': m['id'],
                  'nama_kategori': m['nama_kategori'],
                  'subKategoris': m['sub_kategoris'] ?? m['subKategoris']
                })
            .toList();
      } catch (e) {
        _kategoriDropdown = [];
      }
    }
  }

  Future<void> _loadSubKategoriDropdownForFilter(int kategoriId) async {
    try {
      _subKategoriDropdown = await _api.dropdownSubKategori(kategoriId);
      if (_subKategoriDropdown.isEmpty) {
        // fallback: gunakan cache kategori() bila tersedia
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
      // fallback via kategori cache
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

  Future<void> _loadSubKategoriDropdown(int kategoriId) async {
    try {
      _subKategoriDropdown = await _api.dropdownSubKategori(kategoriId);
      if (_subKategoriDropdown.isEmpty) {
        // fallback: gunakan cache kategori() bila tersedia
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
      // fallback via kategori cache
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

  Future<void> _openTagihanForm({Map<String, dynamic>? current}) async {
    // Muat data dropdown secara aman (non-blocking kesalahan)
    try {
      await _loadPendudukByVillage();
    } catch (_) {
      _pendudukDropdown = [];
    }
    try {
      await _loadKategoriDropdown();
    } catch (_) {
      _kategoriDropdown = [];
      _subKategoriDropdown = [];
    }
    int? kategoriId = current?['kategori_id'] as int?;
    if (kategoriId != null) {
      try {
        await _loadSubKategoriDropdown(kategoriId);
      } catch (_) {
        _subKategoriDropdown = [];
      }
    } else if (_kategoriDropdown.isNotEmpty) {
      kategoriId = _kategoriDropdown.first['id'] as int?;
      if (kategoriId != null) {
        try {
          await _loadSubKategoriDropdown(kategoriId);
        } catch (_) {
          _subKategoriDropdown = [];
        }
      }
    }

    int? subKategoriId = current?['sub_kategori_id'] as int?;
    String? selectedNik = (current?['nik'] ?? '').toString().isEmpty
        ? null
        : (current?['nik'] as String);
    final nominalCtrl =
        TextEditingController(text: (current?['nominal'] ?? '').toString());
    final ketCtrl =
        TextEditingController(text: (current?['keterangan'] ?? '').toString());
    final tanggalCtrl =
        TextEditingController(text: (current?['tanggal'] ?? '').toString());
    String statusVal = (current?['status'] ?? 'pending').toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text(current == null ? 'Tambah Tagihan' : 'Ubah Tagihan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedNik,
                          decoration: const InputDecoration(
                              labelText: 'Pilih NIK Penduduk'),
                          items: _pendudukDropdown
                              .map((e) => DropdownMenuItem<String>(
                                    value: e['nik'] as String,
                                    child: Text(
                                        '${e['full_name'] ?? '-'} (${e['nik']})'),
                                  ))
                              .toList(),
                          onChanged: (v) => setStateDialog(() {
                            selectedNik = v;
                          }),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Muat ulang penduduk',
                        onPressed: () async {
                          try {
                            await _loadPendudukByVillage();
                          } catch (_) {
                            _pendudukDropdown = [];
                          }
                          if (mounted) setStateDialog(() {});
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: kategoriId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: _kategoriDropdown
                        .map((e) => DropdownMenuItem<int>(
                              value: e['id'] as int,
                              child:
                                  Text((e['nama_kategori'] ?? '-').toString()),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      setStateDialog(() {
                        kategoriId = v;
                        subKategoriId = null;
                        _subKategoriDropdown = [];
                      });
                      if (v != null) {
                        await _loadSubKategoriDropdown(v);
                        setStateDialog(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: subKategoriId,
                    decoration:
                        const InputDecoration(labelText: 'Sub Kategori'),
                    items: _subKategoriDropdown
                        .map((e) => DropdownMenuItem<int>(
                              value: e['id'] as int,
                              child: Text(
                                  (e['nama_sub_kategori'] ?? '-').toString()),
                            ))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => subKategoriId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nominalCtrl,
                    decoration: const InputDecoration(labelText: 'Nominal'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ketCtrl,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tanggalCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Tanggal (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: statusVal,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'lunas', child: Text('Lunas')),
                      DropdownMenuItem(
                          value: 'belum_lunas', child: Text('Belum Lunas')),
                    ],
                    onChanged: (v) =>
                        setStateDialog(() => statusVal = v ?? 'pending'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Simpan')),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      // Validasi minimal
      if (selectedNik == null || selectedNik!.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pilih NIK terlebih dahulu')));
        }
        return;
      }
      final parsedNominal = double.tryParse(
          nominalCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
      if (parsedNominal == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nominal tidak valid')));
        }
        return;
      }
      if (kategoriId == null || subKategoriId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Kategori dan Sub Kategori wajib diisi')));
        }
        return;
      }
      final payload = {
        'nik': selectedNik,
        'kategori_id': kategoriId,
        'sub_kategori_id': subKategoriId,
        'nominal': parsedNominal,
        'keterangan': ketCtrl.text.trim(),
        'status': statusVal,
        'tanggal': tanggalCtrl.text.trim(),
      };
      try {
        if (current == null) {
          await _api.createTagihan(payload);
        } else {
          await _api.updateTagihan((current['id'] as num).toInt(), payload);
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal simpan: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _loadPendudukByVillage() async {
    final villageId = _extractVillageId(widget.adminData);
    try {
      List<Map<String, dynamic>> list = [];
      if (villageId != null) {
        list = await _pendudukApi.getCitizensByVillageId(villageId);
      } else {
        list = await _pendudukApi.getAllCitizensLite();
      }
      list.sort((a, b) => (a['full_name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['full_name'] ?? '').toString().toLowerCase()));
      _pendudukDropdown = list;
      // perbarui cache nik->nama segera
      for (final e in list) {
        final nik = (e['nik'] ?? '').toString();
        final nama = (e['full_name'] ?? '').toString();
        if (nik.isNotEmpty && nama.isNotEmpty) {
          _nikNameCache[nik] = nama;
        }
      }
    } catch (_) {
      _pendudukDropdown = [];
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

  Future<void> _deleteTagihan(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tagihan'),
        content: Text('Hapus tagihan NIK ${m['nik']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteTagihan((m['id'] as num).toInt());
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal hapus: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _quickUpdateStatus(Map<String, dynamic> m) async {
    final next = m['status'] == 'pending'
        ? 'belum_lunas'
        : m['status'] == 'belum_lunas'
            ? 'lunas'
            : 'pending';
    try {
      await _api.updateStatus((m['id'] as num).toInt(), next);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal update status: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tagihan', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4A47DC),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_loading || _loadingNames)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTopActions(),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      // FAB dihilangkan; tambah dipindah ke AppBar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: const Color(0xFF4A47DC),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, size: 28), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long, size: 28), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 28), label: ''),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminBerandaPage(adminData: widget.adminData),
                ),
              );
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminBiodataPage(adminData: widget.adminData),
                ),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari NIK/Keterangan',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _search = null;
                              _page = 1;
                            });
                            _load();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) {
                  _search = v.trim().isEmpty ? null : v.trim();
                  _page = 1;
                  _load();
                },
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list),
              label: const Text('Filter'),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
          ],
        ),
        if (_showFilters) const SizedBox(height: 12),
        if (_showFilters)
          LayoutBuilder(
            builder: (context, constraints) {
              final double maxW = constraints.maxWidth;
              final int columns = maxW >= 860
                  ? 3
                  : maxW >= 580
                      ? 2
                      : 1;
              final double gap = 12;
              final double itemW =
                  columns == 1 ? maxW : (maxW - gap * (columns - 1)) / columns;

              List<Widget> filterWidgets() => [
                    SizedBox(
                      width: columns == 1 ? maxW : itemW,
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(
                              value: 'lunas', child: Text('Lunas')),
                          DropdownMenuItem(
                              value: 'belum_lunas', child: Text('Belum Lunas')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _status = v;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ),
                    SizedBox(
                      width: columns == 1 ? maxW : itemW,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateButton(
                              label: _startDate == null
                                  ? 'Mulai'
                                  : 'Mulai: ' + _startDate!,
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDateButton(
                              label: _endDate == null
                                  ? 'Selesai'
                                  : 'Selesai: ' + _endDate!,
                              onTap: _pickEndDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: columns == 1 ? maxW : itemW,
                      child: DropdownButtonFormField<int>(
                        value: _selectedKategoriId,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Kategori',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _kategoriDropdown
                            .map((e) => DropdownMenuItem<int>(
                                  value: e['id'] as int?,
                                  child: Text(
                                      (e['nama_kategori'] ?? '-').toString()),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setState(() {
                            _selectedKategoriId = v;
                            _selectedSubKategoriId = null;
                            _subKategoriDropdown = [];
                            _page = 1;
                          });
                          if (v != null) {
                            await _loadSubKategoriDropdownForFilter(v);
                            setState(() {});
                          }
                          _load();
                        },
                      ),
                    ),
                    SizedBox(
                      width: columns == 1 ? maxW : itemW,
                      child: DropdownButtonFormField<int>(
                        value: _selectedSubKategoriId,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Sub Kategori',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _subKategoriDropdown
                            .map((e) => DropdownMenuItem<int>(
                                  value: e['id'] as int?,
                                  child: Text((e['nama_sub_kategori'] ?? '-')
                                      .toString()),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedSubKategoriId = v;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ),
                    SizedBox(
                      width: columns == 1 ? maxW : itemW,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Reset Filter',
                          onPressed: () {
                            setState(() {
                              _status = null;
                              _selectedKategoriId = null;
                              _selectedSubKategoriId = null;
                              _subKategoriDropdown = [];
                              _startDate = null;
                              _endDate = null;
                              _page = 1;
                            });
                            _load();
                          },
                        ),
                      ),
                    ),
                  ];

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: filterWidgets(),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.category),
            label: const Text('Kategori'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminTagihanKategoriPage()),
              );
              _load();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Tagihan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A47DC),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final saved = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminTagihanFormPage(
                    adminData: widget.adminData,
                  ),
                ),
              );
              if (saved == true) _load();
            },
          ),
        ),
      ],
    );
  }

  // UI helper: tombol tanggal bergaya ringan
  Widget _buildDateButton(
      {required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: Color(0xFF4A47DC), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _startDate = _formatYmd(picked);
        _page = 1;
      });
      _load();
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _endDate = _formatYmd(picked);
        _page = 1;
      });
      _load();
    }
  }

  String _formatYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return y + '-' + m + '-' + da;
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Belum ada tagihan'));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = _items[index] as Map<String, dynamic>;
        final String nik = (m['nik'] ?? '').toString();
        String nama =
            (m['nama'] ?? m['full_name'] ?? m['penduduk']?['full_name'])
                    ?.toString() ??
                '-';
        if (nik.isNotEmpty) {
          if (_nikNameCache.containsKey(nik)) {
            nama = _nikNameCache[nik]!;
          } else {
            // coba cari dari daftar penduduk yang sudah dimuat seperti di form
            final found = _pendudukDropdown.firstWhere(
                (e) => (e['nik'] ?? '').toString() == nik,
                orElse: () => {});
            final lookupName = (found['full_name'] ?? '').toString();
            if (lookupName.isNotEmpty) {
              _nikNameCache[nik] = lookupName;
              nama = lookupName;
            } else {
              // fallback: lazy fetch detail jika belum ada
              // tahan dulu sampai prefetch penduduk selesai agar tidak spam request besar paralel
              if (!_loadingNames) {
                _ensurePendudukName(nik);
              }
            }
          }
        }
        final String status = (m['status'] ?? '').toString();
        final String tanggal = _formatLongDate((m['tanggal'] ?? '').toString());
        final String kategori =
            m['kategori']?['nama_kategori']?.toString() ?? '-';
        final String subKategori =
            m['sub_kategori']?['nama_sub_kategori']?.toString() ?? '-';
        final String nominal = (m['nominal'] ?? '').toString();

        final bool isResolvingName = nik.isNotEmpty &&
            !_nikNameCache.containsKey(nik) &&
            !_pendudukDropdown.any((e) =>
                (e['nik'] ?? '').toString() == nik &&
                (e['full_name'] ?? '').toString().isNotEmpty) &&
            _resolvingNiks.contains(nik);

        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF4A47DC)),
            title: Row(
              children: [
                Expanded(child: Text('$nik • $nama')),
                if (isResolvingName)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A47DC)),
                    ),
                  ),
              ],
            ),
            subtitle: Text('$kategori / $subKategori\n$tanggal'),
            isThreeLine: true,
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nominal.isEmpty ? '-' : nominal,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'lunas'
                        ? Colors.green[100]
                        : status == 'pending'
                            ? Colors.orange[100]
                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () async {
              final saved = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminTagihanFormPage(
                    adminData: widget.adminData,
                    current: m,
                  ),
                ),
              );
              if (saved == true) _load();
            },
            onLongPress: () async {
              final selected = await showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(200, 200, 0, 0),
                items: const [
                  PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                  PopupMenuItem(
                      value: 'status', child: Text('Ubah Status Cepat')),
                ],
              );
              if (selected == 'edit') {
                final saved = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminTagihanFormPage(
                      adminData: widget.adminData,
                      current: m,
                    ),
                  ),
                );
                if (saved == true) _load();
              } else if (selected == 'hapus') {
                _deleteTagihan(m);
              } else if (selected == 'status') {
                _quickUpdateStatus(m);
              }
            },
          ),
        );
      },
    );
  }

  String _formatLongDate(String input) {
    if (input.isEmpty) return '-';
    try {
      final s = input.trim();
      DateTime? dt;
      if (s.contains('T') || s.endsWith('Z')) {
        // ISO string: parse lalu konversi ke waktu lokal
        dt = DateTime.tryParse(s)?.toLocal();
      } else {
        // YYYY-MM-DD atau sejenisnya
        final parts = s.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) {
            dt = DateTime(y, m, d);
          }
        }
      }
      dt ??= DateTime.tryParse(s)?.toLocal();
      if (dt == null) return input;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final monthName = months[dt.month - 1];
      return '${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return input;
    }
  }

  Future<void> _ensurePendudukName(String nik) async {
    if (_nikNameCache.containsKey(nik)) return;
    try {
      final already = _resolvingNiks.contains(nik);
      if (!already) {
        _resolvingNiks.add(nik);
        if (mounted) setState(() {});
      }
      final detail = await _pendudukApi.getPendudukDetailByNik(nik);
      final fullName = (detail['full_name'] ?? '').toString();
      if (fullName.isNotEmpty) {
        _nikNameCache[nik] = fullName;
        if (mounted) setState(() {});
      }
    } catch (_) {
    } finally {
      if (_resolvingNiks.contains(nik)) {
        _resolvingNiks.remove(nik);
        if (mounted) setState(() {});
      }
    }
  }
}
