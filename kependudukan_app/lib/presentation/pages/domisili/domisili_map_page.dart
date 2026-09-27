import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/presentation/cubits/domisili/domisili_cubit.dart';
import 'package:ladimas/presentation/widgets/common/location_map_component.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'dart:async';

class DomisiliMapPage extends StatefulWidget {
  final String nik;
  final String kk;

  const DomisiliMapPage({super.key, required this.nik, required this.kk});

  @override
  State<DomisiliMapPage> createState() => _DomisiliMapPageState();
}

class _DomisiliMapPageState extends State<DomisiliMapPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _searchLocationController =
      TextEditingController();

  late final DomisiliCubit _domisiliCubit;
  final MapController _mapController = MapController();
  bool _isSaving = false;
  bool _isSearching = false;
  String _currentKK = '';
  bool _isLoadingKK = false;
  String? _errorMessage;
  StreamSubscription<MapEvent>? _mapEventSub;
  Timer? _debounce;

  LatLng _currentPosition = const LatLng(
    -7.310000,
    110.290000,
  );

  int? _provinceId;
  int? _districtId;
  int? _subDistrictId;
  int? _villageId;

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _subDistricts = [];
  List<Map<String, dynamic>> _villages = [];

  Future<Map<String, String>> _authHeaders() async {
    final authLocalStorage = GetIt.instance<AuthLocalStorage>();
    final rawToken = await authLocalStorage.getStoredToken();
    String bearer = '';
    if (rawToken != null && rawToken.isNotEmpty) {
      bearer = rawToken.contains('|') ? rawToken.split('|').last : rawToken;
    }
    return {
      'Accept': 'application/json',
      if (bearer.isNotEmpty) 'Authorization': 'Bearer $bearer',
      'X-API-Key': AppConstants.apiKey,
    };
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String? _getCodeById(List<Map<String, dynamic>> list, int? id) {
    if (id == null) return null;
    for (final e in list) {
      final int? itemId = _toInt(e['id']);
      if (itemId == id) return e['code']?.toString();
    }
    return null;
  }

  Future<void> _loadProvinces() async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(Uri.parse('${AppConstants.authApiUrl}/user/warungku/wilayah/provinces'), headers: headers);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (mounted) setState(() => _provinces = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (_) {}
  }

  Future<void> _loadDistricts(String code) async {
    try {
      final head = await _authHeaders();
      final res = await http.get(Uri.parse('${AppConstants.authApiUrl}/user/warungku/wilayah/districts/$code'), headers: head);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) setState(() => _districts = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (_) {}
  }

  Future<void> _loadSubDistricts(String code) async {
    try {
      final head = await _authHeaders();
      final res = await http.get(Uri.parse('${AppConstants.authApiUrl}/user/warungku/wilayah/sub-districts/$code'), headers: head);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) setState(() => _subDistricts = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (_) {}
  }

  Future<void> _loadVillages(String code) async {
    try {
      final head = await _authHeaders();
      final res = await http.get(Uri.parse('${AppConstants.authApiUrl}/user/warungku/wilayah/villages/$code'), headers: head);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) setState(() => _villages = List<Map<String, dynamic>>.from(data['data']));
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _domisiliCubit = GetIt.instance<DomisiliCubit>();

    // Inisialisasi data wilayah
    _loadProvinces();

    // Jika kk kosong, ambil data KK terlebih dahulu
    if (widget.kk.isEmpty) {
      _loadKKData();
    } else {
      _loadData();
    }

    // Dengarkan pergerakan peta dan update koordinat berdasarkan center
    _mapEventSub = _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove ||
          event is MapEventFlingAnimation ||
          event is MapEventRotate) {
        // Debounce agar tidak terlalu sering reverse geocoding
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 450), () async {
          final center = _mapController.camera.center;
          _onCenterChanged(center);
        });
      } else if (event is MapEventMoveEnd) {
        final center = _mapController.camera.center;
        _onCenterChanged(center);
      }
    });
  }

  /// Inisialisasi peta dan alamat dari data user login
  Future<void> _initializeFromUserData() async {
    try {
      print('🔵 [Domisili] Starting initialization from user data...');
      final authLocalStorage = AuthLocalStorage();
      final userData = await authLocalStorage.getUserCredentials();

      if (userData == null) {
        print('⚠️  [Domisili] No user credentials found');
        return;
      }

      print('📦 [Domisili] User data keys: ${userData.keys.toList()}');

      // Ambil alamat dari user data
      final alamat = userData['alamat']?.toString() ?? '';
      print(
          '📍 [Domisili] Alamat from storage: ${alamat.isNotEmpty ? alamat : "EMPTY"}');

      // Ambil tag_lokasi dari user data (format: "lat,lng")
      final tagLokasi = userData['tag_lokasi']?.toString() ?? '';
      print('🗺️  [Domisili] Tag lokasi from storage: ${tagLokasi.isNotEmpty ? tagLokasi : "EMPTY"}');
      
      final provinceIdStr = userData['province_id']?.toString() ?? '';
      final districtIdStr = userData['district_id']?.toString() ?? '';
      final subDistrictIdStr = userData['sub_district_id']?.toString() ?? '';
      final villageIdStr = userData['village_id']?.toString() ?? '';

      // Jika ada alamat, set ke controller
      if (alamat.isNotEmpty) {
        if (mounted) {
          setState(() {
            _addressController.text = alamat;
            if (provinceIdStr.isNotEmpty) _provinceId = _toInt(provinceIdStr);
            if (districtIdStr.isNotEmpty) _districtId = _toInt(districtIdStr);
            if (subDistrictIdStr.isNotEmpty) _subDistrictId = _toInt(subDistrictIdStr);
            if (villageIdStr.isNotEmpty) _villageId = _toInt(villageIdStr);
          });
          print('✅ [Domisili] Alamat set to controller: $alamat');
          
          if (_provinceId != null) {
              final pCode = _getCodeById(_provinces, _provinceId);
              if (pCode != null) await _loadDistricts(pCode);
              if (_districtId != null) {
                  final dCode = _getCodeById(_districts, _districtId);
                  if (dCode != null) await _loadSubDistricts(dCode);
                  if (_subDistrictId != null) {
                      final sCode = _getCodeById(_subDistricts, _subDistrictId);
                      if (sCode != null) await _loadVillages(sCode);
                  }
              }
          }
        }
      } else {
        print('⚠️  [Domisili] Alamat is empty, skipping...');
      }

      // Jika ada tag_lokasi, parse dan set ke peta
      if (tagLokasi.isNotEmpty) {
        final parts = tagLokasi.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());

          print('🔢 [Domisili] Parsed coordinates - Lat: $lat, Lng: $lng');

          if (lat != null && lng != null) {
            final initialPosition = LatLng(lat, lng);

            // Update state dengan koordinat
            if (mounted) {
              setState(() {
                _currentPosition = initialPosition;
                _latitudeController.text = lat.toStringAsFixed(6);
                _longitudeController.text = lng.toStringAsFixed(6);
              });
              print(
                  '✅ [Domisili] Coordinates set - Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}');
            }

            // Tunggu sampai map controller ready, lalu move ke lokasi
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Delay sedikit untuk memastikan map sudah ter-render
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  try {
                    _mapController.move(initialPosition, 15.0);
                    print('✅ [Domisili] Map moved to tag_lokasi: $tagLokasi');
                  } catch (e) {
                    print('❌ [Domisili] Error moving map: $e');
                  }
                }
              });
            });

            print('✅ [Domisili] Successfully initialized from user data');
            print('   - Alamat: $alamat');
            print('   - Tag Lokasi: $tagLokasi');
            print('   - Position: Lat $lat, Lng $lng');
            return;
          } else {
            print(
                '❌ [Domisili] Failed to parse coordinates - Lat: $lat, Lng: $lng');
          }
        } else {
          print(
              '❌ [Domisili] Invalid tag_lokasi format - expected "lat,lng", got: $tagLokasi');
        }
      } else {
        print(
            '⚠️  [Domisili] Tag lokasi is empty, skipping map initialization...');
      }

      print('⚠️  [Domisili] Initialization completed but some data missing');
    } catch (e, stackTrace) {
      print('❌ [Domisili] Error initializing from user data: $e');
      print('❌ [Domisili] Stack trace: $stackTrace');
    }
  }

  Future<void> _loadKKData() async {
    if (_isLoadingKK) return;

    setState(() => _isLoadingKK = true);

    try {
      // Ambil data KK dari repository
      final repository = GetIt.instance<AuthRepository>();
      final result = await repository.getPendudukDetail(widget.nik);

      if (!mounted) return;

      result.fold(
        (failure) {
          // Jika gagal, tampilkan error
          setState(() {
            _errorMessage = 'Gagal mendapatkan data KK: ${failure.message}';
          });
        },
        (data) {
          final kk = data['kk']?.toString() ?? '';
          if (kk.isNotEmpty) {
            // Jika berhasil dapat KK, update state dan load data domisili
            setState(() {
              _currentKK = kk;
              _errorMessage = null;
            });
            _loadData();
          } else {
            // Jika tidak ada KK, tampilkan pesan
            setState(() {
              _errorMessage =
                  'Nomor KK tidak tersedia untuk melihat data domisili';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingKK = false);
      }
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Gunakan kk yang sudah ada atau yang baru didapat
    final kk = widget.kk.isNotEmpty ? widget.kk : _currentKK;

    if (kk.isEmpty) {
      return;
    }

    await _domisiliCubit.loadFamilyMember(kk, widget.nik,
        forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>?> _getCitizenData() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.goBaseUrl}/api/citizens/${widget.nik}'),
        headers: {
          'X-API-Key': AppConstants.apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      // Log error tanpa print statement
      return null;
    }
  }

  // Fungsi untuk mencari lokasi berdasarkan alamat
  Future<void> _searchLocation() async {
    final query = _searchLocationController.text.trim();
    if (query.isEmpty) {
      MessageService.showErrorSnackBar(
        context,
        'Masukkan alamat yang ingin dicari',
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Gunakan OpenStreetMap Nominatim API untuk geocoding
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=id',
        ),
        headers: {
          'User-Agent': 'LADIMAS App',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        if (results.isNotEmpty) {
          final result = results.first;
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);

          // Update posisi peta
          if (mounted) {
            setState(() {
              _currentPosition = LatLng(lat, lon);
              _latitudeController.text = lat.toStringAsFixed(6);
              _longitudeController.text = lon.toStringAsFixed(6);
              _addressController.text = result['display_name'] ?? query;
            });
          }

          // Pindahkan peta ke lokasi yang ditemukan
          _mapController.move(_currentPosition, 15.0);

          if (mounted) {
            MessageService.showSuccessSnackBar(
              context,
              'Lokasi ditemukan: ${result['display_name']}',
            );
          }
        } else {
          if (mounted) {
            MessageService.showErrorSnackBar(
              context,
              'Lokasi tidak ditemukan. Coba dengan kata kunci yang lebih spesifik.',
            );
          }
        }
      } else {
        throw Exception('Gagal mencari lokasi');
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(
          context,
          'Gagal mencari lokasi: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // Fungsi untuk menggunakan lokasi saat ini (GPS)
  Future<void> _useCurrentLocation() async {
    try {
      // Cek layanan lokasi aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        MessageService.showErrorSnackBar(
          context,
          'Layanan lokasi tidak aktif. Aktifkan GPS Anda.',
        );
        return;
      }

      // Cek & minta izin
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        MessageService.showErrorSnackBar(
          context,
          'Izin lokasi ditolak.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        MessageService.showErrorSnackBar(
          context,
          'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.',
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(pos.latitude, pos.longitude);

      // Reverse geocoding via Nominatim
      String resolvedAddress =
          'Koordinat: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      try {
        final resp = await http.get(
          Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1&accept-language=id'),
          headers: {
            'User-Agent': 'LADIMAS App',
          },
        );
        if (resp.statusCode == 200) {
          final Map<String, dynamic> body = json.decode(resp.body);
          if (body['display_name'] != null) {
            resolvedAddress = body['display_name'];
          }
        }
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _currentPosition = current;
        _latitudeController.text = current.latitude.toStringAsFixed(6);
        _longitudeController.text = current.longitude.toStringAsFixed(6);
        _addressController.text = resolvedAddress;
      });

      _mapController.move(current, 16.0);

      MessageService.showInfoSnackBar(
        context,
        'Lokasi GPS berhasil didapatkan',
      );
    } catch (e) {
      MessageService.showErrorSnackBar(
        context,
        'Gagal mendapatkan lokasi GPS: ${e.toString()}',
      );
    }
  }

  Map<String, dynamic> _convertDataToApiFormat(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Convert gender
    if (result['gender'] == 'Laki-Laki') {
      result['gender'] = 1;
    } else if (result['gender'] == 'Perempuan') {
      result['gender'] = 2;
    }

    // Convert citizen status
    if (result['citizen_status'] == 'WNI') {
      result['citizen_status'] = 1;
    } else if (result['citizen_status'] == 'WNA') {
      result['citizen_status'] = 2;
    }

    // Convert family status
    final familyStatusMap = {
      'ANAK': 1,
      'Anak': 1,
      'KEPALA KELUARGA': 2,
      'Kepala Keluarga': 2,
      'ISTRI': 3,
      'Istri': 3,
      'ORANG TUA': 4,
      'Orang Tua': 4,
      'MERTUA': 5,
      'Mertua': 5,
      'CUCU': 6,
      'Cucu': 6,
      'FAMILI LAIN': 7,
      'Famili Lain': 7
    };
    if (result['family_status'] is String &&
        familyStatusMap[result['family_status']] != null) {
      result['family_status'] = familyStatusMap[result['family_status']];
    }

    // Convert blood type
    final bloodTypeMap = {
      'A': 1,
      'B': 2,
      'AB': 3,
      'O': 4,
      'A+': 5,
      'A-': 6,
      'B+': 7,
      'B-': 8,
      'AB+': 9,
      'AB-': 10,
      'O+': 11,
      'O-': 12,
      'Tidak Tahu': 13
    };
    if (bloodTypeMap[result['blood_type']] != null) {
      result['blood_type'] = bloodTypeMap[result['blood_type']];
    }

    // Convert religion
    final religionMap = {
      'Islam': 1,
      'Kristen': 2,
      'Katolik': 3,
      'Katholik': 3,
      'Hindu': 4,
      'Buddha': 5,
      'Budha': 5,
      'Kong Hu Cu': 6,
      'Konghucu': 6,
      'Lainnya': 7
    };
    if (religionMap[result['religion']] != null) {
      result['religion'] = religionMap[result['religion']];
    }

    // Convert marital status
    final maritalMap = {
      'Belum Kawin': 1,
      'Kawin Tercatat': 2,
      'Kawin Belum Tercatat': 3,
      'Cerai Hidup Tercatat': 4,
      'Cerai Hidup Belum Tercatat': 5,
      'Cerai Mati': 6
    };
    if (maritalMap[result['marital_status']] != null) {
      result['marital_status'] = maritalMap[result['marital_status']];
    }

    // Convert certificate statuses
    if (result['birth_certificate'] == 'Ada') {
      result['birth_certificate'] = 1;
    } else if (result['birth_certificate'] == 'Tidak Ada') {
      result['birth_certificate'] = 2;
    }

    if (result['marital_certificate'] == 'Ada') {
      result['marital_certificate'] = 1;
    } else if (result['marital_certificate'] == 'Tidak Ada') {
      result['marital_certificate'] = 2;
    }

    if (result['divorce_certificate'] == 'Ada') {
      result['divorce_certificate'] = 1;
    } else if (result['divorce_certificate'] == 'Tidak Ada') {
      result['divorce_certificate'] = 2;
    }

    if (result['mental_disorders'] == 'Ada') {
      result['mental_disorders'] = 1;
    } else if (result['mental_disorders'] == 'Tidak Ada') {
      result['mental_disorders'] = 2;
    }

    // Convert disabilities
    final disabilitiesMap = {
      'Fisik': 1,
      'Netra/Buta': 2,
      'Rungu/Wicara': 3,
      'Mental/Jiwa': 4,
      'Fisik dan Mental': 5,
      'Lainnya': 6
    };
    if (result['disabilities'] is String) {
      if (result['disabilities'].isEmpty || result['disabilities'] == ' ') {
        result['disabilities'] = null;
      } else if (disabilitiesMap[result['disabilities']] != null) {
        result['disabilities'] = disabilitiesMap[result['disabilities']];
      }
    }

    // Convert education status
    final educationMap = {
      'Tidak/Belum Sekolah': 1,
      'Belum tamat SD/Sederajat': 2,
      'Tamat SD': 3,
      'SLTP/SMP/Sederajat': 4,
      'SLTA/SMA/Sederajat': 5,
      'Diploma I/II': 6,
      'Akademi/Diploma III/ Sarjana Muda': 7,
      'Diploma IV/ Strata I/ Strata II': 8,
      'Strata III': 9,
      'Lainnya': 10
    };
    if (educationMap[result['education_status']] != null) {
      result['education_status'] = educationMap[result['education_status']];
    }

    // Convert dates
    if (result['birth_date'] != null &&
        result['birth_date'].toString().contains('/')) {
      final parts = result['birth_date'].split('/');
      if (parts.length == 3) {
        result['birth_date'] = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    // Handle empty values
    if (result['marriage_date'] == '') {
      result['marriage_date'] = ' ';
    }
    if (result['divorce_certificate_date'] == '') {
      result['divorce_certificate_date'] = ' ';
    }
    if (result['birth_certificate_no'] == '') {
      result['birth_certificate_no'] = ' ';
    }
    if (result['marital_certificate_no'] == '') {
      result['marital_certificate_no'] = ' ';
    }
    if (result['divorce_certificate_no'] == '') {
      result['divorce_certificate_no'] = ' ';
    }

    return result;
  }

  Future<void> _saveLocation() async {
    if (_isSaving) return;

    final lat = _latitudeController.text;
    final lng = _longitudeController.text;
    final address = _addressController.text.trim();

    if (lat.isEmpty || lng.isEmpty) {
      MessageService.showErrorSnackBar(
        context,
        'Pilih lokasi pada peta terlebih dahulu',
      );
      return;
    }

    if (address.isEmpty) {
      MessageService.showErrorSnackBar(
        context,
        'Masukkan alamat domisili',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Ambil token untuk endpoint auth-api
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();
      if (rawToken == null || rawToken.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final token =
          rawToken.contains('|') ? rawToken.split('|').last : rawToken;

      final response = await http.post(
        Uri.parse('${AppConstants.authApiUrl}/user/profile/update-location'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'target_nik': widget.nik,
          'tag_lokasi': '$lat,$lng',
          'alamat': address,
          'province_id': _provinceId,
          'district_id': _districtId,
          'sub_district_id': _subDistrictId,
          'village_id': _villageId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Update coordinate lokal untuk member aktif
          await _domisiliCubit.updateCoordinate(
            widget.nik,
            LatLng(double.parse(lat), double.parse(lng)),
          );

          if (mounted) {
            final String msg = responseData['message'] ?? 'Lokasi domisili keluarga berhasil diperbarui';
            final bool isPending = responseData['is_pending_alert'] == true;
            
            if (isPending) {
              MessageService.showInfoSnackBar(context, msg);
            } else {
              MessageService.showSuccessSnackBar(context, msg);
            }
          }

          // Refresh data
          await _loadData(forceRefresh: true);
        } else {
          throw Exception(responseData['message'] ?? 'Gagal menyimpan lokasi');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Tidak terotorisasi. Silakan login ulang.');
      } else {
        String errorMsg = 'Gagal menyimpan lokasi: ${response.statusCode}';
        try {
          final Map<String, dynamic> body = json.decode(response.body);
          if (body['message'] is String) errorMsg = body['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(
          context,
          'Gagal menyimpan lokasi: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onLocationSelected(LatLng position) {
    setState(() {
      _currentPosition = position;
      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
    });
    _reverseGeocodeAndFill(position);
  }

  Future<void> _reverseGeocodeAndFill(LatLng pos) async {
    try {
      final resp = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1&accept-language=id'),
        headers: {
          'User-Agent': 'LADIMAS App',
        },
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(resp.body);
        final display = body['display_name'] ?? '';
        setState(() {
          _addressController.text = display.toString();
        });
      }
    } catch (_) {}
  }

  void _onCenterChanged(LatLng center) {
    setState(() {
      _currentPosition = center;
      _latitudeController.text = center.latitude.toStringAsFixed(6);
      _longitudeController.text = center.longitude.toStringAsFixed(6);
    });
    _reverseGeocodeAndFill(center);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lokasi Domisili',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(forceRefresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<DomisiliCubit, DomisiliState>(
        bloc: _domisiliCubit,
        listener: (context, state) {
          if (state is DomisiliLoaded) {
            final member = state.member;

            // Set coordinates
            if (member.coordinate != null && member.coordinate!.isNotEmpty) {
              final coords = member.coordinate!.split(',');
              if (coords.length == 2) {
                try {
                  double lat = double.parse(coords[0]);
                  double lng = double.parse(coords[1]);
                  _currentPosition = LatLng(lat, lng);
                  _latitudeController.text = lat.toStringAsFixed(6);
                  _longitudeController.text = lng.toStringAsFixed(6);

                  // Move map to the position
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _mapController.move(_currentPosition, 16.0);
                    }
                  });
                } catch (e) {
                  // Ignore parse error
                }
              }
            } else {
              // Clear if null
              _latitudeController.clear();
              _longitudeController.clear();
            }

            // Set address (Strictly populate from member data)
            _addressController.text = member.address ?? '';

            // Set wilayah and load dropdown data in cascade
            if (member.provinceId != null) {
              _provinceId = member.provinceId;
              final pCode = _getCodeById(_provinces, _provinceId);
              if (pCode != null) {
                _loadDistricts(pCode).then((_) {
                  if (member.districtId != null) {
                    setState(() => _districtId = member.districtId);
                    final dCode = _getCodeById(_districts, _districtId);
                    if (dCode != null) {
                      _loadSubDistricts(dCode).then((_) {
                        if (member.subDistrictId != null) {
                          setState(() => _subDistrictId = member.subDistrictId);
                          final sCode =
                              _getCodeById(_subDistricts, _subDistrictId);
                          if (sCode != null) {
                            _loadVillages(sCode).then((_) {
                              if (member.villageId != null) {
                                setState(() => _villageId = member.villageId);
                              }
                            });
                          }
                        }
                      });
                    }
                  }
                });
              }
            } else {
              // Reset regions if no domicile record
              setState(() {
                _provinceId = null;
                _districtId = null;
                _subDistrictId = null;
                _villageId = null;
              });
            }
          }
 else if (state is DomisiliError) {
            MessageService.showErrorSnackBar(context, state.message);
          }
        },
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
                        _loadKKData();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Tampilkan loading untuk KK jika sedang mengambil data
          if (_isLoadingKK) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text('Sedang mengambil data ...'),
                ],
              ),
            );
          }

          if (state is DomisiliInitial || state is DomisiliLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (state is DomisiliError && state is! DomisiliLoaded) {
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
                      onPressed: () => _loadData(forceRefresh: true),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Get member data if available
          final member = state is DomisiliLoaded ? state.member : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info card
                if (member != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
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
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Search Location Section
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cari Lokasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchLocationController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Masukkan alamat (contoh: Jl. Sudirman, Jakarta)',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                onSubmitted: (_) => _searchLocation(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isSearching ? null : _searchLocation,
                              icon: _isSearching
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(_isSearching ? 'Mencari...' : 'Cari'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _useCurrentLocation,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Gunakan GPS'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Wilayah Input
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Wilayah',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _dropdownWilayah('Provinsi', _provinces, _provinceId, (value) async {
                          setState(() {
                            _provinceId = value;
                            _districtId = null;
                            _subDistrictId = null;
                            _villageId = null;
                            _districts = [];
                            _subDistricts = [];
                            _villages = [];
                          });
                          if (value != null) {
                            final code = _getCodeById(_provinces, value);
                            if (code != null) await _loadDistricts(code);
                          }
                        }),
                        const SizedBox(height: 12),
                        _dropdownWilayah('Kabupaten/Kota', _districts, _districtId, (value) async {
                          setState(() {
                            _districtId = value;
                            _subDistrictId = null;
                            _villageId = null;
                            _subDistricts = [];
                            _villages = [];
                          });
                          if (value != null) {
                            final code = _getCodeById(_districts, value);
                            if (code != null) await _loadSubDistricts(code);
                          }
                        }),
                        const SizedBox(height: 12),
                        _dropdownWilayah('Kecamatan', _subDistricts, _subDistrictId, (value) async {
                          setState(() {
                            _subDistrictId = value;
                            _villageId = null;
                            _villages = [];
                          });
                          if (value != null) {
                            final code = _getCodeById(_subDistricts, value);
                            if (code != null) await _loadVillages(code);
                          }
                        }),
                        const SizedBox(height: 12),
                        _dropdownWilayah('Desa', _villages, _villageId, (value) {
                          setState(() {
                            _villageId = value;
                          });
                        }),
                      ],
                    ),
                  ),
                ),

                // Address Input
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alamat Domisili',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Masukkan alamat lengkap domisili Anda',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map title
                const Text(
                  'Pilih Lokasi pada Peta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),

                const SizedBox(height: 10),

                // Map component
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        LocationMapComponent(
                          initialPosition: _currentPosition,
                          mode: MapMode.select,
                          onLocationSelected: _onLocationSelected,
                          mapController: _mapController,
                          showCurrentMarker: false,
                        ),
                        // Custom marker overlay
                        Positioned(
                          left: MediaQuery.of(context).size.width * 0.5 - 20,
                          top: 150 - 20,
                          child: GestureDetector(
                            onTap: () {
                              MessageService.showInfoSnackBar(
                                context,
                                'Lokasi yang dipilih: ${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)}',
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Coordinate Display
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Koordinat Lokasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latitudeController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                  prefixIcon: const Icon(Icons.location_on),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _longitudeController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                  prefixIcon: const Icon(Icons.location_on),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Koordinat akan otomatis terupdate saat Anda memilih lokasi pada peta atau mencari alamat',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'KIRIM PERMINTAAN PERUBAHAN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownWilayah(String label, List<Map<String, dynamic>> items, int? value, Function(int?)? onChanged) {
    // Normalisasi id
    final Set<int> seen = {};
    final normalized = items.map((e) => {
      'id': _toInt(e['id']) ?? _toInt(e['code']) ?? _toInt(e['value']),
      'label': (e['name'] ?? e['label'] ?? e['text'] ?? '').toString(),
    }).where((e) => e['id'] != null).where((e) => seen.add(e['id'] as int)).toList();
    
    final ids = normalized.map<int>((e) => e['id'] as int).toSet();
    final int? safeValue = (value != null && ids.contains(value)) ? value : null;
    
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: safeValue,
          hint: const Text('Pilih'),
          items: normalized.map((e) => DropdownMenuItem<int>(
            value: e['id'] as int,
            child: Text(e['label'] as String),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _searchLocationController.dispose();
    _mapEventSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
