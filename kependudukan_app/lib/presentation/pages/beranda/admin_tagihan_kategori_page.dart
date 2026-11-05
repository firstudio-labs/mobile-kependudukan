import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/data/datasources/admin_tagihan_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:http/http.dart' as http;

class AdminTagihanKategoriPage extends StatefulWidget {
  const AdminTagihanKategoriPage({Key? key}) : super(key: key);

  @override
  State<AdminTagihanKategoriPage> createState() =>
      _AdminTagihanKategoriPageState();
}

class _AdminTagihanKategoriPageState extends State<AdminTagihanKategoriPage> {
  late final AdminTagihanApiService _api;
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _api = AdminTagihanApiService(
        client: http.Client(), authLocalStorage: AuthLocalStorage());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // coba kategori(); fallback ke kategoriIndex()
      try {
        final data = await _api.kategori();
        setState(() {
          _items = data;
          _loading = false;
        });
      } catch (_) {
        final list =
            await _api.kategoriIndex(search: _search, page: 1, perPage: 50);
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createOrEdit({Map<String, dynamic>? current}) async {
    final controller = TextEditingController(
        text: current?['nama_kategori']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(current == null ? 'Tambah Kategori' : 'Ubah Kategori'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Kategori'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (result != true) return;
    final nama = controller.text.trim();
    if (nama.isEmpty) return;
    try {
      if (current == null) {
        await _api.createKategori(nama);
      } else {
        await _api.updateKategori(current['id'] as int, nama);
      }
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: ${e.toString()}')));
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Hapus kategori "${m['nama_kategori']}"?'),
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
    if (ok != true) return;
    try {
      await _api.deleteKategori(m['id'] as int);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus: ${e.toString()}')));
    }
  }

  Future<void> _editSubKategori(
      Map<String, dynamic> kategori, Map<String, dynamic> sub) async {
    int kategoriId = (kategori['id'] as num).toInt();
    final controller =
        TextEditingController(text: sub['nama_sub_kategori']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Sub Kategori'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama Sub Kategori'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (result == true) {
      try {
        await _api.updateSubKategori(
            (sub['id'] as num).toInt(), kategoriId, controller.text.trim());
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal simpan: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _deleteSubKategori(Map<String, dynamic> sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sub Kategori'),
        content: Text('Hapus sub kategori "${sub['nama_sub_kategori']}"?'),
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
        await _api.deleteSubKategori((sub['id'] as num).toInt());
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal hapus: ${e.toString()}')));
        }
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where((e) => (e['nama_kategori'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Kategori Tagihan',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: AppTheme.primaryColor,
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFEEF0F5),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Tambah Kategori',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar Kategori',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202943),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Kelola kategori dan subkategori tagihan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filtered.length} kategori',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFE7EAF1),
                  ),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama kategori...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9AA3B5),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              setState(() => _search = '');
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 19,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),

              const SizedBox(height: 16),

              // List
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 42,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Gagal memuat kategori',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFEEF0F5),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F3FF),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: const Icon(
                                          Icons.category_outlined,
                                          size: 34,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Kategori tidak ditemukan',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF202943),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _search.isNotEmpty
                                            ? 'Coba kata kunci pencarian lain.'
                                            : 'Tambahkan kategori tagihan pertama.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8992A5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final m = filtered[i] as Map<String, dynamic>;

                                  final List<dynamic> subs =
                                      (m['sub_kategoris'] as List?) ??
                                          (m['subKategoris'] as List?) ??
                                          const [];

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(17),
                                      border: Border.all(
                                        color: const Color(0xFFEAEDF4),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.025),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent,
                                        splashColor:
                                            AppTheme.primaryColor.withOpacity(
                                          0.05,
                                        ),
                                        highlightColor: Colors.transparent,
                                      ),
                                      child: ExpansionTile(
                                        key: PageStorageKey(
                                          'kategori_${m['id']}',
                                        ),
                                        tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 5,
                                        ),
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(17),
                                        ),
                                        collapsedShape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(17),
                                        ),
                                        leading: Container(
                                          width: 43,
                                          height: 43,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEDF1FF),
                                            borderRadius:
                                                BorderRadius.circular(13),
                                          ),
                                          child: const Icon(
                                            Icons.category_rounded,
                                            color: AppTheme.primaryColor,
                                            size: 22,
                                          ),
                                        ),
                                        title: Text(
                                          m['nama_kategori']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF202943),
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.account_tree_outlined,
                                                size: 13,
                                                color: Color(0xFF8992A5),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                '${subs.length} subkategori',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF8992A5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Tombol aksi kategori
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Ubah kategori',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  _createOrEdit(current: m),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 19,
                                                color: Color(0xFFDA9225),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Hapus kategori',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () => _delete(m),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20,
                                                color: Color(0xFFE05252),
                                              ),
                                            ),
                                          ],
                                        ),

                                        children: [
                                          Container(
                                            height: 1,
                                            color: const Color(0xFFEEF0F5),
                                          ),
                                          const SizedBox(height: 8),

                                          // Header subkategori
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  'SUBKATEGORI',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1,
                                                    color: Color(0xFF8992A5),
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () async {
                                                  final controller =
                                                      TextEditingController();

                                                  final ok =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      backgroundColor:
                                                          Colors.white,
                                                      title: const Text(
                                                        'Tambah Sub Kategori',
                                                      ),
                                                      content: TextField(
                                                        controller: controller,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Nama Sub Kategori',
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                          child: const Text(
                                                            'Batal',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                          child: const Text(
                                                            'Simpan',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (ok == true) {
                                                    final nama =
                                                        controller.text.trim();

                                                    if (nama.isNotEmpty) {
                                                      try {
                                                        await _api
                                                            .createSubKategori(
                                                          (m['id'] as num)
                                                              .toInt(),
                                                          nama,
                                                        );
                                                        _load();
                                                      } catch (e) {
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Gagal tambah: ${e.toString()}',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    }
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 17,
                                                ),
                                                label: const Text(
                                                  'Tambah',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 4),

                                          if (subs.isEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF7F8FC),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Belum ada subkategori.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8992A5),
                                                ),
                                              ),
                                            )
                                          else
                                            ...subs
                                                .whereType<
                                                    Map<String, dynamic>>()
                                                .map(
                                                  (s) => Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                      bottom: 6,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 10,
                                                      right: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF7F8FC,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        11,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 30,
                                                          height: 30,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              9,
                                                            ),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .subdirectory_arrow_right_rounded,
                                                            size: 17,
                                                            color: AppTheme
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 9),
                                                        Expanded(
                                                          child: Text(
                                                            s['nama_sub_kategori']
                                                                    ?.toString() ??
                                                                '-',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                0xFF384158,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip:
                                                              'Ubah subkategori',
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          onPressed: () =>
                                                              _editSubKategori(
                                                            m,
                                                            s,
                                                          ),
                                                          icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 17,
                                                            color: Color(
                                                              0xFFDA9225,
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip:
                                                              'Hapus subkategori',
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          onPressed: () =>
                                                              _deleteSubKategori(
                                                            s,
                                                          ),
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            size: 18,
                                                            color: Color(
                                                              0xFFE05252,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
      ),
    );
  }
}
