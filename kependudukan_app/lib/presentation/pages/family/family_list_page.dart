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
  Future<void> _batchLoadFotoDiri(List<String> nikList,
      {bool forceRefresh = false}) async {
    if (nikList.isEmpty) return;

    final nikToLoad = forceRefresh
        ? nikList
        : nikList
            .where((nik) =>
                !_fotoDiriByNik.containsKey(nik) &&
                !_fotoCheckedNik.contains(nik))
            .toList();

    if (nikToLoad.isEmpty) return;

    _fotoCheckedNik.addAll(nikToLoad);

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
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final cachedKK =
          await authLocalStorage.getCachedKKByNik(widget.nikPenduduk);

      if (cachedKK != null && cachedKK.isNotEmpty) {
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

      try {
        final pendudukApiService = GetIt.instance<PendudukApiService>();
        final kk = await pendudukApiService.getKKByNik(widget.nikPenduduk);

        if (!mounted) return;

        if (kk != null && kk.isNotEmpty) {
          await authLocalStorage.cacheKKByNik(widget.nikPenduduk, kk);

          setState(() {
            _currentKK = kk;
            _errorMessage = null;
            _isLoadingKK = false;
          });
          _loadFamilyData();
        } else {
          _loadKKDataFallback();
        }
      } catch (e) {
        _loadKKDataFallback();
      }
    } catch (e) {
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
    final kk = widget.kk.isNotEmpty ? widget.kk : _currentKK;

    if (kk.isEmpty) {
      return;
    }

    if (forceRefresh) {
      _fotoDiriByNik.clear();
      _fotoCheckedNik.clear();
    }

    await _familyCubit.loadFamilyMembers(kk, forceRefresh: forceRefresh);

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Data Keluarga',
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
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Terjadi Kesalahan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                              _currentKK = '';
                            });
                            _loadKKDataOptimized();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Tampilkan loading untuk KK jika sedang mengambil data KK
          if (_isLoadingKK) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sedang mengambil data KK...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mohon tunggu sebentar',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is FamilyInitial ||
              (state is FamilyLoading && state.currentMembers.isEmpty)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Memuat data keluarga...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is FamilyError) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memuat Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _loadFamilyData(forceRefresh: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (state is FamilyEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.people_outline_rounded,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Anggota Keluarga',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tidak ada data anggota keluarga yang terdaftar pada nomor KK ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final members = state is FamilyLoaded ? state.members : [];
          final isLoadingMore = state is FamilyLoading;
          final displayKK = _currentKK.isNotEmpty ? _currentKK : widget.kk;

          return RefreshIndicator(
            onRefresh: () => _loadFamilyData(forceRefresh: true),
            color: AppTheme.primaryColor,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: members.length + 1 + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Header Item: Summary Card KK
                if (index == 0) {
                  return _buildHeaderCard(displayKK, members.length);
                }

                final memberIndex = index - 1;

                if (memberIndex >= members.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                }

                final member = members[memberIndex];
                final bool isCurrentUser = member.nik == widget.nikPenduduk;

                return _buildMemberCard(member, isCurrentUser);
              },
            ),
          );
        },
      ),
    );
  }

  /// Header summary card for Kartu Keluarga
  Widget _buildHeaderCard(String kkNumber, int totalMembers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cottage_rounded,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nomor Kartu Keluarga (KK)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kkNumber.isNotEmpty ? kkNumber : '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (totalMembers > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$totalMembers Orang',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Modern Card for Family Member
  Widget _buildMemberCard(dynamic member, bool isCurrentUser) {
    final statusColorData = _getStatusBadge(member.familyStatus);
    final photoUrl = _fotoDiriByNik[member.nik];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.8)
              : const Color(0xFFE2E8F0),
          width: isCurrentUser ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : const Color(0x08000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDocuments(member),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrentUser
                              ? AppTheme.primaryColor
                              : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: (photoUrl != null && photoUrl.trim().isNotEmpty)
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildAvatarFallback(
                                      member.fullName, isCurrentUser);
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isCurrentUser
                                            ? AppTheme.primaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _buildAvatarFallback(
                                member.fullName, isCurrentUser),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Member Information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  member.fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isCurrentUser)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 12,
                                        color: AppTheme.primaryColor,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Anda',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                member.nik,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColorData.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusColorData.icon,
                                  size: 13,
                                  color: statusColorData.textColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatFamilyStatus(member.familyStatus),
                                  style: TextStyle(
                                    color: statusColorData.textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Divider line
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Button row: Lihat Dokumen
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Berkas Kependudukan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _navigateToDocuments(member),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Lihat Dokumen',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
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
  }

  Widget _buildAvatarFallback(String fullName, bool isCurrentUser) {
    String initials = '';
    final parts = fullName.trim().split(' ');
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials += parts[0][0];
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials += parts[1][0];
      }
    }
    if (initials.isEmpty) initials = 'P';

    return Container(
      color: isCurrentUser
          ? const Color(0xFFE0F2FE)
          : const Color(0xFFF1F5F9),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isCurrentUser
                ? AppTheme.primaryColor
                : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _navigateToDocuments(dynamic member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FamilyMemberDocumentsPage(
          nik: member.nik,
          name: member.fullName,
        ),
      ),
    );
  }

  _StatusBadgeData _getStatusBadge(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('kepala keluarga')) {
      return const _StatusBadgeData(
        backgroundColor: Color(0xFFE0F2FE),
        textColor: Color(0xFF0369A1),
        icon: Icons.shield_outlined,
      );
    }
    if (lower.contains('istri')) {
      return const _StatusBadgeData(
        backgroundColor: Color(0xFFFCE7F3),
        textColor: Color(0xFFBE185D),
        icon: Icons.favorite_border_rounded,
      );
    }
    if (lower.contains('anak')) {
      return const _StatusBadgeData(
        backgroundColor: Color(0xFFDCFCE7),
        textColor: Color(0xFF15803D),
        icon: Icons.child_care_rounded,
      );
    }
    if (lower.contains('cucu')) {
      return const _StatusBadgeData(
        backgroundColor: Color(0xFFFEF3C7),
        textColor: Color(0xFFB45309),
        icon: Icons.face_rounded,
      );
    }
    return const _StatusBadgeData(
      backgroundColor: Color(0xFFF3E8FF),
      textColor: Color(0xFF7E22CE),
      icon: Icons.person_outline_rounded,
    );
  }

  String _formatFamilyStatus(String status) {
    if (status.isNotEmpty) {
      return status[0].toUpperCase() + status.substring(1);
    }
    return status;
  }
}

class _StatusBadgeData {
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const _StatusBadgeData({
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
  });
}
