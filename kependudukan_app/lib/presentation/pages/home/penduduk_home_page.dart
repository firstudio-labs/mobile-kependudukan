import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/asset/asset_list_page.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/pages/domisili/domisili_map_page.dart';
import 'package:ladimas/presentation/pages/family/family_list_page.dart';
import 'package:ladimas/presentation/pages/profile/profile_details_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/berita-desa/berita_desa_form_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'package:intl/intl.dart';
import 'package:ladimas/data/datasources/pengumuman_api_service.dart';
import 'package:ladimas/data/models/pengumuman_model.dart';
import 'package:ladimas/presentation/pages/pengumuman/pengumuman_detail_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
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
  bool _isProcessingNavigation = false;
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

  // Flag untuk menandai apakah initial load sudah selesai (untuk menghindari tampilan "belum ada data" saat awal)
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Validate penduduk data
    if (widget.penduduk.nik.isEmpty || widget.penduduk.token.isEmpty) {
      // Show error and return to login if data is invalid
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

    // Set initial tab index, default to 0 (Berita Desa)
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
        // Lazy load data untuk tab yang baru dipilih jika belum ada
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

    // Selalu coba refresh data saat aplikasi pertama kali dibuka
    // Ini memastikan data selalu up-to-date
    _dataManager.resetLoadingStates();

    // Kick off villageId fetch lebih awal agar bisa berjalan paralel dengan load data
    _startVillageIdPrefetch();

    // Pre-load villageId dan data (Gunakan Cache-First strategy)
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

    // Refresh data saat aplikasi kembali dari background
    if (state == AppLifecycleState.resumed && _isInitialLoadComplete) {
      print('📱 PendudukHome - App resumed, checking for data updates');
      _checkForUpdatesInBackground();
    }
  }

  Future<void> _preloadVillageIdAndData() async {
    print('🚀 PendudukHome - Starting preload village ID and data');

    // Tampilkan data yang ada di memory segera jika masih fresh
    if (_dataManager.isDataFresh && _dataManager.hasLoadedData) {
      print('✅ PendudukHome - Data is fresh, showing cached data first');
      _isInitialLoadComplete = true;
      if (mounted) setState(() {});
      
      // Tetap cek update di background tanpa blocking
      _checkForUpdatesInBackground();
      return;
    }

    // Jika tidak fresh di memory, load data (ApiService akan cek persistent storage dulu secara otomatis)
    // JANGAN CLEAR CACHE DI SINI karena itu akan menghapus data lari persistent storage.
    
    // Mulai fetch villageId secara paralel
    _startVillageIdPrefetch();

    // Tentukan apakah data untuk tab aktif sudah ada (biar tidak loading spinner kalau sudah ada di memory)
    bool hasDataForCurrentTab = false;
    switch (_currentTabIndex) {
      case 0: hasDataForCurrentTab = _dataManager.beritaDesa.isNotEmpty; break;
      case 1: hasDataForCurrentTab = _dataManager.laporan.isNotEmpty; break;
      case 2: hasDataForCurrentTab = _dataManager.pengumuman.isNotEmpty; break;
      case 3: hasDataForCurrentTab = _dataManager.agenda.isNotEmpty; break;
    }

    // Hanya set loading jika benar-benar tidak ada data
    if (!hasDataForCurrentTab) {
      switch (_currentTabIndex) {
        case 0: _dataManager.setLoadingBerita(true); break;
        case 1: _dataManager.setLoadingLaporan(true); break;
        case 2: _dataManager.setLoadingPengumuman(true); break;
        case 3: _dataManager.setLoadingAgenda(true); break;
      }
      if (mounted) setState(() {});
    }

    try {
      // Load data untuk tab aktif (ApiService akan ambil dari storage duku jika ada)
      switch (_currentTabIndex) {
        case 0: await _loadBeritaDesa(); break;
        case 1: await _loadLaporan(); break;
        case 2: await _loadPengumuman(); break;
        case 3: await _loadAgenda(); break;
      }

      // Tandai initial load selesai agar UI terupdate
      _isInitialLoadComplete = true;
      if (mounted) setState(() {});

      // Load tab lainnya dan cek update di background secara paralel
      _loadOtherTabsDataInBackground();
      
      // Update status data manager
      _dataManager.markDataAsLoaded();
    } catch (e) {
      print('❌ PendudukHome - Error in preload: $e');
      _isInitialLoadComplete = true;
      _dataManager.resetLoadingStates();
      if (mounted) setState(() {});
    }
  }

  // Load data untuk tab lainnya di background
  Future<void> _loadOtherTabsDataInBackground() async {
    _startVillageIdPrefetch();
    final futures = <Future>[];

    if (_currentTabIndex != 0) {
      futures.add(_loadBeritaDesa());
    }
    if (_currentTabIndex != 1) {
      futures.add(_loadLaporan());
    }
    if (_currentTabIndex != 2) {
      futures.add(_loadPengumuman());
    }
    if (_currentTabIndex != 3) {
      futures.add(_loadAgenda());
    }

    // Load di background tanpa blocking
    if (futures.isNotEmpty) {
      Future.wait(futures).then((_) {
        // Data loaded successfully
      }).catchError((e) {
        print('Error loading background data: $e');
      });
    }
  }

  Future<void> _checkForUpdatesInBackground() async {
    print('🔄 PendudukHome - Checking for updates in background');

    try {
      // Load update di background tanpa menghapus cache terlebih dahulu.
      // Jika data baru tersedia, ApiService akan mengupdate cache secara atomik.
      final futures = [
        _loadBeritaDesa(forceRefresh: true),
        _loadLaporan(forceRefresh: true),
        _loadPengumuman(forceRefresh: true),
        _loadAgenda(forceRefresh: true),
      ];

      await Future.wait(futures);

      // Update timestamp setelah berhasil
      _dataManager.markDataAsLoaded();
      
      if (mounted) {
        setState(() {});
      }
      print('✅ PendudukHome - Background update completed');
    } catch (e) {
      print('❌ PendudukHome - Error in background update: $e');
    }
  }

  // Load data untuk tab tertentu (untuk lazy loading saat user switch tab)
  Future<void> _loadDataForTab(int tabIndex) async {
    // Cek apakah data untuk tab ini sudah ada
    bool needsLoad = false;

    switch (tabIndex) {
      case 0: // Berita Desa
        if (_dataManager.beritaDesa.isEmpty && !_dataManager.isLoadingBerita) {
          needsLoad = true;
          _dataManager.setLoadingBerita(true);
        }
        break;
      case 1: // Lapor Desa
        if (_dataManager.laporan.isEmpty && !_dataManager.isLoadingLaporan) {
          needsLoad = true;
          _dataManager.setLoadingLaporan(true);
        }
        break;
      case 2: // Pengumuman
        if (_dataManager.pengumuman.isEmpty &&
            !_dataManager.isLoadingPengumuman) {
          needsLoad = true;
          _dataManager.setLoadingPengumuman(true);
        }
        break;
      case 3: // Agenda
        if (_dataManager.agenda.isEmpty && !_dataManager.isLoadingAgenda) {
          needsLoad = true;
          _dataManager.setLoadingAgenda(true);
        }
        break;
    }

    if (needsLoad && mounted) {
      setState(() {});

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
      } catch (e) {
        print('Error loading data for tab $tabIndex: $e');
      }
    }
  }

  // Method untuk load data hanya jika diperlukan (untuk refresh)
  Future<void> _loadDataIfNeeded() async {
    await _preloadVillageIdAndData();
  }

  Future<void> _loadPengumuman({bool forceRefresh = false}) async {
    if (!mounted) return;

    print(
        '🔵 PendudukHome - Starting _loadPengumuman, forceRefresh: $forceRefresh');

    // Jika data sudah ada dan tidak force refresh, langsung return
    if (!forceRefresh &&
        _dataManager.pengumuman.isNotEmpty &&
        _dataManager.isDataFresh) {
      print('✅ PendudukHome - Pengumuman data is fresh, skipping load');
      return;
    }

    try {
      // Hanya set loading state jika force refresh atau belum ada data
      if (forceRefresh || _dataManager.pengumuman.isEmpty) {
        if (mounted) {
          print('🔄 PendudukHome - Setting loading state for pengumuman');
          _dataManager.setLoadingPengumuman(true);
          
          if (forceRefresh) {
            await _pengumumanApiService.clearCache();
            _dataManager.setPengumuman([]);
          }
          setState(() {});
        }
      }

      print('📡 PendudukHome - Calling getPengumumanList');
      // Optimasi: gunakan timeout yang lebih pendek, cache sudah handle di service
      final items = await _pengumumanApiService.getPengumumanList().timeout(
        const Duration(seconds: 15), // Kurangi dari default 30 detik
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Silakan coba lagi.');
        },
      );

      print('✅ PendudukHome - Pengumuman Count: ${items.length}');
      if (items.isNotEmpty) {
        for (var p in items) {
          print('📄 PendudukHome - Pengumuman: ${p.judul} (ID: ${p.id})');
        }
      } else {
        print('⚠️ PendudukHome - No pengumuman data returned');
      }

      if (mounted) {
        _dataManager.setPengumuman(items);
        _dataManager.setLoadingPengumuman(false);
        print('🔄 PendudukHome - Pengumuman data loaded, updating UI');
        setState(() {});
      }
    } on TimeoutException catch (e) {
      print(
          '❌ PendudukHome - TimeoutException loading pengumuman: ${e.message}');
      if (mounted) {
        _dataManager.setLoadingPengumuman(false);
        if (forceRefresh) {
          _dataManager.setPengumuman([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(
            context, e.message ?? 'Koneksi timeout');
      }
    } on AuthException catch (e) {
      print('❌ PendudukHome - AuthException loading pengumuman: ${e.message}');
      if (mounted) {
        _dataManager.setLoadingPengumuman(false);
        if (forceRefresh) {
          _dataManager.setPengumuman([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(context, e.message);
      }
    } on ServerException catch (e) {
      print(
          '❌ PendudukHome - ServerException loading pengumuman: ${e.message}');
      if (mounted) {
        _dataManager.setLoadingPengumuman(false);
        if (forceRefresh) {
          _dataManager.setPengumuman([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(context, e.message);
      }
    } catch (e) {
      print('❌ PendudukHome - Exception loading pengumuman: $e');
      if (mounted) {
        _dataManager.setLoadingPengumuman(false);
        if (forceRefresh) {
          _dataManager.setPengumuman([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(
          context,
          'Gagal memuat pengumuman: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _loadBeritaDesa({bool forceRefresh = false}) async {
    if (!mounted) return;

    print(
        '🔵 PendudukHome - Starting _loadBeritaDesa, forceRefresh: $forceRefresh');

    // Jika data sudah ada dan tidak force refresh, langsung return
    if (!forceRefresh &&
        _dataManager.beritaDesa.isNotEmpty &&
        _dataManager.isDataFresh) {
      print('✅ PendudukHome - Berita data is fresh, skipping load');
      return;
    }

    try {
      // Hanya set loading state jika force refresh atau belum ada data
      if (forceRefresh || _dataManager.beritaDesa.isEmpty) {
        if (mounted) {
          print('🔄 PendudukHome - Setting loading state for berita desa');
          _dataManager.setLoadingBerita(true);
          if (forceRefresh) {
            _dataManager.setBeritaDesa([]);
          }
          setState(() {});
        }
      }

      // Force refresh harus bypass cache service berita.
      if (forceRefresh) {
        await _beritaDesaApiService.clearCache();
      }

      // Gunakan cached villageId jika sudah ada, jika tidak baru fetch
      final int? villageId = _cachedVillageId ?? await _getVillageId();
      print(
          '🏘️ PendudukHome - Village ID: $villageId (cached: ${_cachedVillageId != null})');

      // Jika village_id null atau 0, coba load semua data tanpa filter
      print(
          '📡 PendudukHome - Calling getBeritaDesa with villageId: $villageId');
      final berita = await _beritaDesaApiService.getBeritaDesa(
        villageId: (villageId != null && villageId > 0) ? villageId : null,
      );

      print('✅ PendudukHome - Berita Count: ${berita.length}');
      if (berita.isNotEmpty) {
        for (var b in berita) {
          print(
              '📄 PendudukHome - Berita: ${b.judul} (ID: ${b.id}, Village: ${b.villageId})');
        }
      } else {
        print('⚠️ PendudukHome - No berita data returned');
      }

      if (mounted) {
        _dataManager.setBeritaDesa(berita);
        _dataManager.setLoadingBerita(false);
        print('🔄 PendudukHome - Berita data loaded, updating UI');
        setState(() {});
      }
    } on AuthException catch (e) {
      print('❌ PendudukHome - AuthException loading berita: ${e.message}');
      if (mounted) {
        _dataManager.setLoadingBerita(false);
        if (forceRefresh) {
          _dataManager.setBeritaDesa([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(context, e.message);
      }
    } on ServerException catch (e) {
      print('❌ PendudukHome - ServerException loading berita: ${e.message}');
      if (mounted) {
        _dataManager.setLoadingBerita(false);
        if (forceRefresh) {
          _dataManager.setBeritaDesa([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(context, e.message);
      }
    } catch (e) {
      print('❌ PendudukHome - Exception loading berita: $e');
      if (mounted) {
        _dataManager.setLoadingBerita(false);
        if (forceRefresh) {
          _dataManager.setBeritaDesa([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(
          context,
          'Gagal memuat berita desa: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _loadLaporan({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Jika data sudah ada dan tidak force refresh, langsung return
    if (!forceRefresh &&
        _dataManager.laporan.isNotEmpty &&
        _dataManager.isDataFresh) {
      return;
    }

    try {
      // Hanya set loading state jika force refresh atau belum ada data
      if (forceRefresh || _dataManager.laporan.isEmpty) {
        if (mounted) {
          _dataManager.setLoadingLaporan(true);
          if (forceRefresh) {
            _dataManager.setLaporan([]);
          }
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
        if (forceRefresh) {
          _dataManager.setLaporan([]);
        }
        setState(() {});
        MessageService.showErrorSnackBar(
          context,
          'Gagal memuat laporan: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _loadAgenda({bool forceRefresh = false}) async {
    if (!mounted) return;

    print(
        '🔵 PendudukHome - Starting _loadAgenda, forceRefresh: $forceRefresh');

    // Jika data sudah ada dan tidak force refresh, langsung return
    if (!forceRefresh &&
        _dataManager.agenda.isNotEmpty &&
        _dataManager.isDataFresh) {
      print('✅ PendudukHome - Agenda data is fresh, skipping load');
      return;
    }

    try {
      // Hanya set loading state jika force refresh atau belum ada data
      if (forceRefresh || _dataManager.agenda.isEmpty) {
        if (mounted) {
          print('🔄 PendudukHome - Setting loading state for agenda');
          _dataManager.setLoadingAgenda(true);
          if (forceRefresh) {
            _dataManager.setAgenda([]);
          }
          setState(() {});
        }
      }

      // Gunakan cached villageId jika sudah ada, jika tidak baru fetch
      final villageId = _cachedVillageId ?? await _getVillageId();
      print(
          '🏘️ PendudukHome - Agenda Village ID: $villageId (cached: ${_cachedVillageId != null})');

      print(
          '📡 PendudukHome - Calling getAgenda with villageId: $villageId (forceRefresh: $forceRefresh)');
      // Jika village_id null atau 0, coba load semua data tanpa filter
      final agenda = await _agendaApiService.getAgenda(
          villageId: (villageId != null && villageId > 0) ? villageId : null,
          forceRefresh: forceRefresh);

      print('✅ PendudukHome - Agenda Count: ${agenda.length}');
      if (agenda.isNotEmpty) {
        for (var a in agenda) {
          print(
              '📅 PendudukHome - Agenda: ${a.judul} (ID: ${a.id}, Village: ${a.villagesId})');
        }
      } else {
        print('⚠️ PendudukHome - No agenda data returned');
      }

      if (mounted) {
        _dataManager.setAgenda(agenda);
        _dataManager.setLoadingAgenda(false);
        print('🔄 PendudukHome - Agenda data loaded, updating UI');
        setState(() {});
      }
    } catch (e) {
      print('❌ PendudukHome - Exception loading agenda: $e');
      if (mounted) {
        _dataManager.setLoadingAgenda(false);
        if (forceRefresh) {
          _dataManager.setAgenda([]);
        }
        setState(() {});
        // Show user-friendly error message
        final errorMessage = e.toString().contains('timeout')
            ? 'Koneksi timeout. Silakan coba lagi.'
            : e.toString().contains('internet')
                ? 'Tidak ada koneksi internet.'
                : 'Gagal memuat agenda. Silakan coba lagi.';
        MessageService.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  // Method untuk refresh individual tab
  Future<void> _refreshBeritaDesa() async {
    try {
      // Set loading state untuk berita desa tanpa menghapus data lama
      _dataManager.setLoadingBerita(true);
      if (mounted) setState(() {});

      // Clear cache untuk memastikan data fresh
      print('PendudukHome - Refreshing Berita Desa...');
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
      print('PendudukHome - Error refreshing Berita Desa: $e');
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
      // Set loading state untuk laporan tanpa menghapus data lama
      _dataManager.setLoadingLaporan(true);
      if (mounted) setState(() {});

      // Clear cache untuk memastikan data fresh
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
      // Set loading state untuk pengumuman tanpa menghapus data lama
      _dataManager.setLoadingPengumuman(true);
      if (mounted) setState(() {});

      // Clear cache untuk memastikan data fresh
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
      // Set loading state untuk agenda tanpa menghapus data lama
      _dataManager.setLoadingAgenda(true);
      if (mounted) setState(() {});

      // Clear cache untuk memastikan data fresh
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
    print('🏘️ PendudukHome - Getting village ID, cached: $_cachedVillageId');
    if (_cachedVillageId != null) {
      print('✅ PendudukHome - Using cached village ID: $_cachedVillageId');
      return _cachedVillageId;
    }

    _startVillageIdPrefetch();
    final result = await _villageIdFuture;
    if (result != null) {
      _cachedVillageId = result;
      print('✅ PendudukHome - Resolved village ID: $result');
    } else {
      print('❌ PendudukHome - Failed to resolve village ID');
    }
    return result;
  }

  void _startVillageIdPrefetch() {
    if (_cachedVillageId != null || _villageIdFuture != null) return;
    _villageIdFuture = _resolveVillageId();
  }

  Future<int?> _resolveVillageId() async {
    print('🔍 PendudukHome - Starting village ID resolution');
    if (_cachedVillageId != null) {
      print(
          '✅ PendudukHome - Already have cached village ID: $_cachedVillageId');
      return _cachedVillageId;
    }
    if (_isLoadingVillageId) {
      print('⏳ PendudukHome - Village ID resolution already in progress');
      return _villageIdFuture;
    }

    _isLoadingVillageId = true;
    print('🔄 PendudukHome - Starting village ID resolution process');
    try {
      final storage = AuthLocalStorage();

      print('💾 PendudukHome - Checking cached village ID from storage');
      final cached = await storage.getCachedVillageId();
      if (cached != null && cached > 0) {
        _cachedVillageId = cached;
        print('✅ PendudukHome - Found cached village ID: $cached');
        return cached;
      }
      print('❌ PendudukHome - No cached village ID found');

      print('👤 PendudukHome - Trying to fetch village ID from profile');
      final profileVillageId = await _fetchVillageIdFromProfile();
      if (profileVillageId != null && profileVillageId > 0) {
        await storage.cacheVillageId(profileVillageId);
        _cachedVillageId = profileVillageId;
        print(
            '✅ PendudukHome - Got village ID from profile: $profileVillageId');
        return profileVillageId;
      }
      print('❌ PendudukHome - Failed to get village ID from profile');

      print('👥 PendudukHome - Falling back to citizens endpoint');
      final fallback = await _fetchVillageIdFromCitizens();
      if (fallback != null && fallback > 0) {
        await storage.cacheVillageId(fallback);
        _cachedVillageId = fallback;
        print('✅ PendudukHome - Got village ID from citizens: $fallback');
      } else {
        print('❌ PendudukHome - Failed to get village ID from citizens');
      }
      return fallback;
    } finally {
      _isLoadingVillageId = false;
      print('🏁 PendudukHome - Village ID resolution completed');
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
      print('PendudukHome - Failed to fetch villageId from profile: $e');
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
      if (nik.isEmpty) {
        print('PendudukHome - NIK is empty');
        return null;
      }

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
      } else {
        print(
            'PendudukHome - Error getting village ID: ${response.statusCode}');
      }
    } catch (e) {
      print('PendudukHome - Exception in _fetchVillageIdFromCitizens: $e');
    }
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

      // Handle ISO format with time
      if (dateString.contains('T')) {
        // Extract date part from ISO format: 2025-09-09T02:50:50.000000Z -> 2025-09-09
        final datePart = dateString.split('T')[0];
        final parts = datePart.split('-');

        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          date = DateTime(year, month, day);
        } else {
          date = DateTime.parse(dateString);
        }
      } else {
        date = DateTime.parse(dateString);
      }

      return DateFormat('dd MMMM yyyy').format(date);
    } catch (e) {
      // Try alternative parsing methods
      try {
        if (dateString.contains('T')) {
          final datePart = dateString.split('T')[0];
          final parts = datePart.split('-');
          if (parts.length == 3) {
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final day = int.parse(parts[2]);
            final date = DateTime(year, month, day);
            return DateFormat('dd MMMM yyyy').format(date);
          }
        }
      } catch (e2) {
        // Fallback to original string if all parsing fails
      }

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

    // If the path already starts with http/https, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Gunakan helper terpusat agar konsisten (pakai STORAGE_URL kalau diset).
    return AppConstants.storageFileUrl(imagePath);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'diproses':
      case 'proses':
        return Colors.orange;
      case 'selesai':
      case 'completed':
        return Colors.green;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'pending':
      case 'menunggu':
        return Colors.blue;
      default:
        return Colors.grey;
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

  Future<void> _getPendudukDetailAndNavigate({
    required Function(String kk) onSuccess,
    required String errorPrefix,
    required String emptyKkMessage,
  }) async {
    if (_isProcessingNavigation || _isDebouncing()) return;

    setState(() => _isProcessingNavigation = true);

    try {
      final repository = GetIt.instance<AuthRepository>();
      final result = await repository.getPendudukDetail(widget.penduduk.nik);

      if (!mounted) {
        setState(() => _isProcessingNavigation = false);
        return;
      }

      result.fold(
        (failure) {
          MessageService.showErrorSnackBar(
              context, '$errorPrefix ${failure.message}');
          setState(() => _isProcessingNavigation = false);
        },
        (data) {
          final kk = data['kk']?.toString() ?? '';
          if (kk.isNotEmpty) {
            onSuccess(kk);
          } else {
            MessageService.showInfoSnackBar(context, emptyKkMessage);
            setState(() => _isProcessingNavigation = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, 'Error: ${e.toString()}');
        setState(() => _isProcessingNavigation = false);
      }
    }
  }

  Future<void> _navigateToFamilyPage() async {
    if (_isProcessingNavigation || _isDebouncing()) return;

    setState(() => _isProcessingNavigation = true);

    try {
      // Langsung navigasi ke halaman keluarga
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FamilyListPage(
            kk: '', // Akan diisi nanti
            nikPenduduk: widget.penduduk.nik,
          ),
        ),
      );

      // Reset state setelah navigasi
      if (mounted) {
        setState(() => _isProcessingNavigation = false);
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, 'Error: ${e.toString()}');
        setState(() => _isProcessingNavigation = false);
      }
    }
  }

  Future<void> _navigateToDomisiliPage() async {
    if (_isProcessingNavigation || _isDebouncing()) return;

    setState(() => _isProcessingNavigation = true);

    try {
      // Langsung navigasi ke halaman domisili
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DomisiliMapPage(
            nik: widget.penduduk.nik,
            kk: '', // Akan diisi nanti
          ),
        ),
      );

      // Reset state setelah navigasi
      if (mounted) {
        setState(() => _isProcessingNavigation = false);
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, 'Error: ${e.toString()}');
        setState(() => _isProcessingNavigation = false);
      }
    }
  }

  Future<void> _navigateToPage(Widget page) async {
    if (_isProcessingNavigation) return;
    setState(() => _isProcessingNavigation = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isProcessingNavigation = false);
    }
  }

  Future<void> _navigateToProfilePage() async {
    await _navigateToPage(ProfileDetailsPage(nik: widget.penduduk.nik));
  }

  Future<void> _navigateToAssetPage() async {
    await _navigateToPage(const AssetListPage());
  }

  Widget _buildBeritaDesaTab() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9E9E9E).withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Berita Desa',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BeritaDesaFormPage()),
                          );
                          if (result == true) {
                            // IMPORTANT: form page meng-clear cache pada instance service-nya sendiri.
                            // Instance service di halaman ini masih bisa menyimpan cache in-memory lama,
                            // jadi kita clear juga sebelum reload agar berita terbaru muncul.
                            await _beritaDesaApiService.clearCache();
                            _loadBeritaDesa(forceRefresh: true);
                          }
                        },
                        icon: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Buat Berita',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A47DC),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dataManager.isLoadingBerita ||
                          (!_isInitialLoadComplete && _currentTabIndex == 0)
                      ? const Center(child: CircularProgressIndicator())
                      : _dataManager.beritaDesa.isEmpty
                          ? const Center(
                              child: Text('Belum ada berita desa'),
                            )
                          : Column(
                              children: _dataManager.beritaDesa
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final berita = entry.value;
                                final isLast =
                                    index == _dataManager.beritaDesa.length - 1;
                                return _buildBeritaItem(berita, isLast: isLast);
                              }).toList(),
                            ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeritaItem(BeritaDesaModel berita, {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
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
            if (berita.gambarUrl.isNotEmpty)
              Image.network(
                berita.gambarUrl,
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        berita.judul,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDate(berita.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    color: Colors.grey.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stripHtml(berita.deskripsi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaporDesaTab() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9E9E9E).withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lapor Desa',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LaporanFormPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Buat Laporan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A47DC),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dataManager.isLoadingLaporan ||
                          (!_isInitialLoadComplete && _currentTabIndex == 1)
                      ? const Center(child: CircularProgressIndicator())
                      : _dataManager.laporan.isEmpty
                          ? const Center(
                              child: Text('Belum ada laporan'),
                            )
                          : Column(
                              children: _dataManager.laporan
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final laporan = entry.value;
                                final isLast =
                                    index == _dataManager.laporan.length - 1;
                                return _buildLaporanItem(laporan,
                                    isLast: isLast);
                              }).toList(),
                            ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaporanItem(VillageReportModel laporan, {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
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
            if (laporan.gambar.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  _buildImageUrl(laporan.gambar),
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 50,
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        laporan.judulLaporan,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDate(laporan.createdAt.toString()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    color: Colors.grey.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    laporan.deskripsiLaporan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(laporan.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      laporan.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(laporan.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPengumumanTab() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9E9E9E).withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pengumuman',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _dataManager.isLoadingPengumuman ||
                          (!_isInitialLoadComplete && _currentTabIndex == 2)
                      ? const Center(child: CircularProgressIndicator())
                      : _dataManager.pengumuman.isEmpty
                          ? const Center(
                              child: Text('Belum ada pengumuman'),
                            )
                          : Column(
                              children: _dataManager.pengumuman
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final pengumuman = entry.value;
                                final isLast =
                                    index == _dataManager.pengumuman.length - 1;
                                return _buildPengumumanItem(pengumuman,
                                    isLast: isLast);
                              }).toList(),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaTab() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9E9E9E).withOpacity(0.15),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agenda',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _dataManager.isLoadingAgenda ||
                          (!_isInitialLoadComplete && _currentTabIndex == 3)
                      ? const Center(child: CircularProgressIndicator())
                      : _dataManager.agenda.isEmpty
                          ? const Center(
                              child: Text('Belum ada agenda'),
                            )
                          : Column(
                              children: _dataManager.agenda
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final agenda = entry.value;
                                final isLast =
                                    index == _dataManager.agenda.length - 1;
                                return _buildAgendaItem(agenda, isLast: isLast);
                              }).toList(),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaItem(AgendaModel agenda, {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
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
            if (agenda.gambarUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  agenda.gambarUrl,
                  width: double.infinity,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.campaign,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.campaign,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stripHtml(agenda.judul),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDate(agenda.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    color: Colors.grey.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stripHtml(agenda.deskripsi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          agenda.alamat.isNotEmpty
                              ? agenda.alamat
                              : agenda.tagLokasi,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPengumumanItem(PengumumanModel pengumuman,
      {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
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
            if (pengumuman.gambarUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  pengumuman.gambarUrl,
                  width: double.infinity,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.campaign,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.campaign,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stripHtml(pengumuman.judul),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDate(pengumuman.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    color: Colors.grey.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stripHtml(pengumuman.deskripsi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFFF5F6FA)),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          children: [
            Text(
              'Informasi Desa',
              style: TextStyle(
                color: Color(0xFF4A47DC),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              icon: Icons.newspaper,
              label: 'Berita Desa',
              index: 0,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              icon: Icons.assignment,
              label: 'Lapor Desa',
              index: 1,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              icon: Icons.campaign,
              label: 'Pengumuman',
              index: 2,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabItem(
              icon: Icons.event,
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
    final color = isActive ? const Color(0xFF4A47DC) : Colors.grey[600]!;
    final fontWeight = isActive ? FontWeight.w600 : FontWeight.w500;

    return GestureDetector(
      onTap: () => _tabController?.animateTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: fontWeight,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
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
          foregroundColor: const Color(0xFF4A47DC),
          elevation: 0,
          backgroundColor: const Color(0xFFF5F6FA),
          automaticallyImplyLeading: false,
        ),
        backgroundColor: const Color(0xFFF5F6FA),
        body: Column(
          children: [
            // Header Section
            _buildHeaderSection(),

            // Tab Menu
            _buildTabMenu(),

            // Tab Content
            Expanded(
              child: _tabController != null
                  ? TabBarView(
                      controller: _tabController!,
                      children: [
                        RefreshIndicator(
                          onRefresh: _refreshBeritaDesa,
                          color: const Color(0xFF4A47DC),
                          child: _buildBeritaDesaTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshLaporan,
                          color: const Color(0xFF4A47DC),
                          child: _buildLaporDesaTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshPengumuman,
                          color: const Color(0xFF4A47DC),
                          child: _buildPengumumanTab(),
                        ),
                        RefreshIndicator(
                          onRefresh: _refreshAgenda,
                          color: const Color(0xFF4A47DC),
                          child: _buildAgendaTab(),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: const Color(0xFF4A47DC),
          unselectedItemColor: Colors.grey,
          currentIndex: 2, // Halaman Informasi
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 28), label: 'Beranda'),
            BottomNavigationBarItem(
                icon: Icon(Icons.storefront_sharp, size: 28),
                label: 'Warungku'),
            BottomNavigationBarItem(
                icon: Icon(Icons.apps, size: 28), label: 'Informasi'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance, size: 28),
                label: 'Profil Desa'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long, size: 28), label: 'Tagihan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.description, size: 28), label: 'Portal'),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BerandaPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WarungkuPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 2:
                // Current page - Informasi
                break;
              case 3:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilDesaPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 4:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TagihanPage(penduduk: widget.penduduk),
                  ),
                );
                break;
              case 5:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DocumentServicesWebViewPage(penduduk: widget.penduduk),
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }
}
