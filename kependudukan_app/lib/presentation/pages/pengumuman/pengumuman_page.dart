import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/pengumuman_api_service.dart';
import 'package:ladimas/data/models/pengumuman_model.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'pengumuman_detail_page.dart';

class PengumumanPage extends StatefulWidget {
  const PengumumanPage({Key? key}) : super(key: key);

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  late final PengumumanApiService _api;
  final TextEditingController _searchController = TextEditingController();
  List<PengumumanModel> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = PengumumanApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );
    _load();
  }

  Future<void> _load({String? search}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final result = await _api.getPengumumanList(search: search);
      if (!mounted) return;
      setState(() {
        _items = result;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi kesalahan: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(date);
    } catch (_) {
      return value;
    }
  }

  String _stripHtml(String input) {
    try {
      final noTags = input.replaceAll(RegExp(r'<[^>]*>'), ' ');
      return noTags.replaceAll('&nbsp;', ' ').replaceAll('\n', ' ').trim();
    } catch (_) {
      return input;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Cari pengumuman...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (v) => _load(search: v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _load(search: _searchController.text.trim()),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _load(
                                    search: _searchController.text.trim()),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(child: Text('Belum ada pengumuman'))
                        : RefreshIndicator(
                            onRefresh: () =>
                                _load(search: _searchController.text.trim()),
                            child: ListView.separated(
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Card(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: item.gambarUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              item.gambarUrl,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons
                                                      .image_not_supported),
                                            ),
                                          )
                                        : const Icon(Icons.campaign, size: 40),
                                    title: Text(
                                      _stripHtml(item.judul),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          _stripHtml(item.deskripsi),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatDate(item.createdAt),
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PengumumanDetailPage(id: item.id),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
