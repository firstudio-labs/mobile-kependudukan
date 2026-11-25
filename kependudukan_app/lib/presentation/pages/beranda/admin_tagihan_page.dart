import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/pages/beranda/admin_beranda_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_biodata_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:ladimas/data/datasources/admin_tagihan_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/data/datasources/penduduk_api_service.dart';
import 'package:ladimas/presentation/pages/beranda/admin_tagihan_form_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_tagihan_kategori_page.dart';

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
  int _totalItems = 0;
  final int _perPage = 10;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.addListener(_onScroll);
    _load();
    // Muat daftar penduduk seperti di form agar nama tersedia cepat
    _loadingNames = true;
    _loadPendudukByVillage().then((_) {
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }

    if (_scrollController.position.extentAfter < 250) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    _page = 1;
    _hasMore = true;
    _loadingMore = false;

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

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

      final dynamic responseData = res['data'];
      dynamic pageData = responseData;
      if (pageData is Map && pageData['data'] is Map) {
        pageData = pageData['data'];
      }

      final List<dynamic> items;
      if (pageData is Map && pageData['data'] is List) {
        items = List<dynamic>.from(pageData['data'] as List);
      } else if (responseData is List) {
        items = List<dynamic>.from(responseData);
      } else if (pageData is List) {
        items = List<dynamic>.from(pageData);
      } else {
        items = <dynamic>[];
      }

      final dynamic meta = pageData is Map ? pageData : null;
      final int? apiLastPage = int.tryParse(
        (meta?['last_page'] ?? res['last_page'] ?? '').toString(),
      );
      final int? apiTotal = int.tryParse(
        (meta?['total'] ?? res['total'] ?? '').toString(),
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _totalItems = apiTotal ?? items.length;
        _hasMore = apiLastPage != null
            ? _page < apiLastPage
            : items.length >= _perPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Gagal Memuat Data', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Tidak dapat memuat data. Periksa koneksi internet Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    final int nextPage = _page + 1;
    setState(() => _loadingMore = true);

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
        page: nextPage,
        perPage: _perPage,
      );

      final dynamic responseData = res['data'];
      dynamic pageData = responseData;
      if (pageData is Map && pageData['data'] is Map) {
        pageData = pageData['data'];
      }

      final List<dynamic> newItems;
      if (pageData is Map && pageData['data'] is List) {
        newItems = List<dynamic>.from(pageData['data'] as List);
      } else if (responseData is List) {
        newItems = List<dynamic>.from(responseData);
      } else if (pageData is List) {
        newItems = List<dynamic>.from(pageData);
      } else {
        newItems = <dynamic>[];
      }

      final dynamic meta = pageData is Map ? pageData : null;
      final int? apiLastPage = int.tryParse(
        (meta?['last_page'] ?? res['last_page'] ?? '').toString(),
      );
      final int? apiTotal = int.tryParse(
        (meta?['total'] ?? res['total'] ?? '').toString(),
      );

      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(newItems);
        _totalItems = apiTotal ?? _items.length;
        _hasMore = apiLastPage != null
            ? _page < apiLastPage
            : newItems.length >= _perPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat tagihan berikutnya. Coba scroll lagi.'),
        ),
      );
    }
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

  Future<void> _openTagihanForm({Map<String, dynamic>? current}) async {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          initialValue: selectedNik,
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
                    initialValue: kategoriId,
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
                    initialValue: subKategoriId,
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
                    initialValue: statusVal,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Tagihan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Hapus tagihan NIK ${m['nik']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
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

  String _formatNominal(dynamic val) {
    if (val == null) return '-';
    final s = val.toString().trim();
    if (s.isEmpty) return '-';
    final parsed = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
    if (parsed != null) {
      final intVal = parsed.toInt();
      final str = intVal.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      return 'Rp $str';
    }
    if (!s.startsWith('Rp')) return 'Rp $s';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Tagihan',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actionsIconTheme: const IconThemeData(color: AppTheme.primaryColor),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          if (_loading || _loadingNames)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopActions(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Tagihan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (_items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_totalItems data',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        items: [
          AppBottomNavBar.item(icon: Icons.home_outlined, label: ''),
          AppBottomNavBar.item(icon: Icons.receipt_long, label: ''),
          AppBottomNavBar.item(icon: Icons.person_outline, label: ''),
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
                  hintText: 'Cari NIK atau keterangan...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
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
            const SizedBox(width: 10),
            Material(
              color: _showFilters
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showFilters
                          ? AppTheme.primaryColor
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    _showFilters
                        ? Icons.filter_list_off_rounded
                        : Icons.filter_list_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
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
              const double gap = 12;
              final double itemW =
                  columns == 1 ? maxW : (maxW - gap * (columns - 1)) / columns;

              List<Widget> filterWidgets() => [
                    SizedBox(
                      width: columns == 1 ? maxW : itemW,
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        isDense: true,
                        decoration: _filterInputDecoration('Status'),
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
                                  ? 'Tanggal mulai'
                                  : 'Mulai: $_startDate',
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDateButton(
                              label: _endDate == null
                                  ? 'Tanggal akhir'
                                  : 'Akhir: $_endDate',
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
                        decoration: _filterInputDecoration('Pilih Kategori'),
                        items: _kategoriDropdown
                            .map((e) => DropdownMenuItem<int>(
                                  value: e['id'] as int?,
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
                        decoration:
                            _filterInputDecoration('Pilih Sub Kategori'),
                        items: _subKategoriDropdown
                            .map((e) => DropdownMenuItem<int>(
                                  value: e['id'] as int?,
                                  child: Text(
                                    (e['nama_sub_kategori'] ?? '-').toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                  ];

              return Container(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryColor),
                            SizedBox(width: 6),
                            Text(
                              'Filter Tagihan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
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
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFF64748B)),
                                SizedBox(width: 4),
                                Text(
                                  'Reset',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: filterWidgets(),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  InputDecoration _filterInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.4),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.category_outlined, size: 18),
            label: const Text('Kategori'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              elevation: 0,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
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
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Tambah Tagihan'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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

  Widget _buildDateButton(
      {required String label, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.primaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
    return '$y-$m-$da';
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
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
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 12),
              Text(
                'Belum Ada Tagihan',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Data tagihan warga akan ditampilkan di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _items.length + ((_hasMore || _loadingMore) ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            );
          }
          if (_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Muat lebih banyak'),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
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
            final found = _pendudukDropdown.firstWhere(
                (e) => (e['nik'] ?? '').toString() == nik,
                orElse: () => {});
            final lookupName = (found['full_name'] ?? '').toString();
            if (lookupName.isNotEmpty) {
              _nikNameCache[nik] = lookupName;
              nama = lookupName;
            } else {
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

        final String statusLower = status.toLowerCase();
        final Color statusColor;
        final Color statusBackground;
        final IconData statusIcon;
        if (statusLower == 'lunas') {
          statusColor = const Color(0xFF059669);
          statusBackground = const Color(0xFFECFDF5);
          statusIcon = Icons.check_circle_outline_rounded;
        } else if (statusLower == 'pending') {
          statusColor = const Color(0xFFD97706);
          statusBackground = const Color(0xFFFFFBEB);
          statusIcon = Icons.access_time_rounded;
        } else {
          statusColor = const Color(0xFFDC2626);
          statusBackground = const Color(0xFFFEF2F2);
          statusIcon = Icons.highlight_off_rounded;
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                  color: Colors.white,
                  position: const RelativeRect.fromLTRB(200, 200, 0, 0),
                  items: const [
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                    PopupMenuItem(
                        value: 'status', child: Text('Ubah Status Cepat')),
                  ],
                );
                if (selected == 'edit') {
                  if (!context.mounted) return;
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    nik.isEmpty ? 'NIK tidak tersedia' : 'NIK: $nik',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  if (isResolvingName) ...[
                                    const SizedBox(width: 6),
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 19,
                            color: Color(0xFF94A3B8),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (selected) async {
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
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 17, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('Ubah Tagihan', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'status',
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 17, color: Color(0xFF475569)),
                                  SizedBox(width: 8),
                                  Text('Ubah Status', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'hapus',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFDC2626)),
                                  SizedBox(width: 8),
                                  Text('Hapus', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildInfoChip(
                          Icons.category_outlined,
                          kategori,
                        ),
                        _buildInfoChip(
                          Icons.subdirectory_arrow_right_outlined,
                          subKategori,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 11, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status.isEmpty
                                    ? '-'
                                    : status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tanggal,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatNominal(nominal),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLongDate(String input) {
    if (input.isEmpty) return '-';
    try {
      final s = input.trim();
      DateTime? dt;
      if (s.contains('T') || s.endsWith('Z')) {
        dt = DateTime.tryParse(s)?.toLocal();
      } else {
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
        'Desember',
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
