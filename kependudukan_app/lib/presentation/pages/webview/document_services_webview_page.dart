import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:get_it/get_it.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/presentation/pages/riwayat-surat/riwayat_surat_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';

class DocumentServicesWebViewPage extends StatefulWidget {
  final Penduduk? penduduk;
  const DocumentServicesWebViewPage({Key? key, this.penduduk})
      : super(key: key);

  @override
  State<DocumentServicesWebViewPage> createState() =>
      _DocumentServicesWebViewPageState();
}

class _DocumentServicesWebViewPageState
    extends State<DocumentServicesWebViewPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  Penduduk? _currentPenduduk;

  // Location IDs
  int? _provinceId;
  int? _districtId;
  int? _subDistrictId;
  int? _villageId;

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  @override
  void initState() {
    super.initState();
    _currentPenduduk = widget.penduduk;
    _loadUserData();
  }

  Penduduk? _getCurrentPenduduk() {
    // Prioritize _currentPenduduk if it's complete, otherwise use widget.penduduk
    if (_currentPenduduk != null &&
        _currentPenduduk!.nik.isNotEmpty &&
        _currentPenduduk!.token.isNotEmpty) {
      return _currentPenduduk;
    }

    // Fallback to widget.penduduk if it's complete
    if (widget.penduduk != null &&
        widget.penduduk!.nik.isNotEmpty &&
        widget.penduduk!.token.isNotEmpty) {
      return widget.penduduk;
    }

    return null;
  }

  Future<void> _loadUserData() async {
    try {
      // Prioritize data from widget first, then fallback to local storage
      if (widget.penduduk != null &&
          widget.penduduk!.nik.isNotEmpty &&
          widget.penduduk!.token.isNotEmpty) {
        // Use data from widget if it's complete
        _currentPenduduk = widget.penduduk;
        await _loadUserLocationData(widget.penduduk!.nik);
      } else {
        // Fallback to local storage if widget data is incomplete
        final authLocalStorage = GetIt.instance<AuthLocalStorage>();
        final userData = await authLocalStorage.getUserCredentials();

        if (userData == null) {
          setState(() {
            _errorMessage = 'User data not found. Please login again.';
          });
          return;
        }

        final nik = userData['nik'];
        if (nik == null || nik.toString().isEmpty) {
          setState(() {
            _errorMessage = 'NIK not found. Please login again.';
          });
          return;
        }

        // Create Penduduk object from stored data
        _currentPenduduk = Penduduk(
          nik: nik.toString(),
          name: userData['name']?.toString() ?? 'Penduduk',
          noHp: userData['no_hp']?.toString() ?? '',
          token: userData['token']?.toString() ?? '',
        );

        // Get user details including location data
        await _loadUserLocationData(nik.toString());
      }

      // Initialize WebView after data is loaded
      // Kalau ada error dari fetch citizen, jangan timpa dengan pesan generik.
      if (_errorMessage != null) return;

      // Validasi ID lokasi: harus ada dan > 0 (karena dipakai untuk membangun URL webview)
      final ok = (_provinceId ?? 0) > 0 &&
          (_districtId ?? 0) > 0 &&
          (_subDistrictId ?? 0) > 0 &&
          (_villageId ?? 0) > 0;

      if (ok) {
        _initializeWebView();
      } else {
        // ignore: avoid_print
        print(
            '[Portal] Location incomplete province=$_provinceId district=$_districtId subDistrict=$_subDistrictId village=$_villageId');
        setState(() {
          _errorMessage = 'Location data is incomplete. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    }
  }

  Future<void> _loadUserLocationData(String nik) async {
    try {
      // Optimasi: ambil detail 1 penduduk saja (bukan tarik /all-citizens).
      final response = await GetIt.instance<http.Client>().get(
        Uri.parse('${AppConstants.goBaseUrl}/api/citizens/$nik'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
            '[Portal] /api/citizens/$nik failed ${response.statusCode}: ${response.body}');
        setState(() {
          _errorMessage = 'Failed to fetch user data: ${response.statusCode}';
        });
        return;
      }

      final dynamic responseData = json.decode(response.body);
      final citizen = (responseData is Map<String, dynamic>)
          ? (responseData['data'] as Map<String, dynamic>?)
          : null;
      if (citizen == null) {
        // ignore: avoid_print
        print('[Portal] invalid citizen payload: ${response.body}');
        setState(() {
          _errorMessage = 'Format data penduduk tidak valid';
        });
        return;
      }

      setState(() {
        _provinceId = _toInt(citizen['province_id']);
        _districtId = _toInt(citizen['district_id']);
        _subDistrictId = _toInt(citizen['sub_district_id']);
        _villageId = _toInt(citizen['village_id']);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching user location data: $e';
      });
    }
  }

  void _initializeWebView() {
    // Build the URL with location IDs
    final url =
        'https://pelayanan.desaverse.id/pelayanan/list/$_provinceId/$_districtId/$_subDistrictId/$_villageId';

    // Create WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar
            if (progress < 100) {
              setState(() {
                _isLoading = true;
              });
            } else {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _errorMessage = 'Error loading page: ${error.description}';
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Layanan Surat',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RiwayatSuratPage(),
                ),
              );
            },
            tooltip: 'Riwayat Surat',
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _loadUserData();
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 5, // Portal Layanan Desa
        items: [
          AppBottomNavBar.item(icon: Icons.home_outlined, label: 'Beranda'),
          AppBottomNavBar.item(icon: Icons.storefront, label: 'Warungku'),
          AppBottomNavBar.item(
              icon: Icons.grid_view_outlined, label: 'Informasi'),
          AppBottomNavBar.item(
              icon: Icons.account_balance_outlined, label: 'Profil Desa'),
          AppBottomNavBar.item(icon: Icons.receipt_long_outlined, label: 'Tagihan'),
          AppBottomNavBar.item(icon: Icons.description, label: 'Portal'),
        ],
        onTap: (index) {
          // Get penduduk data from widget
          final penduduk = _getCurrentPenduduk();

          if (penduduk == null ||
              penduduk.nik.isEmpty ||
              penduduk.token.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Data penduduk tidak lengkap. Silakan login ulang.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BerandaPage(penduduk: penduduk),
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => WarungkuPage(penduduk: penduduk),
                ),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PendudukHomePage(
                    penduduk: penduduk,
                    initialTabIndex: 0, // Berita Desa tab
                  ),
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilDesaPage(penduduk: penduduk),
                ),
              );
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TagihanPage(penduduk: penduduk),
                ),
              );
              break;
            case 5:
              // Current page - Portal Layanan Desa
              break;
          }
        },
      ),
    );
  }
}
