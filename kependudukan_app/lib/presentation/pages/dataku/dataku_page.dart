import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/presentation/pages/profile/profile_details_page.dart';
import 'package:ladimas/presentation/pages/family/family_list_page.dart';
import 'package:ladimas/presentation/pages/domisili/domisili_map_page.dart';
import 'package:ladimas/presentation/pages/asset/asset_list_page.dart';
import 'package:ladimas/presentation/pages/profile/biodata_edit_page.dart';
import 'package:ladimas/presentation/pages/profile/profile_edit_page.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:get_it/get_it.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/presentation/pages/beranda/beranda_page.dart';
import 'package:ladimas/presentation/pages/warungku/warungku_page.dart';
import 'package:ladimas/presentation/pages/tagihan/tagihan_page.dart';
import 'package:ladimas/presentation/pages/webview/document_services_webview_page.dart';
import 'package:ladimas/presentation/pages/home/penduduk_home_page.dart';
import 'package:ladimas/presentation/pages/profil_desa/profil_desa_page.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:ladimas/presentation/pages/auth/login_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';

class _MenuConf {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuConf(this.icon, this.label, this.onTap);
}

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
  Map<String, dynamic>? _user; // ignore: unused_field
  final Set<int> _hoveredMenuIndexes = <int>{};
  final Set<int> _pressedMenuIndexes = <int>{};
  String? _fotoDiriUrl;

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
      // Ambil biodata lengkap dari API baru jika token tersedia
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
            }
          }
        }
      } catch (_) {}

      // Fallback repository jika belum ada biodata
      if (_biodata == null || _biodata!.isEmpty) {
        final repository = GetIt.instance<AuthRepository>();
        final result = await repository.getPendudukDetail(widget.penduduk.nik);
        result.fold((failure) {
          MessageService.showErrorSnackBar(context, failure.message);
        }, (data) {
          _biodata = data;
        });
      }

      // Pastikan nama wilayah terisi (fallback dari ID jika perlu)
      await _resolveLocationNames();

      // Ambil foto diri dari dokumen anggota (jika ada)
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
    } catch (e) {
      MessageService.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveLocationNames() async {
    if (_biodata == null) return;
    String getStr(dynamic v) => v == null ? '' : v.toString();

    String provName = getStr(_biodata!['province_name']);
    String distName = getStr(_biodata!['district_name']);
    String subDistName = getStr(_biodata!['sub_district_name']);
    String villageName = getStr(_biodata!['village_name']);

    final provId = getStr(_biodata!['province_id']);
    final distId = getStr(_biodata!['district_id']);
    final subDistId = getStr(_biodata!['sub_district_id']);
    final villageId = getStr(_biodata!['village_id']);

    final wilayahService = WilayahService();

    if (provName.isEmpty && provId.isNotEmpty) {
      try {
        final data = await wilayahService.getProvince(provId);
        if (data != null && data['name'] != null) provName = data['name'];
      } catch (_) {}
    }
    if (distName.isEmpty && distId.isNotEmpty) {
      try {
        final data = await wilayahService.getDistrict(distId);
        if (data != null && data['name'] != null) distName = data['name'];
      } catch (_) {}
    }
    if (subDistName.isEmpty && subDistId.isNotEmpty) {
      try {
        final data = await wilayahService.getSubDistrict(subDistId, distId);
        if (data != null && data['name'] != null) subDistName = data['name'];
      } catch (_) {}
    }
    if (villageName.isEmpty && villageId.isNotEmpty) {
      try {
        final data =
            await wilayahService.getVillage(villageId, subDistId, distId);
        if (data != null && data['name'] != null) villageName = data['name'];
      } catch (_) {}
    }

    // Simpan kembali ke map agar widget memakai nama yang sudah terisi
    _biodata!['province_name'] =
        provName.isNotEmpty ? provName : _biodata!['province_name'];
    _biodata!['district_name'] =
        distName.isNotEmpty ? distName : _biodata!['district_name'];
    _biodata!['sub_district_name'] =
        subDistName.isNotEmpty ? subDistName : _biodata!['sub_district_name'];
    _biodata!['village_name'] =
        villageName.isNotEmpty ? villageName : _biodata!['village_name'];
  }

  // ===== Informasi Usaha helper =====
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
                                color: Color(0xFF4A47DC), size: 30),
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
    await _navigateToPage(ProfileDetailsPage(
      nik: widget.penduduk.nik,
      penduduk: widget.penduduk,
      biodata: _biodata,
    ));
  }

  Future<void> _navigateToAssetPage() async {
    await _navigateToPage(const AssetListPage());
  }

  Future<void> _navigateToProfileEditPage() async {
    await _navigateToPage(BiodataEditPage(penduduk: widget.penduduk));
  }

  Future<void> _navigateToProfileUpdatePage() async {
    await _navigateToPage(ProfileEditPage(penduduk: widget.penduduk));
  }

  Widget _buildSectionTitle(String text,
      {bool center = false, double fontSize = 14}) {
    // Override ukuran font jika diminta
    final effective = Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        color: const Color(0xFF333333),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: center ? Center(child: effective) : effective,
    );
  }

  Widget _buildReadonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 36,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final nama = _biodata?['full_name']?.toString() ?? widget.penduduk.name;
    final nik = _biodata?['nik']?.toString() ?? widget.penduduk.nik;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF4A47DC),
                backgroundImage:
                    (_fotoDiriUrl != null && _fotoDiriUrl!.trim().isNotEmpty)
                        ? NetworkImage(_fotoDiriUrl!)
                        : null,
                child: (_fotoDiriUrl == null || _fotoDiriUrl!.trim().isEmpty)
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nik,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit Profil',
                icon: const Icon(Icons.edit, color: Color(0xFF4A47DC)),
                onPressed: _navigateToProfilePage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataContent() {
    final kk = _biodata?['kk']?.toString() ?? '';
    final gender = _biodata?['gender']?.toString() ?? '';
    final age = _biodata?['age']?.toString() ?? '';
    final birthPlace = _biodata?['birth_place']?.toString() ?? '';
    final birthDate = _biodata?['birth_date']?.toString() ?? '';
    // final noHp = _user?['no_hp']?.toString() ?? _biodata?['telephone']?.toString() ?? '';

    final address = _biodata?['address']?.toString() ?? '';
    final rt = _biodata?['rt']?.toString() ?? '';
    final rw = _biodata?['rw']?.toString() ?? '';
    final prov = _biodata?['province_name']?.toString() ?? '';
    final kab = _biodata?['district_name']?.toString() ?? '';
    final kec = _biodata?['sub_district_name']?.toString() ?? '';
    final desa = _biodata?['village_name']?.toString() ?? '';

    // Informasi usaha jika ada dari endpoint biodata API baru
    final usaha = _informasiUsaha ?? {};
    final usahaNama = usaha['nama_usaha']?.toString() ?? '';
    final usahaKelompok = usaha['kelompok_usaha']?.toString() ?? '';
    final usahaAlamat = usaha['alamat']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Profil Pengguna', center: true, fontSize: 16),
        _buildProfileCard(),
        _buildSectionTitle('Informasi Pribadi'),
        _buildReadonlyField('No. KK ', kk),
        _buildReadonlyField('Jenis Kelamin ', gender),
        _buildReadonlyField('Umur ', age),
        _buildReadonlyField('Tempat Lahir ', birthPlace),
        _buildReadonlyField('Tanggal Lahir ', birthDate),
        _buildSectionTitle('Informasi Alamat'),
        _buildReadonlyField('Alamat', address),
        _buildReadonlyField(
            'RT/RW', '${rt.isNotEmpty ? rt : ''}/${rw.isNotEmpty ? rw : ''}'),
        _buildReadonlyField('Provinsi', prov),
        _buildReadonlyField('Kabupaten/Kota', kab),
        _buildReadonlyField('Kecamatan', kec),
        _buildReadonlyField('Desa', desa),
        _buildSectionTitle('Informasi Usaha'),
        _buildReadonlyField('Nama Usaha', usahaNama),
        _buildReadonlyField('Alamat Usaha', usahaAlamat),
        _buildReadonlyField('Kelompok Usaha', usahaKelompok),
        _buildUsahaMapAndPhoto(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFFF5F6FA)),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Text(
          'Dataku',
          style: TextStyle(
            color: Color(0xFF4A47DC),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth;
          const double spacing = 8;
          int columns;
          if (maxWidth >= 360) {
            columns = 3; // 3 kolom untuk layar lebar
          } else if (maxWidth >= 240) {
            columns = 2; // 2 kolom untuk layar sedang
          } else {
            columns = 1; // 1 kolom untuk layar kecil
          }

          final List<_MenuConf> items = <_MenuConf>[
            _MenuConf(
                Icons.manage_accounts, 'Profil', _navigateToProfileUpdatePage),
            _MenuConf(Icons.person_2, 'Biodata', _navigateToProfileEditPage),
            _MenuConf(
              _isProcessingNavigation
                  ? Icons.hourglass_empty
                  : Icons.family_restroom,
              'Keluarga',
              _isProcessingNavigation ? () {} : _navigateToFamilyPage,
            ),
            _MenuConf(Icons.location_on, 'Domisili', _navigateToDomisiliPage),
            _MenuConf(Icons.home_work, 'Aset', _navigateToAssetPage),
          ];

          double itemWidth;
          if (columns == 1) {
            itemWidth = maxWidth;
          } else {
            itemWidth = (maxWidth - spacing * (columns - 1)) / columns;
          }

          return Wrap(
            spacing: spacing,
            runSpacing: 8,
            children: items
                .asMap()
                .entries
                .map((entry) => SizedBox(
                      width: itemWidth,
                      child: _buildMenuItem(
                        index: entry.key,
                        icon: items[entry.key].icon,
                        label: items[entry.key].label,
                        onTap: items[entry.key].onTap,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    // Pecah label menjadi dua baris jika terlalu panjang (mirip _buildTabItem)
    String firstLine = label;
    String secondLine = '';
    if (label.length > 8) {
      final words = label.split(' ');
      if (words.length >= 2) {
        firstLine = words[0];
        secondLine = words.sublist(1).join(' ');
      } else {
        final mid = (label.length / 2).round();
        firstLine = label.substring(0, mid);
        secondLine = label.substring(mid);
      }
    }

    final bool isHovered = _hoveredMenuIndexes.contains(index);
    final bool isPressed = _pressedMenuIndexes.contains(index);
    final Color primary = const Color(0xFF4A47DC);
    final Color defaultText = const Color(0xFF9E9E9E); // abu-abu seperti home
    final bool active = isHovered || isPressed;
    final Color iconColor = active ? primary : defaultText;
    final Color textColor = active ? primary : defaultText;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMenuIndexes.add(index)),
      onExit: (_) => setState(() => _hoveredMenuIndexes.remove(index)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onHighlightChanged: (isNowPressed) {
            setState(() {
              if (isNowPressed) {
                _pressedMenuIndexes.add(index);
              } else {
                _pressedMenuIndexes.remove(index);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: const BoxDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Icon(
                  icon,
                  size: 28,
                  color: iconColor,
                ),
                const SizedBox(height: 6),
                if (secondLine.isEmpty)
                  Text(
                    firstLine,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Column(
                    children: [
                      Text(
                        firstLine,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        secondLine,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  // (dipindah ke top-level)

  Widget _buildMenuShortcut({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false, // Hapus semua route sebelumnya
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: const Color(0xFF4A47DC),
          elevation: 0,
          backgroundColor: const Color(0xFFF5F6FA),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(
                Icons.logout,
                color: Color(0xFF4A47DC),
              ),
              tooltip: 'Keluar',
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF5F6FA),
        body: Column(
          children: [
            _buildHeaderSection(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMenuGrid(),
                          const SizedBox(height: 8),
                          _buildDataContent(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: const Color(0xFF4A47DC),
          unselectedItemColor: Colors.grey,
          currentIndex: 0, // Set ke 0 tapi tidak akan terlihat selected
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
                // Navigate to Informasi Desa (PendudukHomePage)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PendudukHomePage(
                      penduduk: widget.penduduk,
                      initialTabIndex: 0, // Berita Desa tab
                    ),
                  ),
                );
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss saat logout sedang diproses
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi',
          style:
              TextStyle(color: Color(0xFF4A47DC), fontWeight: FontWeight.bold),
        ),
        content: const Text('Apakah Anda yakin ingin keluar?',
            style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('KELUAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Method baru untuk melakukan logout dengan cleanup yang proper
  Future<void> _performLogout() async {
    try {
      // Show loading indicator
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
                    CircularProgressIndicator(color: Color(0xFF4A47DC)),
                    SizedBox(height: 16),
                    Text('Sedang keluar...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Clear semua state lokal terlebih dahulu
      if (mounted) {
        setState(() {
          _biodata = null;
          _informasiUsaha = null;
          _user = null;
          _fotoDiriUrl = null;
          _isLoading = false;
          _isProcessingNavigation = false;
          _hoveredMenuIndexes.clear();
          _pressedMenuIndexes.clear();
        });
      }

      // 2. Trigger logout event
      if (mounted) {
        context.read<AuthBloc>().add(LogoutEvent());
      }

      // 3. Wait untuk memastikan logout event diproses
      await Future.delayed(const Duration(milliseconds: 800));

      // 4. Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 5. Force navigate ke login page (sebagai fallback jika BlocListener tidak trigger)
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 200));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog jika ada error
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
