import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    final filtered = _items
        .where((e) => (e['nama_kategori'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Tagihan',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4A47DC),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A47DC),
        onPressed: () => _createOrEdit(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari kategori',
                  border: OutlineInputBorder(),
                  isDense: true),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final m = filtered[i] as Map<String, dynamic>;
                            final List<dynamic> subs =
                                (m['sub_kategoris'] as List?) ??
                                    (m['subKategoris'] as List?) ??
                                    const [];
                            return Card(
                              child: ExpansionTile(
                                title:
                                    Text(m['nama_kategori']?.toString() ?? '-'),
                                subtitle: Text('Sub Kategori: ${subs.length}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.orange),
                                      onPressed: () =>
                                          _createOrEdit(current: m),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _delete(m),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.blue),
                                      tooltip: 'Tambah Sub Kategori',
                                      onPressed: () async {
                                        final controller =
                                            TextEditingController();
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                                'Tambah Sub Kategori'),
                                            content: TextField(
                                              controller: controller,
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      'Nama Sub Kategori'),
                                            ),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Batal')),
                                              ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Simpan')),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          final nama = controller.text.trim();
                                          if (nama.isNotEmpty) {
                                            try {
                                              await _api.createSubKategori(
                                                  (m['id'] as num).toInt(),
                                                  nama);
                                              _load();
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Gagal tambah: ${e.toString()}')));
                                              }
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                children: subs
                                    .whereType<Map<String, dynamic>>()
                                    .map((s) => ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          leading: const Icon(
                                              Icons.subdirectory_arrow_right,
                                              size: 18),
                                          title: Text(s['nama_sub_kategori']
                                                  ?.toString() ??
                                              '-'),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 18,
                                                    color: Colors.orange),
                                                onPressed: () =>
                                                    _editSubKategori(m, s),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    size: 18,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _deleteSubKategori(s),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
