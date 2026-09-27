import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';
import 'package:ladimas/presentation/cubits/family/family_cubit.dart';
import 'package:ladimas/presentation/pages/family/family_member_document_page.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/penduduk_api_service.dart';
import 'package:get_it/get_it.dart';

class FamilyListPage extends StatefulWidget {
  final String kk;
  final String nikPenduduk;

  const FamilyListPage({Key? key, required this.kk, required this.nikPenduduk})
      : super(key: key);

  @override
  State<FamilyListPage> createState() => _FamilyListPageState();
}

class _FamilyListPageState extends State<FamilyListPage> {
  late final FamilyCubit _familyCubit;
  late final FamilyRepository _familyRepository;
  final ScrollController _scrollController = ScrollController();
  String _currentKK = '';
  bool _isLoadingKK = false;
  String? _errorMessage;
  final Map<String, String> _fotoDiriByNik = {};
  final Set<String> _fotoCheckedNik = {};

  @override
  void initState() {
    super.initState();
    _familyCubit = GetIt.instance<FamilyCubit>();
    _familyRepository = GetIt.instance<FamilyRepository>();

    // Jika kk kosong, coba ambil dari cache dulu, baru dari API
    if (widget.kk.isEmpty) {
      _loadKKDataOptimized();
    } else {
      _loadFamilyData();
    }

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  /// Batch load foto diri untuk semua anggota keluarga sekaligus
  /// Ini lebih efisien daripada load satu per satu di itemBuilder
  Future<void> _batchLoadFotoDiri(List<String> nikList,
      {bool forceRefresh = false}) async {
    if (nikList.isEmpty) return;

    // Jika force refresh, load semua foto
    // Jika tidak, hanya load yang belum di-cache
    final nikToLoad = forceRefresh
        ? nikList
        : nikList
            .where((nik) =>
                !_fotoDiriByNik.containsKey(nik) &&
                !_fotoCheckedNik.contains(nik))
            .toList();

    if (nikToLoad.isEmpty) return;

    // Mark semua sebagai sedang di-check
    _fotoCheckedNik.addAll(nikToLoad);

    // Load semua foto secara parallel dengan forceRefresh jika diperlukan
    final futures = nikToLoad.map((nik) async {
      final result = await _familyRepository.getFamilyMemberDocuments(nik,
          forceRefresh: forceRefresh);
      return result.fold(
        (_) => null,
        (docs) {
          final url = docs.fotoDiri?.previewUrl ?? '';
          if (url.isNotEmpty) {
            return MapEntry<String, String>(nik, url);
          }
          return null;
        },
      );
    });

    final results = await Future.wait(futures);

    if (mounted) {
      setState(() {
        for (final result in results) {
          if (result != null) {
            _fotoDiriByNik[result.key] = result.value;
          }
        }
      });
    }
  }

  /// Lazy load foto diri untuk item yang terlihat (untuk optimasi lebih lanjut)
  Future<void> _ensureFotoDiri(String nik) async {
    if (_fotoDiriByNik.containsKey(nik) || _fotoCheckedNik.contains(nik)) {
      return;
    }
    _fotoCheckedNik.add(nik);
    final result = await _familyRepository.getFamilyMemberDocuments(nik);
    result.fold(
      (_) {},
      (docs) {
        final url = docs.fotoDiri?.previewUrl ?? '';
        if (mounted && url.isNotEmpty) {
          setState(() {
            _fotoDiriByNik[nik] = url;
          });
        }
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _familyCubit.loadMoreMembers();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Optimasi: Cek cache KK dulu sebelum memanggil API
  Future<void> _loadKKDataOptimized() async {
    if (_isLoadingKK) return;

    setState(() => _isLoadingKK = true);

    try {
      // Cek cache KK terlebih dahulu (jauh lebih cepat!)
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final cachedKK =
          await authLocalStorage.getCachedKKByNik(widget.nikPenduduk);

      if (cachedKK != null && cachedKK.isNotEmpty) {
        // KK ditemukan di cache, langsung gunakan
        if (mounted) {
          setState(() {
            _currentKK = cachedKK;
            _errorMessage = null;
            _isLoadingKK = false;
          });
          _loadFamilyData();
        }
        return;
      }

      // Jika tidak ada di cache, gunakan method cepat getKKByNik dari PendudukApiService
      try {
        final pendudukApiService = GetIt.instance<PendudukApiService>();
        final kk = await pendudukApiService.getKKByNik(widget.nikPenduduk);

        if (!mounted) return;

        if (kk != null && kk.isNotEmpty) {
          // Cache hasilnya untuk penggunaan berikutnya
          await authLocalStorage.cacheKKByNik(widget.nikPenduduk, kk);

          setState(() {
            _currentKK = kk;
            _errorMessage = null;
            _isLoadingKK = false;
          });
          _loadFamilyData();
        } else {
          // Jika getKKByNik tidak menemukan KK, fallback ke getPendudukDetail
          _loadKKDataFallback();
        }
      } catch (e) {
        // Fallback jika ada error
        _loadKKDataFallback();
      }
    } catch (e) {
      // Fallback ke method lama jika ada error
      _loadKKDataFallback();
    }
  }

  /// Fallback method: menggunakan getPendudukDetail (method lama)
  Future<void> _loadKKDataFallback() async {
    try {
      final repository = GetIt.instance<AuthRepository>();
      final result = await repository.getPendudukDetail(widget.nikPenduduk);

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _errorMessage = 'Gagal mendapatkan data KK: ${failure.message}';
            _isLoadingKK = false;
          });
        },
        (data) {
          final kk = data['kk']?.toString() ?? '';
          if (kk.isNotEmpty) {
            setState(() {
              _currentKK = kk;
              _errorMessage = null;
              _isLoadingKK = false;
            });
            _loadFamilyData();
          } else {
            setState(() {
              _errorMessage =
                  'Nomor KK tidak tersedia untuk melihat data keluarga';
              _isLoadingKK = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoadingKK = false;
        });
      }
    }
  }

  Future<void> _loadFamilyData({bool forceRefresh = false}) async {
    // Gunakan kk yang sudah ada atau yang baru didapat
    final kk = widget.kk.isNotEmpty ? widget.kk : _currentKK;

    if (kk.isEmpty) {
      return;
    }

    // Jika force refresh, clear cache foto diri juga
    if (forceRefresh) {
      _fotoDiriByNik.clear();
      _fotoCheckedNik.clear();
    }

    await _familyCubit.loadFamilyMembers(kk, forceRefresh: forceRefresh);

    // Setelah data keluarga berhasil di-load, batch load foto diri
    // Tunggu sedikit untuk memastikan state sudah update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final state = _familyCubit.state;
        if (state is FamilyLoaded) {
          final nikList = state.members.map((m) => m.nik).toList();
          _batchLoadFotoDiri(nikList, forceRefresh: forceRefresh);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Data Keluarga',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadFamilyData(forceRefresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocBuilder<FamilyCubit, FamilyState>(
        bloc: _familyCubit,
        builder: (context, state) {
          // Tampilkan error message jika ada
          if (_errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _currentKK = '';
                        });
                        _loadKKDataOptimized();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Tampilkan loading untuk KK jika sedang mengambil data KK
          if (_isLoadingKK) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text('Sedang mengambil data KK...'),
                ],
              ),
            );
          }

          if (state is FamilyInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (state is FamilyLoading && (state.currentMembers.isEmpty)) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (state is FamilyError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _loadFamilyData(forceRefresh: true),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is FamilyEmpty) {
            return const Center(
              child: Text(
                'Tidak ada data anggota keluarga',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final members = state is FamilyLoaded ? state.members : [];
          final isLoadingMore = state is FamilyLoading;

          return RefreshIndicator(
            onRefresh: () => _loadFamilyData(forceRefresh: true),
            color: AppTheme.primaryColor,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: members.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= members.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final member = members[index];
                final bool isCurrentUser = member.nik == widget.nikPenduduk;
                // Foto sudah di-load via batch load, tidak perlu load lagi di sini
                // Hanya lazy load jika foto belum ada dan item terlihat

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isCurrentUser
                        ? const BorderSide(
                            color: AppTheme.primaryColor, width: 2)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isCurrentUser
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade200,
                              backgroundImage:
                                  (_fotoDiriByNik[member.nik] != null &&
                                          _fotoDiriByNik[member.nik]!
                                              .trim()
                                              .isNotEmpty)
                                      ? NetworkImage(
                                          _fotoDiriByNik[member.nik]!,
                                        )
                                      : null,
                              child: (_fotoDiriByNik[member.nik] == null ||
                                      _fotoDiriByNik[member.nik]!
                                          .trim()
                                          .isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      color: isCurrentUser
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.fullName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NIK: ${member.nik}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(member.familyStatus),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _formatFamilyStatus(member.familyStatus),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isCurrentUser)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              '(Anda)',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),

                        // Documents button
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FamilyMemberDocumentsPage(
                                        nik: member.nik,
                                        name: member.fullName,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.file_copy, size: 18),
                                label: const Text('Dokumen'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                ),
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
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('kepala keluarga')) return Colors.blue.shade700;
    if (status.contains('istri')) return Colors.pink.shade400;
    if (status.contains('anak')) return Colors.green.shade600;
    if (status.contains('cucu')) return Colors.orange.shade600;
    return Colors.purple.shade400;
  }

  String _formatFamilyStatus(String status) {
    if (status.isNotEmpty) {
      return status[0].toUpperCase() + status.substring(1);
    }
    return status;
  }
}
