import 'package:flutter/material.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ladimas/presentation/widgets/common/location_map_component.dart'
    show LocationMapComponent, MapMode;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

class ProfileEditPage extends StatefulWidget {
  final Penduduk penduduk;

  const ProfileEditPage({Key? key, required this.penduduk}) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  int _refreshKey = 0; // Key untuk memaksa rebuild
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();
  final _kkController = TextEditingController();
  final _jenisKelaminController = TextEditingController();
  final _umurController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  final _alamatController = TextEditingController();
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();
  final _provinsiController = TextEditingController();
  final _kabupatenController = TextEditingController();
  final _kecamatanController = TextEditingController();
  final _desaController = TextEditingController();

  bool _isLoading = false;
  bool _isRequestingApproval = false;
  Map<String, dynamic>? _currentData;

  // Data untuk dropdown
  List<Map<String, dynamic>> _familyMembers = [];
  List<Map<String, dynamic>> _bloodTypes = [];
  List<Map<String, dynamic>> _educationLevels = [];
  List<Map<String, dynamic>> _jobs = [];

  // Controller untuk dropdown
  String? _selectedNik;
  String? _selectedBloodType;
  String? _selectedEducation;
  String? _selectedJob;

  // Informasi Usaha
  final _usahaNamaController = TextEditingController();
  final _usahaKelompokController = TextEditingController();
  final _usahaAlamatController = TextEditingController();
  final _usahaTagLokasiController = TextEditingController();
  Map<String, dynamic>? _informasiUsaha;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _usahaFoto;
  final List<String> _kelompokUsahaOptions = const [
    'UMKM',
    'BUMDES',
    'Mandiri/Perseorangan',
    'KUB (Kelompok Usaha Bersama)',
    'Korporasi/Perusahaan',
  ];
  String? _selectedUsahaKelompok;
  final MapController _usahaMapController = MapController();
  LatLng _usahaPosition = const LatLng(-6.200000, 106.816666);
  bool _showUsahaDebug = false;
  final TextEditingController _usahaSearchController = TextEditingController();
  bool _isSearchingUsahaAddress = false;

  Map<String, dynamic> _composeInformasiUsahaPayload() {
    // Ambil nilai lama dari _informasiUsaha (hasil API) sebagai fallback
    final existing = _informasiUsaha ?? <String, dynamic>{};

    // Nama usaha, kelompok, alamat: pakai input terbaru jika ada, else pakai existing
    final String namaUsaha = _usahaNamaController.text.trim().isNotEmpty
        ? _usahaNamaController.text.trim()
        : (existing['nama_usaha']?.toString() ?? '');

    final String kelompokUsaha =
        (_selectedUsahaKelompok ?? _usahaKelompokController.text.trim())
                .isNotEmpty
            ? (_selectedUsahaKelompok ?? _usahaKelompokController.text.trim())
            : (existing['kelompok_usaha']?.toString() ?? '');

    final String alamatUsaha = _usahaAlamatController.text.trim().isNotEmpty
        ? _usahaAlamatController.text.trim()
        : (existing['alamat']?.toString() ?? '');

    // Tag lokasi string: pakai input jika ada, else existing
    String tagLokasi = _usahaTagLokasiController.text.trim().isNotEmpty
        ? _usahaTagLokasiController.text.trim()
        : (existing['tag_lokasi']?.toString() ?? '');

    // Tentukan lat/lng: dari input, atau existing tag_lat/tag_lng, atau parse dari tag_lokasi, atau posisi map saat ini
    double? lat;
    double? lng;
    if (tagLokasi.contains(',')) {
      final parts = tagLokasi.split(',');
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }
    }
    lat ??= (existing['tag_lat'] is num)
        ? (existing['tag_lat'] as num).toDouble()
        : double.tryParse(existing['tag_lat']?.toString() ?? '');
    lng ??= (existing['tag_lng'] is num)
        ? (existing['tag_lng'] as num).toDouble()
        : double.tryParse(existing['tag_lng']?.toString() ?? '');
    lat ??= _usahaPosition.latitude;
    lng ??= _usahaPosition.longitude;

    // IDs wilayah & KK: pakai _currentData jika ada, else fallback existing
    final dynamic provinceId =
        _currentData?['province_id'] ?? existing['province_id'];
    final dynamic districtId =
        _currentData?['district_id'] ?? existing['districts_id'];
    final dynamic subDistrictId =
        _currentData?['sub_district_id'] ?? existing['sub_districts_id'];
    final dynamic villageId =
        _currentData?['village_id'] ?? existing['villages_id'];
    final String kk = _kkController.text.trim().isNotEmpty
        ? _kkController.text.trim()
        : (_currentData?['kk']?.toString() ?? existing['kk']?.toString() ?? '');

    return {
      'nama_usaha': namaUsaha,
      'kelompok_usaha': kelompokUsaha,
      'alamat': alamatUsaha,
      'tag_lokasi': tagLokasi.isNotEmpty ? tagLokasi : '${lat},${lng}',
      'tag_lat': lat,
      'tag_lng': lng,
      'province_id': provinceId,
      'districts_id': districtId,
      'sub_districts_id': subDistrictId,
      'villages_id': villageId,
      'kk': kk,
      // Catatan: foto dikirim multipart (bukan JSON)
      'has_foto': _usahaFoto != null,
    };
  }

  bool _shouldSendInformasiUsaha(Map<String, dynamic> payload) {
    // Kirim jika ada nilai terisi pada salah satu field usaha
    final hasAnyInput =
        payload.values.any((v) => v != null && v.toString().trim().isNotEmpty);
    if (hasAnyInput) return true;
    // Atau bila ada foto dipilih
    if (_usahaFoto != null) return true;
    // Atau bila peta mengisi koordinat
    if (_usahaTagLokasiController.text.trim().isNotEmpty) return true;

    // Jika tidak ada input baru, cek perbedaan terhadap data awal
    if (_informasiUsaha != null) {
      String asStr(dynamic v) => v == null ? '' : v.toString();
      final currentNama = asStr(_informasiUsaha?['nama_usaha']);
      final currentKelompok = asStr(_informasiUsaha?['kelompok_usaha']);
      final currentAlamat = asStr(_informasiUsaha?['alamat']);
      final currentTag = asStr(_informasiUsaha?['tag_lokasi']);

      final formNama = asStr(_usahaNamaController.text.trim());
      final formKelompok =
          asStr(_selectedUsahaKelompok ?? _usahaKelompokController.text.trim());
      final formAlamat = asStr(_usahaAlamatController.text.trim());
      final formTag = asStr(_usahaTagLokasiController.text.trim());

      final changed = formNama != currentNama ||
          formKelompok != currentKelompok ||
          formAlamat != currentAlamat ||
          formTag != currentTag;
      if (changed) return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();

    // Populate form dengan data dari widget.penduduk sebagai fallback
    _nikController.text = widget.penduduk.nik;
    _nameController.text = widget.penduduk.name;
    _selectedNik = widget.penduduk.nik;

    print('Initial form data from widget.penduduk:'); // Debug
    print('NIK: ${widget.penduduk.nik}');
    print('Nama: ${widget.penduduk.name}');

    // Load data tambahan dari API menggunakan AuthRepository
    _loadCurrentData();
  }

  Widget _buildUsahaPhotoPreview() {
    String? _resolveUsahaPhotoUrl() {
      final rawUrl = _informasiUsaha?['foto_url']?.toString() ?? '';
      final rawPath = _informasiUsaha?['foto']?.toString() ?? '';
      String? url = rawUrl.isNotEmpty ? rawUrl : null;
      // Jika foto_url kosong tapi ada path, bangun dari STORAGE_URL
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

    final existingUrl = _resolveUsahaPhotoUrl();
    final hasPicked = _usahaFoto != null;

    if (!hasPicked && (existingUrl == null || existingUrl.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pratinjau Foto Usaha',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasPicked
                    ? Image.file(
                        File(_usahaFoto!.path),
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        existingUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white.withOpacity(0.85),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Ganti Foto',
                    icon: const Icon(Icons.edit, color: Color(0xFF4A47DC)),
                    onPressed: _pickUsahaPhoto,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _searchUsahaLocation() async {
    final query = _usahaSearchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearchingUsahaAddress = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=' +
              Uri.encodeComponent(query));
      final resp = await http.get(uri, headers: {
        'User-Agent': 'flutter-kependudukan/1.0 (+https://example.org)'
      }).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final List<dynamic> results = json.decode(resp.body);
        if (results.isNotEmpty) {
          final result = results.first;
          final lat = double.tryParse(result['lat']?.toString() ?? '');
          final lon = double.tryParse(result['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final pos = LatLng(lat, lon);
            setState(() {
              _usahaPosition = pos;
              _usahaTagLokasiController.text =
                  '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
              final display = result['display_name']?.toString();
              if ((display ?? '').isNotEmpty &&
                  _usahaAlamatController.text.trim().isEmpty) {
                _usahaAlamatController.text = display!;
              }
            });
            _usahaMapController.move(pos, 15.0);
            MessageService.showSuccessSnackBar(context, 'Lokasi ditemukan');
          }
        } else {
          MessageService.showInfoSnackBar(context, 'Lokasi tidak ditemukan');
        }
      } else {
        await _showErrorAlert(resp);
      }
    } catch (e) {
      if (mounted) {
        await _showErrorAlert(null,
            error: 'Error mencari lokasi: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSearchingUsahaAddress = false);
    }
  }

  Future<void> _reverseGeocodeUsaha(LatLng pos) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=' +
              Uri.encodeComponent(pos.latitude.toString()) +
              '&lon=' +
              Uri.encodeComponent(pos.longitude.toString()));
      final resp = await http.get(uri, headers: {
        'User-Agent': 'flutter-kependudukan/1.0 (+https://example.org)'
      }).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(resp.body);
        final display = body['display_name']?.toString() ?? '';
        setState(() {
          if (display.isNotEmpty) {
            _usahaAlamatController.text = display;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _setUsahaToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final current = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _usahaPosition = current;
        _usahaTagLokasiController.text =
            '${current.latitude.toStringAsFixed(6)},${current.longitude.toStringAsFixed(6)}';
      });
      _usahaMapController.move(current, 16.0);
      await _reverseGeocodeUsaha(current);
    } catch (e) {
      if (mounted) {
        await _showErrorAlert(null,
            error: 'Tidak bisa mengambil lokasi saat ini: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _kkController.dispose();
    _jenisKelaminController.dispose();
    _umurController.dispose();
    _tempatLahirController.dispose();
    _tanggalLahirController.dispose();
    _alamatController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _provinsiController.dispose();
    _kabupatenController.dispose();
    _kecamatanController.dispose();
    _desaController.dispose();
    _usahaNamaController.dispose();
    _usahaKelompokController.dispose();
    _usahaAlamatController.dispose();
    _usahaTagLokasiController.dispose();
    super.dispose();
  }

  Future<void> _pickUsahaPhoto() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _usahaFoto = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        await _showErrorAlert(null,
            error: 'Gagal memilih foto: ${e.toString()}');
      }
    }
  }

  Future<void> _loadCurrentData() async {
    setState(() => _isLoading = true);

    try {
      print('Loading data for NIK: ${widget.penduduk.nik}'); // Debug

      // Load biodata dan data keluarga dari API baru
      await _loadBiodataAndFamily();
    } catch (e) {
      print('Exception: $e'); // Debug
      await _showErrorAlert(null, error: 'Gagal memuat data: ${e.toString()}');
      setState(() {
        _currentData = {};
        _isLoading = false;
      });
      _populateFormFields();
    }
  }

  Future<void> _loadBiodataAndFamily() async {
    try {
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();
      if (rawToken == null || rawToken.isEmpty) return;

      String token = rawToken.contains('|') ? rawToken.split('|')[1] : rawToken;

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

          // Set current data
          setState(() {
            _currentData = data['biodata'] ?? {};
            _familyMembers =
                List<Map<String, dynamic>>.from(data['family_members'] ?? []);
            _informasiUsaha = data['informasi_usaha'];
            _jobs = List<Map<String, dynamic>>.from(data['jobs'] ?? []);
            _isLoading = false;
          });

          // Debug: print struktur data yang diterima
          print('=== DEBUG API RESPONSE ===');
          print('Full API response: $data');
          print('Biodata keys: ${_currentData?.keys.toList()}');
          print('Family members count: ${_familyMembers.length}');
          print('Jobs count: ${_jobs.length}');
          print('========================');

          // Tambahkan data user sendiri ke daftar keluarga jika belum ada
          if (_currentData != null && _currentData!.isNotEmpty) {
            final userNik = _currentData!['nik']?.toString();
            final userExists = _familyMembers
                .any((member) => member['nik']?.toString() == userNik);

            if (!userExists && userNik != null) {
              _familyMembers.insert(0, _currentData!);
            }
          }

          // Initialize dropdown options
          _initializeDropdownOptions();
          _populateFormFields();
        }
      } else {
        print('Failed to fetch /biodata: ${resp.statusCode} ${resp.body}');
        await _showErrorAlert(resp);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching /biodata: $e');
      await _showErrorAlert(null,
          error: 'Gagal memuat data biodata: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  void _initializeDropdownOptions() {
    // Initialize blood types - pastikan tidak ada duplikasi
    _bloodTypes = [
      {'id': '1', 'name': 'A'},
      {'id': '2', 'name': 'B'},
      {'id': '3', 'name': 'AB'},
      {'id': '4', 'name': 'O'},
      {'id': '5', 'name': 'A+'},
      {'id': '6', 'name': 'A-'},
      {'id': '7', 'name': 'B+'},
      {'id': '8', 'name': 'B-'},
      {'id': '9', 'name': 'AB+'},
      {'id': '10', 'name': 'AB-'},
      {'id': '11', 'name': 'O+'},
      {'id': '12', 'name': 'O-'},
      {'id': '13', 'name': 'Tidak Tahu'},
    ];

    // Initialize education levels - pastikan konsisten dengan string
    _educationLevels = [
      {'id': '1', 'name': 'Tidak/Belum Sekolah'},
      {'id': '2', 'name': 'Belum tamat SD/Sederajat'},
      {'id': '3', 'name': 'Tamat SD/Sederajat'},
      {'id': '4', 'name': 'SLTP/SMP/Sederajat'},
      {'id': '5', 'name': 'SLTA/SMA/Sederajat'},
      {'id': '6', 'name': 'Diploma I/II'},
      {'id': '7', 'name': 'Akademi/Diploma III/Sarjana Muda'},
      {'id': '8', 'name': 'Diploma IV/Strata I/Strata II'},
      {'id': '9', 'name': 'Strata III'},
      {'id': '10', 'name': 'Lainnya'},
    ];

    // Validasi tidak ada duplikasi
    _validateDropdownData();
  }

  void _validateDropdownData() {
    // Validasi blood types
    final bloodTypeIds = _bloodTypes.map((e) => e['id']).toList();
    final bloodTypeDuplicates = bloodTypeIds
        .where((id) => bloodTypeIds.indexOf(id) != bloodTypeIds.lastIndexOf(id))
        .toList();
    if (bloodTypeDuplicates.isNotEmpty) {
      print('Warning: Duplicate blood type IDs found: $bloodTypeDuplicates');
    }

    // Validasi education levels
    final educationIds = _educationLevels.map((e) => e['id']).toList();
    final educationDuplicates = educationIds
        .where((id) => educationIds.indexOf(id) != educationIds.lastIndexOf(id))
        .toList();
    if (educationDuplicates.isNotEmpty) {
      print('Warning: Duplicate education IDs found: $educationDuplicates');
    }

    // Validasi jobs
    final jobIds = _jobs.map((e) => e['id']?.toString()).toList();
    final jobDuplicates = jobIds
        .where((id) => jobIds.indexOf(id) != jobIds.lastIndexOf(id))
        .toList();
    if (jobDuplicates.isNotEmpty) {
      print('Warning: Duplicate job IDs found: $jobDuplicates');
    }
  }

  String? _validateAndSetDropdownValue(
      String? value, List<Map<String, dynamic>> options, String type) {
    if (value == null || value.isEmpty) {
      print('$type: No value provided, setting to null');
      return null;
    }

    print('$type: Searching for value: "$value"');
    print('$type: Value type: ${value.runtimeType}');
    print(
        '$type: Available options: ${options.map((e) => '${e['id']}: ${e['name']}').toList()}');

    // Cek apakah value ada dalam options berdasarkan ID
    final validIds = options.map((e) => e['id']?.toString()).toList();
    if (validIds.contains(value)) {
      print(
          '$type: Value "$value" found in options by ID, setting as selected');
      return value;
    }

    // Coba cari berdasarkan name (exact match)
    final exactMatch = options.firstWhere(
      (option) =>
          option['name']?.toString().toLowerCase() == value.toLowerCase(),
      orElse: () => {},
    );

    if (exactMatch.isNotEmpty && exactMatch['id'] != null) {
      final foundId = exactMatch['id'].toString();
      print('$type: Value "$value" matched by exact name, using ID: $foundId');
      return foundId;
    }

    // Coba cari berdasarkan partial match untuk blood type
    if (type == 'blood_type') {
      final partialMatch = options.firstWhere(
        (option) {
          final optionName = option['name']?.toString().toLowerCase() ?? '';
          return optionName.contains(value.toLowerCase()) ||
              value.toLowerCase().contains(optionName);
        },
        orElse: () => {},
      );

      if (partialMatch.isNotEmpty && partialMatch['id'] != null) {
        final foundId = partialMatch['id'].toString();
        print(
            '$type: Value "$value" matched by partial name, using ID: $foundId');
        return foundId;
      }
    }

    // Coba cari berdasarkan partial match untuk education
    if (type == 'education') {
      final partialMatch = options.firstWhere(
        (option) {
          final optionName = option['name']?.toString().toLowerCase() ?? '';
          final searchValue = value.toLowerCase();

          // Cek apakah ada kata kunci yang sama
          final optionWords = optionName.split(' ');
          final valueWords = searchValue.split(' ');

          for (String valueWord in valueWords) {
            if (valueWord.length > 2) {
              // Hanya kata yang lebih dari 2 karakter
              for (String optionWord in optionWords) {
                if (optionWord.contains(valueWord) ||
                    valueWord.contains(optionWord)) {
                  return true;
                }
              }
            }
          }
          return false;
        },
        orElse: () => {},
      );

      if (partialMatch.isNotEmpty && partialMatch['id'] != null) {
        final foundId = partialMatch['id'].toString();
        print(
            '$type: Value "$value" matched by partial education name, using ID: $foundId');
        return foundId;
      }
    }

    print('$type: Value "$value" not found in options, setting to null');
    return null;
  }

  String _getLocationValue(List<String> possibleKeys) {
    if (_currentData == null) return '';

    for (String key in possibleKeys) {
      if (key.contains('.')) {
        // Handle nested keys like 'province.name'
        final parts = key.split('.');
        dynamic value = _currentData;
        for (String part in parts) {
          if (value is Map<String, dynamic> && value.containsKey(part)) {
            value = value[part];
          } else {
            value = null;
            break;
          }
        }
        if (value != null && value.toString().isNotEmpty) {
          print('Found location value for $key: $value');
          return value.toString();
        }
      } else {
        // Handle direct keys
        if (_currentData!.containsKey(key) && _currentData![key] != null) {
          final value = _currentData![key];
          if (value.toString().isNotEmpty) {
            print('Found location value for $key: $value');
            return value.toString();
          }
        }
      }
    }

    print('No location value found for keys: $possibleKeys');
    return '';
  }

  Future<String> _getLocationName(String idKey, String nameKey) async {
    if (_currentData == null) return '';

    // Coba ambil nama langsung dulu
    final nameValue = _currentData![nameKey];
    if (nameValue != null && nameValue.toString().isNotEmpty) {
      print('Found location name for $nameKey: $nameValue');
      return nameValue.toString();
    }

    // Jika nama tidak ada, coba konversi dari ID menggunakan WilayahService
    final idValue = _currentData![idKey];
    if (idValue != null) {
      print('Found location ID for $idKey: $idValue, converting to name...');

      try {
        final wilayahService = WilayahService();
        Map<String, dynamic>? locationData;

        if (idKey == 'province_id') {
          locationData = await wilayahService.getProvince(idValue.toString());
        } else if (idKey == 'district_id') {
          locationData = await wilayahService.getDistrict(idValue.toString());
        } else if (idKey == 'sub_district_id') {
          locationData = await wilayahService.getSubDistrict(
              idValue.toString(), _currentData!['district_id']?.toString());
        } else if (idKey == 'village_id') {
          locationData = await wilayahService.getVillage(
              idValue.toString(),
              _currentData!['sub_district_id']?.toString(),
              _currentData!['district_id']?.toString());
        }

        if (locationData != null && locationData['name'] != null) {
          final name = locationData['name'].toString();
          print('Converted $idKey to name: $name');
          return name;
        }
      } catch (e) {
        print('Error converting $idKey to name: $e');
      }

      // Fallback ke ID jika konversi gagal
      return 'ID: $idValue';
    }

    print('No location data found for $idKey or $nameKey');
    return '';
  }

  void _clearAllFields() {
    print('Clearing all fields...');

    // Clear semua text controllers
    _nikController.clear();
    _nameController.clear();
    _kkController.clear();
    _jenisKelaminController.clear();
    _umurController.clear();
    _tempatLahirController.clear();
    _tanggalLahirController.clear();
    _alamatController.clear();
    _rtController.clear();
    _rwController.clear();
    _provinsiController.clear();
    _kabupatenController.clear();
    _kecamatanController.clear();
    _desaController.clear();

    // Reset dropdown values
    _selectedBloodType = null;
    _selectedEducation = null;
    _selectedJob = null;

    print('All fields cleared');
  }

  Future<void> _selectBirthDate() async {
    DateTime? selectedDate = DateTime.now();

    // Coba parse tanggal yang sudah ada
    if (_tanggalLahirController.text.isNotEmpty) {
      try {
        selectedDate = DateTime.parse(_tanggalLahirController.text);
      } catch (e) {
        // Jika gagal parse, gunakan tanggal sekarang
        selectedDate = DateTime.now();
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        // Pastikan format YYYY-MM-DD untuk kompatibilitas dengan server
        _tanggalLahirController.text = _formatDateForServer(picked);
      });
    }
  }

  String _formatDateForServer(DateTime date) {
    // Format tanggal ke YYYY-MM-DD untuk kompatibilitas dengan server
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String? _normalizeBirthDate(String? dateString) {
    if (dateString == null) return null;
    final raw = dateString.trim();
    if (raw.isEmpty) return null; // biarkan null jika kosong

    // Hilangkan bagian waktu jika ada (mis. "12/01/1990 00:00:00")
    final onlyDate = raw.split(' ').first;

    // Helper untuk aman parse int
    int? toInt(String s) => int.tryParse(s.trim());

    // Helper untuk bangun DateTime valid
    DateTime? buildDate(int? y, int? m, int? d) {
      if (y == null || m == null || d == null) return null;
      if (y < 1900) return null;
      if (m < 1 || m > 12) return null;
      if (d < 1 || d > 31) return null;
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }

    // Normalisasi pemisah ke dua mode: "/" atau "-"
    String s = onlyDate.replaceAll('.', '-');

    DateTime? parsedDate;

    // Format dengan "/"
    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 3) {
        // Jika bagian pertama 4 digit -> YYYY/MM/DD
        if (parts[0].length == 4) {
          parsedDate =
              buildDate(toInt(parts[0]), toInt(parts[1]), toInt(parts[2]));
        } else if (parts[2].length == 4) {
          // Else anggap DD/MM/YYYY
          parsedDate =
              buildDate(toInt(parts[2]), toInt(parts[1]), toInt(parts[0]));
        } else {
          // Heuristik: jika bagian kedua > 12 maka pasti DD/MM/YYYY
          final p1 = toInt(parts[0]);
          final p2 = toInt(parts[1]);
          final p3 = toInt(parts[2]);
          if (p2 != null && p2 > 12) {
            parsedDate = buildDate(p3, p2, p1);
          } else {
            // Default ke DD/MM/YYYY
            parsedDate = buildDate(p3, p2, p1);
          }
        }
      }
    }

    // Format dengan "-"
    if (parsedDate == null && s.contains('-')) {
      final parts = s.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          // YYYY-MM-DD
          parsedDate =
              buildDate(toInt(parts[0]), toInt(parts[1]), toInt(parts[2]));
        } else if (parts[2].length == 4) {
          // DD-MM-YYYY
          parsedDate =
              buildDate(toInt(parts[2]), toInt(parts[1]), toInt(parts[0]));
        } else {
          // Heuristik serupa
          final p1 = toInt(parts[0]);
          final p2 = toInt(parts[1]);
          final p3 = toInt(parts[2]);
          if (p2 != null && p2 > 12) {
            parsedDate = buildDate(p3, p2, p1);
          } else {
            parsedDate = buildDate(p3, p2, p1);
          }
        }
      }
    }

    // Coba parse ISO fallback
    if (parsedDate == null) {
      try {
        parsedDate = DateTime.parse(onlyDate);
      } catch (_) {
        parsedDate = null;
      }
    }

    // Validasi akhir dan formatkan
    if (parsedDate == null) return null;
    final now = DateTime.now();
    if (parsedDate.isAfter(now) || parsedDate.year < 1900) return null;

    return _formatDateForServer(parsedDate);
  }

  void _onNikChanged(String? selectedNik) async {
    if (selectedNik != null) {
      print('=== NIK CHANGED TO: $selectedNik ===');

      setState(() {
        _selectedNik = selectedNik;
        _isLoading = true;
        _currentData = null; // Reset current data
        _refreshKey++; // Increment refresh key untuk memaksa rebuild
      });

      try {
        // Load data lengkap untuk NIK yang dipilih
        await _loadMemberData(selectedNik);

        // Tampilkan pesan sukses
        if (mounted) {
          MessageService.showSuccessSnackBar(
              context, 'Data berhasil dimuat untuk NIK: $selectedNik');
        }
      } catch (e) {
        print('Error loading member data: $e');
        if (mounted) {
          MessageService.showErrorSnackBar(
              context, 'Gagal memuat data anggota keluarga');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _loadMemberData(String nik) async {
    print('Loading member data for NIK: $nik');

    try {
      final repository = GetIt.instance<AuthRepository>();
      final result = await repository.getPendudukDetail(nik);

      result.fold(
        (failure) async {
          print('Failed to load member data: ${failure.message}');
          // Fallback ke data dari family members
          await _fallbackToFamilyMemberData(nik);
        },
        (data) async {
          print('Data loaded successfully: $data');

          if (mounted) {
            setState(() {
              _currentData = data;
            });

            print('Set _currentData to: $_currentData');

            // Populate form fields
            await _populateFormFields();

            print('Form fields populated successfully');
          }
        },
      );
    } catch (e) {
      print('Error loading member data: $e');
      // Fallback ke data dari family members
      await _fallbackToFamilyMemberData(nik);
    }
  }

  Future<void> _fallbackToFamilyMemberData(String nik) async {
    // Cari data anggota keluarga yang dipilih dari _familyMembers
    final selectedMember = _familyMembers.firstWhere(
      (member) => member['nik']?.toString() == nik,
      orElse: () => {},
    );

    if (selectedMember.isNotEmpty) {
      setState(() {
        _currentData = selectedMember;
      });
      print('Using fallback family member data: $_currentData');
      await _populateFormFields();

      // Pastikan UI terupdate setelah populate form fields
      if (mounted) {
        print('Triggering setState after fallback populate form fields');
        setState(() {
          // Trigger rebuild untuk memastikan field terupdate
        });
        print('Fallback setState completed');
      }
    } else {
      MessageService.showErrorSnackBar(
          context, 'Data anggota keluarga tidak ditemukan');
    }
  }

  Future<void> _populateFormFields() async {
    print('=== POPULATING FORM FIELDS ===');
    print('Current data: $_currentData');
    print('Selected NIK: $_selectedNik');

    // Clear semua field terlebih dahulu
    _clearAllFields();

    // Populate dengan data dari API jika ada, fallback ke widget.penduduk
    final nikValue = _currentData?['nik']?.toString() ?? widget.penduduk.nik;
    final nameValue = _currentData?['full_name'] ??
        _currentData?['name'] ??
        widget.penduduk.name;
    final kkValue = _currentData?['kk']?.toString() ?? '';

    _nikController.text = nikValue;
    _nameController.text = nameValue;
    _kkController.text = kkValue;

    // Normalisasi gender untuk display
    final genderValue = _currentData?['gender'];
    String genderText = '';
    if (genderValue is int) {
      genderText = genderValue == 1 ? 'Laki-laki' : 'Perempuan';
    } else if (genderValue is String) {
      genderText = genderValue;
    }
    _jenisKelaminController.text = genderText;

    // Debug: print field values yang diisi
    print('=== FIELD VALUES BEING SET ===');
    print('NIK: "$nikValue" -> Controller: "${_nikController.text}"');
    print('Name: "$nameValue" -> Controller: "${_nameController.text}"');
    print('KK: "$kkValue" -> Controller: "${_kkController.text}"');
    print(
        'Gender: "$genderText" -> Controller: "${_jenisKelaminController.text}"');

    final ageValue = _currentData?['age']?.toString() ?? '';
    final birthPlaceValue = _currentData?['birth_place'] ?? '';
    final birthDateValue = _currentData?['birth_date'] ?? '';
    final addressValue = _currentData?['address'] ?? '';
    final rtValue = _currentData?['rt']?.toString() ?? '';
    final rwValue = _currentData?['rw']?.toString() ?? '';

    _umurController.text = ageValue;
    _tempatLahirController.text = birthPlaceValue;
    // Normalisasi tanggal lahir ke format YYYY-MM-DD untuk tampilan dan pengiriman
    final normalizedBirthForField = _normalizeBirthDate(
          birthDateValue is String ? birthDateValue : birthDateValue.toString(),
        ) ??
        (birthDateValue is String
            ? birthDateValue.replaceAll('/', '-').trim()
            : birthDateValue.toString().replaceAll('/', '-').trim());
    _tanggalLahirController.text = normalizedBirthForField;
    _alamatController.text = addressValue;
    _rtController.text = rtValue;
    _rwController.text = rwValue;

    print('Age: "$ageValue" -> Controller: "${_umurController.text}"');
    print(
        'Birth Place: "$birthPlaceValue" -> Controller: "${_tempatLahirController.text}"');
    print(
        'Birth Date: "$birthDateValue" -> Controller: "${_tanggalLahirController.text}"');
    print(
        'Address: "$addressValue" -> Controller: "${_alamatController.text}"');
    print('RT: "$rtValue" -> Controller: "${_rtController.text}"');
    print('RW: "$rwValue" -> Controller: "${_rwController.text}"');
    // Field lokasi - ambil dari ID dan konversi ke nama (async)
    _provinsiController.text =
        await _getLocationName('province_id', 'province_name');
    _kabupatenController.text =
        await _getLocationName('district_id', 'district_name');
    _kecamatanController.text =
        await _getLocationName('sub_district_id', 'sub_district_name');
    _desaController.text = await _getLocationName('village_id', 'village_name');

    print('Province: ${_provinsiController.text}');
    print('District: ${_kabupatenController.text}');
    print('Sub District: ${_kecamatanController.text}');
    print('Village: ${_desaController.text}');

    // Set dropdown values - coba berbagai kemungkinan field name
    final bloodTypeValue = _currentData?['blood_type']?.toString() ??
        _currentData?['golongan_darah']?.toString() ??
        _currentData?['bloodtype']?.toString() ??
        _currentData?['blood_group']?.toString() ??
        _currentData?['gol_darah']?.toString();
    final educationValue = _currentData?['education_status']?.toString() ??
        _currentData?['pendidikan']?.toString() ??
        _currentData?['education']?.toString() ??
        _currentData?['pendidikan_terakhir']?.toString() ??
        _currentData?['education_level']?.toString() ??
        _currentData?['pendidikan_akhir']?.toString();
    final jobValue = _currentData?['job_type_id']?.toString() ??
        _currentData?['pekerjaan_id']?.toString() ??
        _currentData?['job_id']?.toString() ??
        _currentData?['pekerjaan']?.toString() ??
        _currentData?['occupation']?.toString() ??
        _currentData?['work']?.toString();

    print('Raw Blood Type Value: $bloodTypeValue');
    print('Raw Education Value: $educationValue');
    print('Raw Job Value: $jobValue');

    // Debug: print nilai asli dari API
    print('=== RAW API VALUES ===');
    print(
        'API blood_type: ${_currentData?['blood_type']} (${_currentData?['blood_type'].runtimeType})');
    print(
        'API education_status: ${_currentData?['education_status']} (${_currentData?['education_status'].runtimeType})');
    print(
        'API job_type_id: ${_currentData?['job_type_id']} (${_currentData?['job_type_id'].runtimeType})');
    print('=====================');

    // Debug: print semua field yang tersedia dari API
    print('=== ALL API FIELDS ===');
    if (_currentData != null) {
      _currentData!.forEach((key, value) {
        print('$key: $value (${value.runtimeType})');
      });
    }
    print('=====================');

    // Validasi dan set dropdown values
    _selectedBloodType =
        _validateAndSetDropdownValue(bloodTypeValue, _bloodTypes, 'blood_type');
    _selectedEducation = _validateAndSetDropdownValue(
        educationValue, _educationLevels, 'education');
    _selectedJob = _validateAndSetDropdownValue(jobValue, _jobs, 'job');

    // Debug: print dropdown options yang tersedia
    print('=== DROPDOWN OPTIONS ===');
    print(
        'Blood Types: ${_bloodTypes.map((e) => '${e['id']}: ${e['name']}').toList()}');
    print(
        'Education Levels: ${_educationLevels.map((e) => '${e['id']}: ${e['name']}').toList()}');
    print(
        'Jobs: ${_jobs.map((e) => '${e['id']}: ${e['name'] ?? e['job_name']}').toList()}');
    print('========================');

    print('Validated Blood Type: $_selectedBloodType');
    print('Validated Education: $_selectedEducation');
    print('Validated Job: $_selectedJob');

    // JANGAN set ke nilai default jika tidak ada data dari API
    // Biarkan null agar user bisa memilih sendiri
    print('Final dropdown values after validation:');
    print('Blood Type: $_selectedBloodType');
    print('Education: $_selectedEducation');
    print('Job: $_selectedJob');

    // Final setState untuk memastikan semua field terupdate
    if (mounted) {
      print('Triggering final setState after all fields populated');
      setState(() {
        // Final rebuild untuk memastikan semua field terupdate
        _refreshKey++; // Increment refresh key lagi untuk memaksa rebuild
      });
      print('Final setState completed with refresh key: $_refreshKey');

      // Debug: print final dropdown values
      print('=== FINAL DROPDOWN VALUES ===');
      print('Blood Type: $_selectedBloodType');
      print('Education: $_selectedEducation');
      print('Job: $_selectedJob');
      print('============================');
    }

    // Validasi bahwa nilai yang dipilih ada di daftar dropdown
    if (_selectedBloodType != null &&
        !_bloodTypes.any((item) => item['id'] == _selectedBloodType)) {
      print('Invalid blood type: $_selectedBloodType, resetting to null');
      _selectedBloodType = null;
    }
    if (_selectedEducation != null &&
        !_educationLevels.any((item) => item['id'] == _selectedEducation)) {
      print('Invalid education: $_selectedEducation, resetting to null');
      _selectedEducation = null;
    }
    if (_selectedJob != null &&
        !_jobs.any((item) => item['id']?.toString() == _selectedJob)) {
      print('Invalid job: $_selectedJob, resetting to null');
      _selectedJob = null;
    }

    // JANGAN set default values - biarkan null jika tidak ada data dari API
    // User bisa memilih sendiri jika diperlukan

    print('Form fields populated:'); // Debug
    print('NIK: ${_nikController.text}');
    print('Nama: ${_nameController.text}');
    print('KK: ${_kkController.text}');
    print('Jenis Kelamin: ${_jenisKelaminController.text}');
    print('Umur: ${_umurController.text}');
    print('Tempat Lahir: ${_tempatLahirController.text}');
    print('Tanggal Lahir: ${_tanggalLahirController.text}');
    print('Alamat: ${_alamatController.text}');
    print('RT: ${_rtController.text}');
    print('RW: ${_rwController.text}');
    print('Provinsi: ${_provinsiController.text}');
    print('Kabupaten: ${_kabupatenController.text}');
    print('Kecamatan: ${_kecamatanController.text}');
    print('Desa: ${_desaController.text}');
    print('Blood Type: $_selectedBloodType');
    print('Education: $_selectedEducation');
    print('Job: $_selectedJob');

    // Pastikan form ter-update
    setState(() {});

    // Prefill Informasi Usaha jika tersedia
    if (_informasiUsaha != null) {
      _usahaNamaController.text =
          _informasiUsaha?['nama_usaha']?.toString() ?? '';
      _usahaKelompokController.text =
          _informasiUsaha?['kelompok_usaha']?.toString() ?? '';
      final kel = _informasiUsaha?['kelompok_usaha']?.toString();
      if (kel != null && _kelompokUsahaOptions.contains(kel)) {
        _selectedUsahaKelompok = kel;
      } else {
        _selectedUsahaKelompok = null;
      }
      _usahaAlamatController.text =
          _informasiUsaha?['alamat']?.toString() ?? '';
      final lat = _informasiUsaha?['tag_lat']?.toString();
      final lng = _informasiUsaha?['tag_lng']?.toString();
      final tag = _informasiUsaha?['tag_lokasi']?.toString();
      _usahaTagLokasiController.text =
          (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty)
              ? '$lat,$lng'
              : (tag ?? '');

      // Set posisi peta jika ada koordinat
      final latNum = double.tryParse(lat ?? '');
      final lngNum = double.tryParse(lng ?? '');
      if (latNum != null && lngNum != null) {
        _usahaPosition = LatLng(latNum, lngNum);
      }
    }
  }

  Future<void> _requestAdminApproval() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRequestingApproval = true);

    try {
      // Ambil token dari storage (format bisa "id|token" dari Sanctum)
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();
      if (rawToken == null || rawToken.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      String token = rawToken;
      if (rawToken.contains('|')) {
        final parts = rawToken.split('|');
        if (parts.length > 1) {
          token = parts[1];
        }
      }

      // Gunakan NIK user sendiri (tanpa pemilihan NIK)
      final nikToUpdate =
          _currentData?['nik']?.toString() ?? widget.penduduk.nik;

      // Validasi minimal sisi-klien sesuai API baru
      final normalizedGender = _normalizeGender(_jenisKelaminController.text);
      if (normalizedGender == null) {
        throw Exception("Jenis kelamin harus 'Laki-laki' atau 'Perempuan'.");
      }

      // Validasi tanggal lahir
      final birthDateValue = _tanggalLahirController.text.isNotEmpty
          ? _tanggalLahirController.text
          : (_currentData?['birth_date']?.toString() ?? '');
      String? normalizedBirthDate = _normalizeBirthDate(birthDateValue);
      // Jika parsing gagal, coba fallback sederhana: ganti "/" menjadi "-"
      normalizedBirthDate ??= birthDateValue.isNotEmpty
          ? birthDateValue.replaceAll('/', '-').trim()
          : null;
      // Validasi akhir: jika masih bukan format yang bisa diterima, lempar error
      if (birthDateValue.isNotEmpty &&
          _normalizeBirthDate(normalizedBirthDate) == null) {
        throw Exception(
            "Format tanggal lahir tidak valid. Gunakan format YYYY-MM-DD (contoh: 1990-01-15).");
      }

      // Debug: pastikan NIK yang digunakan
      print('=== VALIDASI NIK ===');
      print('Selected NIK: $_selectedNik');
      print('Current Data NIK: ${_currentData?['nik']}');
      print('Form NIK: ${_nikController.text}');
      print('===================');

      // Tidak perlu validasi konsistensi NIK terpilih

      // Pastikan data lokasi tersedia dari _currentData
      if (_currentData?['province_id'] == null ||
          _currentData?['district_id'] == null ||
          _currentData?['sub_district_id'] == null ||
          _currentData?['village_id'] == null) {
        throw Exception(
            'Data wilayah tidak lengkap. Muat ulang data profil dan coba lagi.');
      }

      final Map<String, dynamic> payload = {
        // NIK yang akan diupdate
        'nik': nikToUpdate,

        // Field yang bisa diubah user - gunakan nilai dari form (sesuai NIK yang dipilih)
        'full_name': _nameController.text.isNotEmpty
            ? _nameController.text
            : (_currentData?['full_name'] ?? ''),
        'kk': _kkController.text.isNotEmpty
            ? _kkController.text
            : (_currentData?['kk'] ?? ''),
        'gender': normalizedGender,
        'age': _umurController.text.isNotEmpty
            ? int.tryParse(_umurController.text)
            : (_currentData?['age'] ?? null),
        'birth_place': _tempatLahirController.text.isNotEmpty
            ? _tempatLahirController.text
            : (_currentData?['birth_place'] ?? ''),
        'birth_date': normalizedBirthDate,
        'address': _alamatController.text.isNotEmpty
            ? _alamatController.text
            : (_currentData?['address'] ?? ''),
        'rt': _rtController.text.isNotEmpty
            ? _rtController.text
            : (_currentData?['rt'] ?? ''),
        'rw': _rwController.text.isNotEmpty
            ? _rwController.text
            : (_currentData?['rw'] ?? ''),

        // Field lokasi - selalu gunakan nilai asli dari API (tidak bisa diubah user)
        'province_id': _currentData?['province_id'] ?? 0,
        'district_id': _currentData?['district_id'] ?? 0,
        'sub_district_id': _currentData?['sub_district_id'] ?? 0,
        'village_id': _currentData?['village_id'] ?? 0,

        // Field baru yang bisa diubah - gunakan nilai yang dipilih user atau nilai asli
        'blood_type': _selectedBloodType ?? (_currentData?['blood_type'] ?? ''),
        'education_status':
            _selectedEducation ?? (_currentData?['education_status'] ?? ''),
        'job_type_id': _selectedJob != null
            ? int.tryParse(_selectedJob!)
            : (_currentData?['job_type_id'] ?? null),
      };

      // Sertakan informasi_usaha jika ada input (API baru hanya membaca nested ini)
      final informasiUsahaPayload = _composeInformasiUsahaPayload();
      if (_shouldSendInformasiUsaha(informasiUsahaPayload)) {
        payload['informasi_usaha'] = informasiUsahaPayload;
      }

      // Debug: tampilkan payload yang akan dikirim
      print('=== PAYLOAD YANG AKAN DIKIRIM ===');
      print('Nik yang digunakan: $nikToUpdate');
      print('Current Data: $_currentData');
      print('Selected Blood Type: $_selectedBloodType');
      print('Selected Education: $_selectedEducation');
      print('Selected Job: $_selectedJob');
      print('Payload: $payload');
      if (_showUsahaDebug && payload['informasi_usaha'] != null) {
        print('=== DEBUG RINCI INFORMASI USAHA ===');
        final iu = Map<String, dynamic>.from(payload['informasi_usaha']);
        iu.forEach((k, v) => print('  $k: $v'));
        print('  foto_dipilih: ${_usahaFoto != null}');
        print('===================================');
      }
      print('Informasi Usaha: ${payload['informasi_usaha']}');
      print('===============================');

      // Debug: validasi data yang akan dikirim sesuai NIK yang dipilih
      print('=== VALIDASI DATA SESUAI NIK ===');
      print('NIK yang akan diupdate: ${payload['nik']}');
      print('Nama yang akan diupdate: ${payload['full_name']}');
      print('KK yang akan diupdate: ${payload['kk']}');
      print('Golongan darah yang akan diupdate: ${payload['blood_type']}');
      print('Pendidikan yang akan diupdate: ${payload['education_status']}');
      print('Pekerjaan yang akan diupdate: ${payload['job_type_id']}');
      print('=================================');

      // Debug: pastikan data yang dikirim sesuai dengan NIK yang dipilih
      print('=== VERIFIKASI DATA NIK ===');
      print('NIK: $nikToUpdate');
      print('Current Data NIK: ${_currentData?['nik']}');
      print('Current Data Name: ${_currentData?['full_name']}');
      print('Current Data Age: ${_currentData?['age']}');
      print('Current Data Birth Date: ${_currentData?['birth_date']}');
      print('Current Data Blood Type: ${_currentData?['blood_type']}');
      print('Current Data Education: ${_currentData?['education_status']}');
      print('Current Data Job: ${_currentData?['job_type_id']}');
      print('=========================================');

      // Debug khusus untuk gender
      print('=== DEBUG GENDER ===');
      print('Input gender: "${_jenisKelaminController.text}"');
      print('Normalized gender: "$normalizedGender"');
      print('Expected by API: "Laki-laki" atau "Perempuan"');
      print('===================');

      // Debug: validasi payload sesuai API
      print('=== VALIDASI PAYLOAD ===');
      print('full_name: "${payload['full_name']}" (required, max:255)');
      print(
          'gender: "${payload['gender']}" (required, in:Laki-laki,Perempuan)');
      print('birth_date: "${payload['birth_date']}" (format: YYYY-MM-DD)');
      print('province_id: ${payload['province_id']} (required, numeric)');
      print('district_id: ${payload['district_id']} (required, numeric)');
      print(
          'sub_district_id: ${payload['sub_district_id']} (required, numeric)');
      print('village_id: ${payload['village_id']} (required, numeric)');
      print('================================');

      // Debug: pastikan semua field terkirim
      print('=== COMPLETE PAYLOAD CHECK ===');
      final requiredFields = [
        'full_name',
        'gender',
        'province_id',
        'district_id',
        'sub_district_id',
        'village_id'
      ];
      final optionalFields = [
        'kk',
        'age',
        'birth_place',
        'birth_date',
        'address',
        'rt',
        'rw'
      ];

      for (String field in requiredFields) {
        final value = payload[field];
        print(
            '$field: $value (${value != null && value != '' ? 'OK' : 'MISSING'})');
      }

      for (String field in optionalFields) {
        final value = payload[field];
        print('$field: $value (${value != null ? 'OK' : 'NULL'})');
      }
      print('================================');

      // Debug: bandingkan setiap field untuk memastikan ada perubahan
      print('=== PERBANDINGAN FIELD ===');
      final fieldsToCompare = [
        'full_name',
        'kk',
        'gender',
        'age',
        'birth_place',
        'birth_date',
        'address',
        'rt',
        'rw'
      ];
      bool hasChanges = false;

      for (String field in fieldsToCompare) {
        final payloadValue = payload[field];
        final currentValue = _currentData?[field];
        final isDifferent = payloadValue != currentValue;

        print('$field:');
        print('  Payload: "$payloadValue"');
        print('  Current: "$currentValue"');
        print('  Different: $isDifferent');
        print('');

        if (isDifferent) hasChanges = true;
      }

      print('Has Changes: $hasChanges');
      print('================================');

      http.Response response;
      if (_usahaFoto != null) {
        // Kirim sebagai multipart bila ada foto usaha
        final uri =
            Uri.parse('${AppConstants.authApiUrl}/biodata/request-update');
        final req = http.MultipartRequest('POST', uri);
        req.headers['Accept'] = 'application/json';
        req.headers['Authorization'] = 'Bearer $token';
        req.headers['X-API-Key'] = AppConstants.apiKey;

        // Fields utama (semua sebagai string)
        payload.forEach((key, value) {
          if (key == 'informasi_usaha')
            return; // sisihkan nested, kirim terpisah
          if (value != null) {
            req.fields[key] = value.toString();
          }
        });

        // Nested informasi_usaha kirim sebagai array fields
        if (payload['informasi_usaha'] is Map) {
          final iu = Map<String, dynamic>.from(payload['informasi_usaha']);
          iu.forEach((k, v) {
            if (v != null) req.fields['informasi_usaha[$k]'] = v.toString();
          });
        }

        // Lampirkan file sesuai nama field yang diharapkan backend API baru: informasi_usaha_foto
        final file = File(_usahaFoto!.path);
        final fileName = _usahaFoto!.name;
        String ext = '';
        if (fileName.contains('.')) {
          ext = fileName.split('.').last.toLowerCase();
        }
        MediaType mediaType;
        switch (ext) {
          case 'png':
            mediaType = MediaType('image', 'png');
            break;
          case 'jpg':
          case 'jpeg':
            mediaType = MediaType('image', 'jpeg');
            break;
          case 'webp':
            mediaType = MediaType('image', 'webp');
            break;
          default:
            mediaType = MediaType('application', 'octet-stream');
        }
        req.files.add(await http.MultipartFile.fromPath(
          'informasi_usaha_foto',
          file.path,
          filename: fileName,
          contentType: mediaType,
        ));

        final streamed = await req.send();
        response = await http.Response.fromStream(streamed);
      } else {
        // Tanpa foto: kirim JSON
        response = await http.post(
          Uri.parse('${AppConstants.authApiUrl}/biodata/request-update'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-API-Key': AppConstants.apiKey,
          },
          body: json.encode(payload),
        );
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String msg = responseData['message'] ?? 'Permintaan perubahan data telah dikirim ke admin desa. Silakan tunggu persetujuan.';
        final bool isPending = responseData['is_pending_alert'] == true;

        if (mounted) {
          if (isPending) {
            MessageService.showInfoSnackBar(context, msg);
          } else {
            MessageService.showSuccessSnackBar(context, msg);
          }
        }
        Navigator.pop(context);
      } else {
        // Tampilkan alert error yang detail
        await _showErrorAlert(response);
      }
    } catch (e) {
      await _showErrorAlert(null, error: e.toString());
    } finally {
      setState(() => _isRequestingApproval = false);
    }
  }

  Future<void> _showErrorAlert(http.Response? response, {String? error}) async {
    String title = 'Terjadi Kesalahan';
    String message = 'Gagal mengirim permintaan perubahan data.';
    List<String> details = [];
    String actionText = 'Tutup';

    if (response != null) {
      // Error dari server
      title = 'Error Server (${response.statusCode})';

      try {
        final Map<String, dynamic> body = json.decode(response.body);

        // Ambil pesan error utama
        final mainMessage = body['message'] ??
            body['error'] ??
            body['status'] ??
            'Terjadi kesalahan pada server';

        message = mainMessage.toString();

        // Ambil detail error validasi jika ada
        if (response.statusCode == 422 && body['errors'] != null) {
          final errors = body['errors'];
          if (errors is Map<String, dynamic>) {
            title = 'Validasi Gagal';
            message = 'Data yang dimasukkan tidak valid:';
            details.clear();

            errors.forEach((field, fieldErrors) {
              if (fieldErrors is List) {
                for (var error in fieldErrors) {
                  details.add('• $field: ${error.toString()}');
                }
              } else {
                details.add('• $field: ${fieldErrors.toString()}');
              }
            });
          }
        } else if (response.statusCode == 401) {
          title = 'Sesi Berakhir';
          message = 'Sesi Anda telah berakhir. Silakan login kembali.';
          actionText = 'Login Ulang';
        } else if (response.statusCode == 403) {
          title = 'Akses Ditolak';
          message = 'Anda tidak memiliki izin untuk melakukan aksi ini.';
        } else if (response.statusCode == 500) {
          title = 'Error Server Internal';
          message = 'Terjadi kesalahan pada server. Silakan coba lagi nanti.';
        } else if (response.statusCode == 502 || response.statusCode == 503) {
          title = 'Server Tidak Tersedia';
          message =
              'Server sedang dalam perawatan atau tidak dapat diakses. Silakan coba lagi nanti.';
        }

        // Debug: tampilkan response body untuk analisis
        print('=== RESPONSE ERROR ===');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        print('=====================');
      } catch (e) {
        message = 'Gagal mengirim permintaan: ${response.statusCode}';
        details.add('Response body tidak dapat diparse: ${e.toString()}');
      }
    } else if (error != null) {
      // Error dari exception
      if (error.contains('Format tanggal lahir tidak valid')) {
        title = 'Format Tanggal Salah';
        message = 'Format tanggal lahir tidak valid.';
        details.add('Gunakan format YYYY-MM-DD (contoh: 1990-01-15)');
      } else if (error.contains('Jenis kelamin harus')) {
        title = 'Jenis Kelamin Salah';
        message = 'Jenis kelamin tidak valid.';
        details.add('Pilih "Laki-laki" atau "Perempuan"');
      } else if (error.contains('Data wilayah tidak lengkap')) {
        title = 'Data Wilayah Tidak Lengkap';
        message = 'Data wilayah tidak lengkap.';
        details.add('Muat ulang data profil dan coba lagi');
      } else if (error.contains('Token tidak ditemukan')) {
        title = 'Sesi Berakhir';
        message = 'Sesi Anda telah berakhir.';
        details.add('Silakan login kembali');
        actionText = 'Login Ulang';
      } else if (error.contains('SocketException') ||
          error.contains('HandshakeException')) {
        title = 'Koneksi Gagal';
        message = 'Tidak dapat terhubung ke server.';
        details.add('Periksa koneksi internet Anda');
        details.add('Pastikan server dapat diakses');
      } else if (error.contains('TimeoutException')) {
        title = 'Timeout';
        message = 'Permintaan memakan waktu terlalu lama.';
        details.add('Periksa koneksi internet Anda');
        details.add('Coba lagi nanti');
      } else {
        message = error;
      }
    }

    // Tampilkan dialog error
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.red[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Detail Error:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...details.map((detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tips: Pastikan semua data sudah diisi dengan benar dan koneksi internet stabil.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (actionText == 'Login Ulang') ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Implement logout and redirect to login
                  MessageService.showInfoSnackBar(
                      context, 'Fitur login ulang akan segera tersedia');
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Implement logout and redirect to login
                  MessageService.showInfoSnackBar(
                      context, 'Fitur login ulang akan segera tersedia');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Login Ulang'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A47DC),
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ],
          ],
        );
      },
    );
  }

  String? _normalizeGender(String input) {
    final value = input.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'laki-laki' ||
        value == 'laki laki' ||
        value == 'l' ||
        value == 'male' ||
        value == 'pria') {
      return 'Laki-laki'; // Sesuaikan dengan validasi API
    }
    if (value == 'perempuan' ||
        value == 'p' ||
        value == 'female' ||
        value == 'wanita') {
      return 'Perempuan';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4A47DC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: KeyedSubtree(
                  key: ValueKey(_refreshKey),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Pribadi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A47DC),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tanpa dropdown NIK (otomatis pakai NIK sendiri)
                      const SizedBox.shrink(),

                      // Nama Lengkap (Readonly)
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        enabled: false,
                      ),

                      // KK (Readonly)
                      _buildTextField(
                        controller: _kkController,
                        label: 'Nomor Kartu Keluarga (KK)',
                        enabled: false,
                      ),

                      // Jenis Kelamin (Readonly)
                      _buildTextField(
                        controller: _jenisKelaminController,
                        label: 'Jenis Kelamin',
                        enabled: false,
                      ),

                      // Umur (Readonly)
                      _buildTextField(
                        controller: _umurController,
                        label: 'Umur',
                        keyboardType: TextInputType.number,
                        enabled: false,
                      ),

                      // Tempat Lahir (Readonly)
                      _buildTextField(
                        controller: _tempatLahirController,
                        label: 'Tempat Lahir',
                        enabled: false,
                      ),

                      // Tanggal Lahir (Readonly)
                      _buildTextField(
                        controller: _tanggalLahirController,
                        label: 'Tanggal Lahir (YYYY-MM-DD)',
                        enabled: false,
                      ),

                      // Alamat (Readonly)
                      _buildTextField(
                        controller: _alamatController,
                        label: 'Alamat',
                        maxLines: 3,
                        enabled: false,
                      ),

                      // RT (Readonly)
                      _buildTextField(
                        controller: _rtController,
                        label: 'RT',
                        enabled: false,
                      ),

                      // RW (Readonly)
                      _buildTextField(
                        controller: _rwController,
                        label: 'RW',
                        enabled: false,
                      ),

                      // Provinsi (Readonly)
                      _buildTextField(
                        controller: _provinsiController,
                        label: 'Provinsi',
                        enabled: false,
                      ),

                      // Kabupaten (Readonly)
                      _buildTextField(
                        controller: _kabupatenController,
                        label: 'Kabupaten',
                        enabled: false,
                      ),

                      // Kecamatan (Readonly)
                      _buildTextField(
                        controller: _kecamatanController,
                        label: 'Kecamatan',
                        enabled: false,
                      ),

                      // Desa (Readonly)
                      _buildTextField(
                        controller: _desaController,
                        label: 'Desa',
                        enabled: false,
                      ),

                      // Spacing sebelum field yang ditampilkan berikutnya
                      const SizedBox(height: 20),

                      // Golongan Darah
                      _buildBloodTypeDropdown(),

                      // Pendidikan Terakhir
                      _buildEducationDropdown(),

                      // Pekerjaan
                      _buildJobDropdown(),

                      const SizedBox(height: 16),

                      const Text(
                        'Informasi Usaha (Opsional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A47DC),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _usahaNamaController,
                        label: 'Nama Usaha',
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedUsahaKelompok,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide:
                                BorderSide(color: Color(0xFF4A47DC), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          labelText: 'Kelompok Usaha',
                        ),
                        items: _kelompokUsahaOptions
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt,
                                  child: Text(opt,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedUsahaKelompok = val;
                            _usahaKelompokController.text = val ?? '';
                          });
                        },
                        // Buat opsional: hanya validasi jika seluruh bagian Informasi Usaha memang diwajibkan.
                        // Untuk sekarang, biarkan null agar user bisa ubah satu field saja (misal nama_usaha).
                        validator: (_) => null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _usahaAlamatController,
                        label: 'Alamat Usaha',
                        maxLines: 3,
                      ),
                      // Search bar untuk peta (seperti di Asset)
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usahaSearchController,
                              decoration: InputDecoration(
                                hintText: 'Cari lokasi (jalan, desa, dst)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                              onSubmitted: (_) => _searchUsahaLocation(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSearchingUsahaAddress
                                  ? null
                                  : _searchUsahaLocation,
                              icon: _isSearchingUsahaAddress
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.search),
                              label: const Text('Cari'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A47DC),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: OutlinedButton(
                              onPressed: _setUsahaToCurrentLocation,
                              style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero),
                              child: const Icon(Icons.my_location),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      LocationMapComponent(
                        initialPosition: _usahaPosition,
                        mode: MapMode.select,
                        mapController: _usahaMapController,
                        height: 220,
                        onLocationSelected: (pos) {
                          setState(() {
                            _usahaPosition = pos;
                            _usahaTagLokasiController.text =
                                '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
                          });
                          _reverseGeocodeUsaha(pos);
                        },
                      ),

                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _usahaTagLokasiController,
                        label: 'Tag Lokasi (lat,lng) atau alamat singkat',
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickUsahaPhoto,
                              icon: const Icon(Icons.photo_library),
                              label: Text(_usahaFoto == null
                                  ? 'Pilih Foto Usaha (opsional)'
                                  : 'Ganti Foto: ${_usahaFoto!.name}'),
                            ),
                          ),
                        ],
                      ),

                      _buildUsahaPhotoPreview(),

                      const SizedBox(height: 30),

                      // Tombol Request Approval
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isRequestingApproval
                              ? null
                              : _requestAdminApproval,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A47DC),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isRequestingApproval
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Minta Persetujuan Admin',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Informasi
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Perubahan data akan diproses setelah mendapat persetujuan dari admin desa.',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('${label}_$_refreshKey'),
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4A47DC), width: 2),
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildNikDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Anggota Keluarga',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedNik,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF4A47DC), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _familyMembers.map((member) {
              return DropdownMenuItem<String>(
                value: member['nik']?.toString(),
                child: Container(
                  width: double.infinity,
                  child: Text(
                    '${member['nik']} - ${member['full_name'] ?? member['name'] ?? 'N/A'}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
            onChanged: _onNikChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Pilih anggota keluarga';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Golongan Darah',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBloodType,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF4A47DC), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _bloodTypes.map((bloodType) {
              return DropdownMenuItem<String>(
                value: bloodType['id'],
                child: Container(
                  width: double.infinity,
                  child: Text(
                    bloodType['name'],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBloodType = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEducationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pendidikan Terakhir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedEducation,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF4A47DC), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _educationLevels.map((education) {
              return DropdownMenuItem<String>(
                value: education['id'],
                child: Container(
                  width: double.infinity,
                  child: Text(
                    education['name'],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEducation = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJobDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pekerjaan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedJob,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF4A47DC), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _jobs.map((job) {
              return DropdownMenuItem<String>(
                value: job['id']?.toString(),
                child: Container(
                  width: double.infinity,
                  child: Text(
                    job['name'] ?? job['job_name'] ?? 'N/A',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedJob = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
