import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';

import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';

import 'package:ladimas/presentation/pages/asset/asset_list_page.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_beranda_page.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/domisili/domisili_map_page.dart';
import 'package:ladimas/presentation/pages/family/family_list_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/presentation/pages/profile/biodata_edit_page.dart';
import 'package:ladimas/presentation/pages/profile/profile_details_page.dart';
import 'package:ladimas/presentation/pages/profile/profile_edit_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';

class DatakuPage extends StatefulWidget {
  final Penduduk penduduk;

  const DatakuPage({
    Key? key,
    required this.penduduk,
  }) : super(key: key);

  @override
  State<DatakuPage> createState() => _DatakuPageState();
}

class _DatakuPageState extends State<DatakuPage> {
  bool _isProcessingNavigation = false;
  DateTime? _lastTapTime;
  bool _isLoading = false;

  Map<String, dynamic>? _biodata;
  Map<String, dynamic>? _informasiUsaha;
  Map<String, dynamic>? _user;
  String? _fotoDiriUrl;

  int _selectedCategoryIndex = 0;

  bool _isDebouncing() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500) {
      return true;
    }
    _lastTapTime = now;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Jalankan request biodata & dokumen (foto diri) secara paralel
      await Future.wait([
        _loadBiodataFromApi(),
        _loadFotoDiriFromApi(),
      ]);

      if (_biodata == null || _biodata!.isEmpty) {
        final repository = GetIt.instance<AuthRepository>();
        final result = await repository.getPendudukDetail(widget.penduduk.nik);
        result.fold((failure) {
          MessageService.showErrorSnackBar(context, failure.message);
        }, (data) {
          _biodata = data;
        });
      }

      await _resolveLocationNames();
    } catch (e) {
      MessageService.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBiodataFromApi() async {
    try {
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();
      if (rawToken != null && rawToken.isNotEmpty) {
        final token =
            rawToken.contains('|') ? rawToken.split('|')[1] : rawToken;
        final resp = await http.get(
          Uri.parse('${AppConstants.authApiUrl}/biodata'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'X-API-Key': AppConstants.apiKey,
          },
        );
        if (resp.statusCode == 200) {
          final Map<String, dynamic> jsonResp = json.decode(resp.body);
          if (jsonResp['status'] == 'SUCCESS' && jsonResp['data'] != null) {
            final data = jsonResp['data'];
            _biodata = Map<String, dynamic>.from(data['biodata'] ?? {});
            _informasiUsaha = data['informasi_usaha'];
            _user = data['user'];
            // Simpan payload supaya form edit biodata tidak fetch ulang
            CacheService().set<Map<String, dynamic>>(
              BiodataCacheKeys.apiBiodataPayload,
              data,
              ttl: const Duration(minutes: 30),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFotoDiriFromApi() async {
    try {
      final repo = GetIt.instance<FamilyRepository>();
      final docsResult =
          await repo.getFamilyMemberDocuments(widget.penduduk.nik);
      docsResult.fold((_) {}, (docs) {
        final url = docs.fotoDiri?.previewUrl ?? '';
        if (url.isNotEmpty) {
          _fotoDiriUrl = url;
        }
      });
    } catch (_) {}
  }

  Future<void> _resolveLocationNames() async {
    if (_biodata == null) return;
    String getStr(dynamic v) => v == null ? '' : v.toString();

    final provId = getStr(_biodata!['province_id']);
    final distId = getStr(_biodata!['district_id']);
    final subDistId = getStr(_biodata!['sub_district_id']);
    final villageId = getStr(_biodata!['village_id']);

    final wilayahService = WilayahService();

    Future<String?> resolveProvinceName() async {
      if (getStr(_biodata!['province_name']).isNotEmpty || provId.isEmpty) {
        return null;
      }
      try {
        final data = await wilayahService.getProvince(provId);
        if (data != null && data['name'] != null) {
          return data['name'].toString();
        }
      } catch (_) {}
      return null;
    }

    Future<String?> resolveDistrictName() async {
      if (getStr(_biodata!['district_name']).isNotEmpty || distId.isEmpty) {
        return null;
      }
      try {
        final data = await wilayahService.getDistrict(distId);
        if (data != null && data['name'] != null) {
          return data['name'].toString();
        }
      } catch (_) {}
      return null;
    }

    Future<String?> resolveSubDistrictName() async {
      if (getStr(_biodata!['sub_district_name']).isNotEmpty ||
          subDistId.isEmpty) {
        return null;
      }
      try {
        final data = await wilayahService.getSubDistrict(subDistId, distId);
        if (data != null && data['name'] != null) {
          return data['name'].toString();
        }
      } catch (_) {}
      return null;
    }

    Future<String?> resolveVillageName() async {
      if (getStr(_biodata!['village_name']).isNotEmpty || villageId.isEmpty) {
        return null;
      }
      try {
        final data =
            await wilayahService.getVillage(villageId, subDistId, distId);
        if (data != null && data['name'] != null) {
          return data['name'].toString();
        }
      } catch (_) {}
      return null;
    }

    final results = await Future.wait([
      resolveProvinceName(),
      resolveDistrictName(),
      resolveSubDistrictName(),
      resolveVillageName(),
    ]);

    if (results[0] != null) _biodata!['province_name'] = results[0];
    if (results[1] != null) _biodata!['district_name'] = results[1];
    if (results[2] != null) _biodata!['sub_district_name'] = results[2];
    if (results[3] != null) _biodata!['village_name'] = results[3];

    final cachedPayload = CacheService()
        .get<Map<String, dynamic>>(BiodataCacheKeys.apiBiodataPayload);
    if (cachedPayload != null && _biodata != null) {
      cachedPayload['biodata'] = Map<String, dynamic>.from(_biodata!);
      CacheService().set<Map<String, dynamic>>(
        BiodataCacheKeys.apiBiodataPayload,
        cachedPayload,
        ttl: const Duration(minutes: 30),
      );
    }
  }

  String? _resolveUsahaPhotoUrl() {
    final rawUrl = _informasiUsaha?['foto_url']?.toString() ?? '';
    final rawPath = _informasiUsaha?['foto']?.toString() ?? '';
    String? url = rawUrl.isNotEmpty ? rawUrl : null;
    if ((url == null || url.isEmpty) && rawPath.isNotEmpty) {
      final base = AppConstants.storageUrl.trim();
      if (base.isNotEmpty) {
        final normalizedBase =
            base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        final normalizedPath =
            rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
        url = '$normalizedBase/$normalizedPath';
      }
    }
    return url;
  }

  LatLng? _parseUsahaLatLng() {
    String latStr = _informasiUsaha?['tag_lat']?.toString() ?? '';
    String lngStr = _informasiUsaha?['tag_lng']?.toString() ?? '';
    final tag = _informasiUsaha?['tag_lokasi']?.toString() ?? '';
    if ((latStr.isEmpty || lngStr.isEmpty) && tag.contains(',')) {
      final parts = tag.split(',');
      if (parts.length >= 2) {
        latStr = parts[0].trim();
        lngStr = parts[1].trim();
      }
    }
    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lngStr);
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  Widget _buildUsahaMapAndPhoto() {
    final pos = _parseUsahaLatLng();
    final fotoUrl = _resolveUsahaPhotoUrl();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Map kiri
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: pos == null
                  ? const Center(child: Icon(Icons.map, color: Colors.grey))
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: pos,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: 0),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.firstudio.ladimas',
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: pos,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.location_on,
                                color: AppTheme.primaryColor, size: 30),
                          )
                        ])
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Foto kanan
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: (fotoUrl == null || fotoUrl.isEmpty)
                  ? const Center(child: Icon(Icons.image, color: Colors.grey))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.image_not_supported,
                                color: Colors.grey)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
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

    final currentKK = _biodata?['kk']?.toString() ?? '';
    setState(() => _isProcessingNavigation = true);

    try {
      // Langsung navigasi ke halaman keluarga
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FamilyListPage(
            kk: currentKK,
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

    final currentKK = _biodata?['kk']?.toString() ?? '';
    setState(() => _isProcessingNavigation = true);

    try {
      // Langsung navigasi ke halaman domisili
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DomisiliMapPage(
            nik: widget.penduduk.nik,
            kk: currentKK,
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
    _isProcessingNavigation = true;

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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () {
              // Kembali ke Beranda dengan pushReplacement
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BerandaPage(penduduk: widget.penduduk),
                ),
              );
            },
          ),
          centerTitle: true,
          title: const Text(
            'Dataku',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout, color: AppTheme.primaryColor),
              tooltip: 'Keluar',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeaderCard(),
                  _buildCategoryMenuTabs(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _buildAccordionSection(
                          icon: Icons.person_outline,
                          title: 'Informasi Pribadi',
                          initiallyExpanded: false, // Default tertutup
                          children: _buildPribadiContent(),
                        ),
                        const SizedBox(height: 12),
                        _buildAccordionSection(
                          icon: Icons.home_outlined,
                          title: 'Informasi Alamat',
                          initiallyExpanded: false, // Default tertutup
                          children: _buildAlamatContent(),
                        ),
                        const SizedBox(height: 12),
                        _buildAccordionSection(
                          icon: Icons.storefront_outlined,
                          title: 'Informasi Usaha',
                          initiallyExpanded: false, // Default tertutup
                          children: _buildUsahaContent(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  color: Color(0xFF4C6FFF),
                  minHeight: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final nama = _biodata?['full_name']?.toString() ?? widget.penduduk.name;
    final nik = _biodata?['nik']?.toString() ?? widget.penduduk.nik;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage:
                  (_fotoDiriUrl != null && _fotoDiriUrl!.trim().isNotEmpty)
                      ? NetworkImage(_fotoDiriUrl!)
                      : null,
              child: (_fotoDiriUrl == null || _fotoDiriUrl!.trim().isEmpty)
                  ? const Icon(Icons.person, color: Color(0xFF64748B), size: 26)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIK: $nik',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.primaryColor, size: 20),
              onPressed: () => _navigateToPage(
                ProfileDetailsPage(
                  nik: widget.penduduk.nik,
                  penduduk: widget.penduduk,
                  biodata: _biodata,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryMenuTabs() {
    final categories = [
      {
        'icon': Icons.manage_accounts_outlined,
        'label': 'Profil',
        'color': const Color(0xFF3B82F6)
      },
      {
        'icon': Icons.person_outline,
        'label': 'Biodata',
        'color': const Color(0xFF8B5CF6)
      },
      {
        'icon': Icons.group_outlined,
        'label': 'Keluarga',
        'color': const Color(0xFF10B981)
      },
      {
        'icon': Icons.location_on_outlined,
        'label': 'Domisili',
        'color': const Color(0xFFEF4444)
      },
      {
        'icon': Icons.home_work_outlined,
        'label': 'Aset',
        'color': const Color(0xFFF59E0B)
      },
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(categories.length, (index) {
            final cat = categories[index];
            final bool isSelected = _selectedCategoryIndex == index;
            final Color itemColor = cat['color'] as Color;

            return GestureDetector(
              onTap: () {
                if (_isProcessingNavigation) return;
                _selectedCategoryIndex = index;
                final currentKK = _biodata?['kk']?.toString() ?? '';
                switch (index) {
                  case 0:
                    _navigateToPage(ProfileEditPage(
                      penduduk: widget.penduduk,
                      initialBiodata: _biodata,
                    ));
                    break;
                  case 1:
                    _navigateToPage(BiodataEditPage(
                      penduduk: widget.penduduk,
                      initialBiodata: _biodata,
                    ));
                    break;
                  case 2:
                    if (!_isProcessingNavigation && !_isDebouncing()) {
                      _navigateToPage(FamilyListPage(
                          kk: currentKK, nikPenduduk: widget.penduduk.nik));
                    }
                    break;
                  case 3:
                    if (!_isProcessingNavigation && !_isDebouncing()) {
                      _navigateToPage(DomisiliMapPage(
                          nik: widget.penduduk.nik, kk: currentKK));
                    }
                    break;
                  case 4:
                    _navigateToPage(const AssetListPage());
                    break;
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? itemColor.withOpacity(0.15)
                            : itemColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: itemColor, width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        cat['icon'] as IconData,
                        color: itemColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? itemColor : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAccordionSection({
    required IconData icon,
    required String title,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          leading: Icon(icon, color: const Color(0xFF1E293B), size: 20),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Mengatur teks ke Rata Kiri
        children: [
          Text(
            label,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPribadiContent() {
    final kk = _biodata?['kk']?.toString() ?? '';
    final gender = _biodata?['gender']?.toString() ?? '';
    final age = _biodata?['age']?.toString() ?? '';
    final birthPlace = _biodata?['birth_place']?.toString() ?? '';
    final birthDate = _biodata?['birth_date']?.toString() ?? '';

    return [
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Container Rata Kiri
          children: [
            _buildDetailItem('No. KK', kk),
            _buildDetailItem('Jenis Kelamin', gender),
            _buildDetailItem('Umur', age),
            _buildDetailItem('Tempat Lahir', birthPlace),
            _buildDetailItem('Tanggal Lahir', birthDate),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildAlamatContent() {
    final address = _biodata?['address']?.toString() ?? '';
    final rt = _biodata?['rt']?.toString() ?? '';
    final rw = _biodata?['rw']?.toString() ?? '';
    final prov = _biodata?['province_name']?.toString() ?? '';
    final kab = _biodata?['district_name']?.toString() ?? '';
    final kec = _biodata?['sub_district_name']?.toString() ?? '';
    final desa = _biodata?['village_name']?.toString() ?? '';

    return [
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Container Rata Kiri
          children: [
            _buildDetailItem('Alamat', address),
            _buildDetailItem('RT/RW',
                '${rt.isNotEmpty ? rt : '-'}/${rw.isNotEmpty ? rw : '-'}'),
            _buildDetailItem('Provinsi', prov),
            _buildDetailItem('Kabupaten/Kota', kab),
            _buildDetailItem('Kecamatan', kec),
            _buildDetailItem('Desa', desa),
          ],
        ),
      ),
    ];
  }

  // Fungsi untuk membuka Google Maps
  Future<void> _openGoogleMaps(double lat, double lng) async {
    // Gunakan URI google maps
    final Uri googleMapsUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      // Membuka langsung ke aplikasi eksternal (Browser/Google Maps)
      bool launched = await launchUrl(
        googleMapsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        MessageService.showErrorSnackBar(context, 'Tidak dapat membuka peta');
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, 'Gagal membuka lokasi: $e');
      }
    }
  }

  // Fungsi untuk menampilkan Popup Foto
  void _showImagePopup(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: const Text('Gagal memuat gambar'),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUsahaContent() {
    final usaha = _informasiUsaha ?? {};
    final usahaNama = usaha['nama_usaha']?.toString() ?? '';
    final usahaAlamat = usaha['alamat']?.toString() ?? '';
    final usahaKelompok = usaha['kelompok_usaha']?.toString() ?? '';
    final pos = _parseUsahaLatLng();
    final fotoUrl = _resolveUsahaPhotoUrl();

    return [
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem('Nama Usaha', usahaNama),
            _buildDetailItem('Alamat Usaha', usahaAlamat),
            _buildDetailItem('Kelompok Usaha', usahaKelompok),
            if (pos != null || fotoUrl != null) const SizedBox(height: 8),
            if (pos != null || fotoUrl != null)
              Row(
                children: [
                  // MAPS: Ketika diklik akan mengarahkan ke Google Maps
                  if (pos != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _openGoogleMaps(pos.latitude, pos.longitude),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  options: MapOptions(
                                    initialCenter: pos,
                                    initialZoom: 14,
                                    interactionOptions:
                                        const InteractionOptions(flags: 0),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      subdomains: const ['a', 'b', 'c'],
                                    ),
                                    MarkerLayer(markers: [
                                      Marker(
                                        point: pos,
                                        width: 24,
                                        height: 24,
                                        child: const Icon(Icons.location_on,
                                            color: Color(0xFFEF4444), size: 24),
                                      )
                                    ]),
                                  ],
                                ),
                                // Label petunjuk klik
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.open_in_new,
                                            color: Colors.white, size: 10),
                                        SizedBox(width: 2),
                                        Text(
                                          'Buka Maps',
                                          style: TextStyle(
                                              color: Colors.white, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (pos != null && fotoUrl != null) const SizedBox(width: 12),
                  // FOTO: Ketika diklik akan muncul Pop-up foto full
                  if (fotoUrl != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showImagePopup(fotoUrl),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              fotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi',
          style:
              TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        content: const Text('Apakah Anda yakin ingin keluar?',
            style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
            ),
            child: const Text('BATAL',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('KELUAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4C6FFF)),
                    SizedBox(height: 16),
                    Text('Sedang keluar...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _biodata = null;
          _informasiUsaha = null;
          _user = null;
          _fotoDiriUrl = null;
          _isLoading = false;
          _isProcessingNavigation = false;
        });
      }

      if (mounted) {
        context.read<AuthBloc>().add(LogoutEvent());
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 200));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        MessageService.showErrorSnackBar(
          context,
          'Gagal logout: ${e.toString()}',
        );
      }
    }
  }
}
