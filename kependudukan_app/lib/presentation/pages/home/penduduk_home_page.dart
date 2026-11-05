import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/pages/berita-desa/berita_desa_form_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:intl/intl.dart';
import 'package:ladimas/data/datasources/pengumuman_api_service.dart';
import 'package:ladimas/data/models/pengumuman_model.dart';
import 'package:ladimas/presentation/pages/pengumuman/pengumuman_detail_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/data/datasources/berita_desa_api_service.dart';
import 'package:ladimas/data/models/berita_desa_model.dart';
import 'package:ladimas/data/datasources/laporan_api_service.dart';
import 'package:ladimas/data/models/laporan_model.dart';
import 'package:get_it/get_it.dart';
import 'package:ladimas/presentation/pages/berita-desa/berita_desa_detail_page.dart';
import 'package:ladimas/presentation/pages/village_report/laporan_detail_page.dart';
import 'package:ladimas/presentation/pages/village_report/laporan_form_page.dart';
import 'package:ladimas/data/datasources/agenda_api_service.dart';
import 'package:ladimas/data/models/agenda_model.dart';
import 'package:ladimas/presentation/pages/agenda/agenda_detail_page.dart';
import 'package:ladimas/core/services/penduduk_home_data_manager.dart';

class PendudukHomePage extends StatefulWidget {
  final Penduduk penduduk;
  final int? initialTabIndex;
  const PendudukHomePage({
    Key? key,
    required this.penduduk,
    this.initialTabIndex,
  }) : super(key: key);

  @override
  State<PendudukHomePage> createState() => _PendudukHomePageState();
}

class _PendudukHomePageState extends State<PendudukHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PengumumanApiService _pengumumanApiService;
  late final BeritaDesaApiService _beritaDesaApiService;
  late final VillageReportApiService _laporanApiService;
  late final AgendaApiService _agendaApiService;

  // Global data manager
  final PendudukHomeDataManager _dataManager = PendudukHomeDataManager();

  DateTime? _lastTapTime;
  TabController? _tabController;
  int _currentTabIndex = 0;

  // Cache untuk villageId agar tidak perlu fetch berulang
  int? _cachedVillageId;
  bool _isLoadingVillageId = false;
  Future<int?>? _villageIdFuture;

  // Flag untuk menandai apakah initial load sudah selesai
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.penduduk.nik.isEmpty || widget.penduduk.token.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Data penduduk tidak lengkap. Silakan login ulang.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      });
      return;
    }

    final initialIndex = widget.initialTabIndex ?? 0;
    _currentTabIndex = initialIndex;

    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(() {
      final newIndex = _tabController!.index;
      if (newIndex != _currentTabIndex) {
        setState(() {
          _currentTabIndex = newIndex;
        });
        _loadDataForTab(newIndex);
      }
    });

    _pengumumanApiService = PengumumanApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );

    _beritaDesaApiService = BeritaDesaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );

    _laporanApiService = GetIt.instance<VillageReportApiService>();

    _agendaApiService = AgendaApiService(
      client: http.Client(),
      authLocalStorage: AuthLocalStorage(),
    );

    _dataManager.resetLoadingStates();
    _startVillageIdPrefetch();
    _preloadVillageIdAndData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isInitialLoadComplete) {
      _checkForUpdatesInBackground();
    }
  }

  Future<void> _preloadVillageIdAndData() async {
    if (_dataManager.isDataFresh && _dataManager.hasLoadedData) {
      _isInitialLoadComplete = true;
      if (mounted) setState(() {});
      _checkForUpdatesInBackground();
      return;
    }

    _startVillageIdPrefetch();

    bool hasDataForCurrentTab = false;
    switch (_currentTabIndex) {
      case 0:
        hasDataForCurrentTab = _dataManager.beritaDesa.isNotEmpty;
        break;
      case 1:
        hasDataForCurrentTab = _dataManager.laporan.isNotEmpty;
        break;
      case 2:
        hasDataForCurrentTab = _dataManager.pengumuman.isNotEmpty;
        break;
      case 3:
        hasDataForCurrentTab = _dataManager.agenda.isNotEmpty;
        break;
    }

    if (!hasDataForCurrentTab) {
      switch (_currentTabIndex) {
        case 0:
          _dataManager.setLoadingBerita(true);
          break;
        case 1:
          _dataManager.setLoadingLaporan(true);
          break;
        case 2:
          _dataManager.setLoadingPengumuman(true);
          break;
        case 3:
          _dataManager.setLoadingAgenda(true);
          break;
      }
      if (mounted) setState(() {});
    }

    try {
      switch (_currentTabIndex) {
        case 0:
          await _loadBeritaDesa();
          break;
        case 1:
          await _loadLaporan();
          break;
        case 2:
          await _loadPengumuman();
          break;
        case 3:
          await _loadAgenda();
          break;
      }

      _isInitialLoadComplete = true;
      if (mounted) setState(() {});

      _loadOtherTabsDataInBackground();
    } catch (_) {
      _isInitialLoadComplete = true;
      _dataManager.resetLoadingStates();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadOtherTabsDataInBackground() async {
    _startVillageIdPrefetch();
    final futures = <Future>[];

    if (_currentTabIndex != 0) futures.add(_loadBeritaDesa());
    if (_currentTabIndex != 1) futures.add(_loadLaporan());
    if (_currentTabIndex != 2) futures.add(_loadPengumuman());
    if (_currentTabIndex != 3) futures.add(_loadAgenda());

    if (futures.isNotEmpty) {
      Future.wait(futures).catchError((e) => <dynamic>[]);
    }
  }

  Future<void> _checkForUpdatesInBackground() async {
    try {
      final futures = [
        _loadBeritaDesa(forceRefresh: true),
        _loadLaporan(forceRefresh: true),
        _loadPengumuman(forceRefresh: true),
        _loadAgenda(forceRefresh: true),
      ];

      await Future.wait(futures);
      _dataManager.markDataAsLoaded();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadDataForTab(int tabIndex) async {
    bool needsLoad = false;

    switch (tabIndex) {
      case 0:
        if (_dataManager.beritaDesa.isEmpty && !_dataManager.isLoadingBerita) {
          needsLoad = true;
          _dataManager.setLoadingBerita(true);
        }
        break;
      case 1:
        if (_dataManager.laporan.isEmpty && !_dataManager.isLoadingLaporan) {
          needsLoad = true;
          _dataManager.setLoadingLaporan(true);
        }
        break;
      case 2:
        if (_dataManager.pengumuman.isEmpty &&
            !_dataManager.isLoadingPengumuman) {
          needsLoad = true;
          _dataManager.setLoadingPengumuman(true);
        }
        break;
      case 3:
        if (_dataManager.agenda.isEmpty && !_dataManager.isLoadingAgenda) {
          needsLoad = true;
          _dataManager.setLoadingAgenda(true);
        }
        break;
    }

    if (needsLoad && mounted) {
      setState(() {});
    }

    if (needsLoad) {
      try {
        switch (tabIndex) {
          case 0:
            await _loadBeritaDesa();
            break;
          case 1:
            await _loadLaporan();
            break;
          case 2:
            await _loadPengumuman();
            break;
          case 3:
            await _loadAgenda();
            break;
        }
      } catch (_) {}
    }
  }

  Future<void> _loadPengumuman({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh &&
        _dataManager.pengumuman.isNotEmpty &&
        _dataManager.isDataFresh) {
      return;
    }

    try {
      if (forceRefresh || _dataManager.pengumuman.isEmpty) {
        if (mounted) {
          _dataManager.setLoadingPengumuman(true);
          if (forceRefresh) {
            await _pengumumanApiService.clearCache();
            _dataManager.setPengumuman([]);
          }
          setState(() {});
        }
      }

      final items = await _pengumumanApiService.getPengumumanList().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Koneksi timeout saat memuat pengumuman');
        },
      );

      if (mounted) {
        _dataManager.setPengumuman(items);
        _dataManager.setLoadingPengumuman(false);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _dataManager.setLoadingPengumuman(false);
        if (forceRefresh) _dataManager.setPengumuman([]);
        setState(() {});
        final errorMessage = e.toString().contains('timeout')
            ? 'Koneksi timeout. Silakan coba lagi.'
            : e.toString().contains('internet')
                ? 'Tidak ada koneksi internet.'
                : 'Gagal memuat pengumuman. Silakan coba lagi.';
        MessageService.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  Future<void> _loadBeritaDesa({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh &&
        _dataManager.beritaDesa.isNotEmpty &&
        _dataManager.isDataFresh) {
      return;
    }

    try {
      if (forceRefresh || _dataManager.beritaDesa.isEmpty) {
        if (mounted) {
          _dataManager.setLoadingBerita(true);
          if (forceRefresh) _dataManager.setBeritaDesa([]);
          setState(() {});
        }
      }

      if (forceRefresh) {
        await _beritaDesaApiService.clearCache();
      }

      final villageId = await _getVillageId();
      if (villageId == null || villageId == 0) {
        if (mounted) {
          _dataManager.setLoadingBerita(false);
          setState(() {});
          MessageService.showErrorSnackBar(
              context, 'Data desa tidak ditemukan. Silakan lengkapi profil.');
        }
        return;
      }

      final berita = await _beritaDesaApiService
          .getBeritaDesa(villageId: villageId)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Koneksi timeout saat memuat berita desa');
        },
      );

      if (mounted) {
        _dataManager.setBeritaDesa(berita);
        _dataManager.setLoadingBerita(false);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _dataManager.setLoadingBerita(false);
        if (forceRefresh) _dataManager.setBeritaDesa([]);
        setState(() {});
        final errorMessage = e.toString().contains('timeout')
            ? 'Koneksi timeout. Silakan coba lagi.'
            : e.toString().contains('internet')
                ? 'Tidak ada koneksi internet.'
                : 'Gagal memuat berita desa. Silakan coba lagi.';
        MessageService.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  Future<void> _loadLaporan({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh &&
        _dataManager.laporan.isNotEmpty &&
        _dataManager.isDataFresh) {
      return;
    }

    try {
      if (forceRefresh || _dataManager.laporan.isEmpty) {
        if (mounted) {
          _dataManager.setLoadingLaporan(true);
          if (forceRefresh) _dataManager.setLaporan([]);
          setState(() {});
        }
      }

      final laporan = await _laporanApiService.getVillageReports(
          forceRefresh: forceRefresh);

      if (mounted) {
        _dataManager.setLaporan(laporan);
        _dataManager.setLoadingLaporan(false);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _dataManager.setLoadingLaporan(false);
        if (forceRefresh) _dataManager.setLaporan([]);
        setState(() {});
        MessageService.showErrorSnackBar(
            context, 'Gagal memuat laporan: ${e.toString()}');
      }
    }
  }

  Future<void> _loadAgenda({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (!forceRefresh &&
        _dataManager.agenda.isNotEmpty &&
        _dataManager.isDataFresh) {
      return;
    }

    try {
      if (forceRefresh || _dataManager.agenda.isEmpty) {
        if (mounted) {
          _dataManager.setLoadingAgenda(true);
          if (forceRefresh) _dataManager.setAgenda([]);
          setState(() {});
        }
      }

      if (forceRefresh) {
        await _agendaApiService.clearCache();
      }

      final villageId = await _getVillageId();
      if (villageId == null || villageId == 0) {
        if (mounted) {
          _dataManager.setLoadingAgenda(false);
          setState(() {});
          MessageService.showErrorSnackBar(
              context, 'Data desa tidak ditemukan. Silakan lengkapi profil.');
        }
        return;
      }

      final agenda = await _agendaApiService
          .getAgenda(villageId: villageId, forceRefresh: forceRefresh)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Koneksi timeout saat memuat agenda');
        },
      );

      if (mounted) {
        _dataManager.setAgenda(agenda);
        _dataManager.setLoadingAgenda(false);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _dataManager.setLoadingAgenda(false);
        if (forceRefresh) _dataManager.setAgenda([]);
        setState(() {});
        final errorMessage = e.toString().contains('timeout')
            ? 'Koneksi timeout. Silakan coba lagi.'
            : e.toString().contains('internet')
                ? 'Tidak ada koneksi internet.'
                : 'Gagal memuat agenda. Silakan coba lagi.';
        MessageService.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  Future<void> _refreshBeritaDesa() async {
    try {
      _dataManager.setLoadingBerita(true);
      if (mounted) setState(() {});
      await _beritaDesaApiService.clearCache();
      await _loadBeritaDesa(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berita desa berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui berita desa: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _refreshLaporan() async {
    try {
      _dataManager.setLoadingLaporan(true);
      if (mounted) setState(() {});
      await _laporanApiService.clearCache();
      await _loadLaporan(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui laporan: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _refreshPengumuman() async {
    try {
      _dataManager.setLoadingPengumuman(true);
      if (mounted) setState(() {});
      await _pengumumanApiService.clearCache();
      await _loadPengumuman(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengumuman berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui pengumuman: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _refreshAgenda() async {
    try {
      _dataManager.setLoadingAgenda(true);
      if (mounted) setState(() {});
      await _agendaApiService.clearCache();
      await _loadAgenda(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agenda berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui agenda: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<int?> _getVillageId() async {
    if (_cachedVillageId != null) return _cachedVillageId;
    _startVillageIdPrefetch();
    final result = await _villageIdFuture;
    if (result != null) _cachedVillageId = result;
    return result;
  }

  void _startVillageIdPrefetch() {
    if (_cachedVillageId != null || _villageIdFuture != null) return;
    _villageIdFuture = _resolveVillageId();
  }

  Future<int?> _resolveVillageId() async {
    if (_cachedVillageId != null) return _cachedVillageId;
    if (_isLoadingVillageId) return _villageIdFuture;

    _isLoadingVillageId = true;
    try {
      final storage = AuthLocalStorage();
      final cached = await storage.getCachedVillageId();
      if (cached != null && cached > 0) {
        _cachedVillageId = cached;
        return cached;
      }

      final profileVillageId = await _fetchVillageIdFromProfile();
      if (profileVillageId != null && profileVillageId > 0) {
        await storage.cacheVillageId(profileVillageId);
        _cachedVillageId = profileVillageId;
        return profileVillageId;
      }

      final fallback = await _fetchVillageIdFromCitizens();
      if (fallback != null && fallback > 0) {
        await storage.cacheVillageId(fallback);
        _cachedVillageId = fallback;
      }
      return fallback;
    } finally {
      _isLoadingVillageId = false;
    }
  }

  Future<int?> _fetchVillageIdFromProfile() async {
    try {
      final repository = GetIt.instance<AuthRepository>();
      final profileResult = await repository.getUserProfile();
      return profileResult.fold(
        (_) => null,
        (data) => _extractVillageIdFromData(data),
      );
    } catch (e) {
      return null;
    }
  }

  Future<int?> _fetchVillageIdFromCitizens() async {
    try {
      String? nik = widget.penduduk.nik;
      if (nik.isEmpty) {
        final creds = await AuthLocalStorage().getUserCredentials();
        nik = creds?['nik']?.toString() ?? '';
      }
      if (nik.isEmpty) return null;

      final response = await http.get(
        Uri.parse('${AppConstants.goBaseUrl}/api/citizens/$nik'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          final data = responseData['data'];
          if (data is Map<String, dynamic>) {
            return _tryParseInt(data['village_id']);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  int? _extractVillageIdFromData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      final candidateKeys = [
        'village_id',
        'villageId',
        'villages_id',
        'desa_id',
        'desaId',
        'kelurahan_id',
        'kelurahanId',
      ];
      for (final key in candidateKeys) {
        if (!data.containsKey(key)) continue;
        final parsed = _tryParseInt(data[key]);
        if (parsed != null) return parsed;
      }

      for (final value in data.values) {
        if (value is Map<String, dynamic>) {
          final nested = _extractVillageIdFromData(value);
          if (nested != null) return nested;
        } else if (value is List) {
          for (final item in value) {
            final nested = _extractVillageIdFromData(item);
            if (nested != null) return nested;
          }
        }
      }
    } else if (data is List) {
      for (final item in data) {
        final nested = _extractVillageIdFromData(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Tanggal tidak valid';
    try {
      DateTime date;
      if (dateString.contains('T')) {
        final datePart = dateString.split('T')[0];
        final parts = datePart.split('-');
        if (parts.length == 3) {
          date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          date = DateTime.parse(dateString);
        }
      } else {
        date = DateTime.parse(dateString);
      }
      return DateFormat('dd MMMM yyyy').format(date);
    } catch (e) {
      return 'Tanggal tidak valid';
    }
  }

  String _stripHtml(String input) {
    if (input.isEmpty) return '';
    try {
      final noTags = input.replaceAll(RegExp(r'<[^>]*>'), ' ');
      return noTags
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('\n', ' ')
          .trim();
    } catch (_) {
      return input;
    }
  }

  String _buildImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return AppConstants.storageFileUrl(imagePath);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'diproses':
      case 'proses':
        return const Color(0xFFD97706);
      case 'selesai':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'ditolak':
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'pending':
      case 'menunggu':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'diproses':
      case 'proses':
        return const Color(0xFFFEF3C7);
      case 'selesai':
      case 'completed':
        return const Color(0xFFDCFCE7);
      case 'ditolak':
      case 'rejected':
        return const Color(0xFFFEE2E2);
      case 'pending':
      case 'menunggu':
        return const Color(0xFFE0F2FE);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase().trim()) {
      case 'diproses':
      case 'proses':
        return Icons.sync_rounded;
      case 'selesai':
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'ditolak':
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
      case 'menunggu':
        return Icons.schedule_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  bool _isDebouncing() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300) {
      return true;
    }
    _lastTapTime = now;
    return false;
  }

  // ==========================================
  // WIDGET HELPERS: EMPTY & LOADING STATES
  // ==========================================
  Widget _buildLoadingState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: BERITA DESA
  // ==========================================
  Widget _buildBeritaDesaTab() {
    final isLoading = _dataManager.isLoadingBerita ||
        (!_isInitialLoadComplete && _currentTabIndex == 0);
    final beritaList = _dataManager.beritaDesa;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Aksi Berita
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.newspaper_rounded,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kabar & Berita Desa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Informasi terkini seputar kegiatan dan perkembangan warga',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BeritaDesaFormPage()),
                      );
                      if (result == true) {
                        await _beritaDesaApiService.clearCache();
                        _loadBeritaDesa(forceRefresh: true);
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Tulis',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Berita',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (!isLoading && beritaList.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${beritaList.length} Berita',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content List
            if (isLoading)
              _buildLoadingState('Memuat kabar dan berita desa...')
            else if (beritaList.isEmpty)
              _buildEmptyState(
                icon: Icons.article_outlined,
                title: 'Belum Ada Berita',
                subtitle:
                    'Saat ini belum ada publikasi berita atau artikel terbaru dari desa.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: beritaList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildBeritaItem(beritaList[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeritaItem(BeritaDesaModel berita) {
    final imageUrl = _buildImageUrl(berita.gambar);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (_isDebouncing()) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BeritaDesaDetailPage(id: berita.id),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Header Berita
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 170,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 140,
                            width: double.infinity,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 36,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatDate(berita.createdAt.toString()),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Konten Teks Berita
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(berita.createdAt.toString()),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      berita.judul,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stripHtml(berita.deskripsi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Baca Selengkapnya',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: LAPOR DESA
  // ==========================================
  Widget _buildLaporDesaTab() {
    final isLoading = _dataManager.isLoadingLaporan ||
        (!_isInitialLoadComplete && _currentTabIndex == 1);
    final laporanList = _dataManager.laporan;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Ajakan Lapor
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Color(0xFF0284C7),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Layanan Aspirasi Warga',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Sampaikan pengaduan atau aspirasi Anda secara cepat dan tanggap',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LaporanFormPage()),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Lapor',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Laporan Desa',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (!isLoading && laporanList.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${laporanList.length} Laporan',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content List
            if (isLoading)
              _buildLoadingState('Memuat data laporan warga...')
            else if (laporanList.isEmpty)
              _buildEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum Ada Laporan',
                subtitle:
                    'Belum ada laporan atau aduan yang disampaikan oleh warga desa.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: laporanList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildLaporanItem(laporanList[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaporanItem(VillageReportModel laporan) {
    final hasImage = laporan.gambar.isNotEmpty;
    final statusColor = _getStatusColor(laporan.status);
    final statusBgColor = _getStatusBgColor(laporan.status);
    final statusIcon = _getStatusIcon(laporan.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LaporanDetailPage(report: laporan),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Image.network(
                    _buildImageUrl(laporan.gambar),
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 36,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatDate(laporan.createdAt.toString()),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                laporan.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      laporan.judulLaporan,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      laporan.deskripsiLaporan,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lihat Detail Laporan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: PENGUMUMAN
  // ==========================================
  Widget _buildPengumumanTab() {
    final isLoading = _dataManager.isLoadingPengumuman ||
        (!_isInitialLoadComplete && _currentTabIndex == 2);
    final pengumumanList = _dataManager.pengumuman;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Pengumuman
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFFD97706),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengumuman Resmi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Informasi penting dan maklumat resmi dari pemerintah desa',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Pengumuman',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (!isLoading && pengumumanList.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pengumumanList.length} Pengumuman',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content List
            if (isLoading)
              _buildLoadingState('Memuat pengumuman resmi desa...')
            else if (pengumumanList.isEmpty)
              _buildEmptyState(
                icon: Icons.campaign_outlined,
                title: 'Belum Ada Pengumuman',
                subtitle:
                    'Saat ini tidak ada pengumuman aktif dari pemerintah desa.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pengumumanList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildPengumumanItem(pengumumanList[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPengumumanItem(PengumumanModel pengumuman) {
    final hasImage = pengumuman.gambarUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PengumumanDetailPage(id: pengumuman.id),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Image.network(
                    pengumuman.gambarUrl,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 36,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD97706).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PENGUMUMAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(pengumuman.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _stripHtml(pengumuman.judul),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stripHtml(pengumuman.deskripsi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lihat Pengumuman Lengkap',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: AGENDA
  // ==========================================
  Widget _buildAgendaTab() {
    final isLoading = _dataManager.isLoadingAgenda ||
        (!_isInitialLoadComplete && _currentTabIndex == 3);
    final agendaList = _dataManager.agenda;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Agenda
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agenda Kegiatan Desa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Jadwal pertemuan, musyawarah, dan gotong royong warga desa',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jadwal Agenda',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (!isLoading && agendaList.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${agendaList.length} Agenda',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content List
            if (isLoading)
              _buildLoadingState('Memuat agenda kegiatan warga...')
            else if (agendaList.isEmpty)
              _buildEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'Belum Ada Agenda',
                subtitle:
                    'Saat ini belum ada jadwal agenda atau kegiatan terencana di desa.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: agendaList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _buildAgendaItem(agendaList[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaItem(AgendaModel agenda) {
    final hasImage = agenda.gambarUrl.isNotEmpty;
    final locationText =
        agenda.alamat.isNotEmpty ? agenda.alamat : agenda.tagLokasi;

    // Parse date for calendar badge
    String day = '';
    String month = '';
    try {
      DateTime dt = DateTime.parse(agenda.createdAt);
      day = DateFormat('dd').format(dt);
      month = DateFormat('MMM').format(dt).toUpperCase();
    } catch (_) {
      day = '--';
      month = 'TGL';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgendaDetailPage(id: agenda.id),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Image.network(
                    agenda.gambarUrl,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 36,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Calendar Badge
                        Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                month,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                day,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Judul & Deskripsi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stripHtml(agenda.judul),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _stripHtml(agenda.deskripsi),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            size: 15,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              locationText,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lihat Detail Agenda',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB MENU (CUSTOM MODERN PILL TAB)
  // ==========================================
  Widget _buildTabMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              icon: Icons.newspaper_rounded,
              label: 'Berita',
              index: 0,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              icon: Icons.assignment_rounded,
              label: 'Lapor',
              index: 1,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              icon: Icons.campaign_rounded,
              label: 'Pengumuman',
              index: 2,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              icon: Icons.event_rounded,
              label: 'Agenda',
              index: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentTabIndex == index;

    return GestureDetector(
      onTap: () => _tabController?.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Informasi Desa',
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
          actions: [
            IconButton(
              tooltip: 'Segarkan Data',
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              onPressed: () {
                switch (_currentTabIndex) {
                  case 0:
                    _refreshBeritaDesa();
                    break;
                  case 1:
                    _refreshLaporan();
                    break;
                  case 2:
                    _refreshPengumuman();
                    break;
                  case 3:
                    _refreshAgenda();
                    break;
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildTabMenu(),
            Expanded(
              child: _tabController != null
                  ? TabBarView(
                      controller: _tabController!,
                      children: [
                        RefreshIndicator(
                          onRefresh: _refreshBeritaDesa,
                          color: AppTheme.primaryColor,
                          child: _buildBeritaDesaTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshLaporan,
                          color: AppTheme.primaryColor,
                          child: _buildLaporDesaTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshPengumuman,
                          color: AppTheme.primaryColor,
                          child: _buildPengumumanTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshAgenda,
                          color: AppTheme.primaryColor,
                          child: _buildAgendaTab(),
                        ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: 2,
          items: [
            AppBottomNavBar.item(icon: Icons.home_outlined, label: 'Beranda'),
            AppBottomNavBar.item(icon: Icons.storefront, label: 'Warungku'),
            AppBottomNavBar.item(
                icon: Icons.grid_view_sharp, label: 'Informasi'),
            AppBottomNavBar.item(
                icon: Icons.account_balance_outlined, label: 'Profil Desa'),
            AppBottomNavBar.item(icon: Icons.receipt_long_outlined, label: 'Tagihan'),
            AppBottomNavBar.item(
                icon: Icons.description_outlined, label: 'Portal'),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BerandaPage(penduduk: widget.penduduk)),
                );
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => WarungkuPage(penduduk: widget.penduduk)),
                );
                break;
              case 2:
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ProfilDesaPage(penduduk: widget.penduduk)),
                );
                break;
              case 4:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TagihanPage(penduduk: widget.penduduk)),
                );
                break;
              case 5:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentServicesWebViewPage(
                          penduduk: widget.penduduk)),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}
