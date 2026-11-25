import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/pages/beranda/admin_beranda_page.dart';
import 'package:ladimas/presentation/pages/beranda/admin_tagihan_page.dart';
import 'package:ladimas/presentation/widgets/common/app_bottom_nav_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:ladimas/data/datasources/penduduk_api_service.dart';

class AdminBiodataPage extends StatefulWidget {
  final Map<String, dynamic> adminData;

  const AdminBiodataPage({Key? key, required this.adminData}) : super(key: key);

  @override
  State<AdminBiodataPage> createState() => _AdminBiodataPageState();
}

class _AdminBiodataPageState extends State<AdminBiodataPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();
  final _kkController = TextEditingController();
  final _genderController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _addressController = TextEditingController();
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _rfidController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthCertificateNoController = TextEditingController();
  final _maritalCertificateNoController = TextEditingController();
  final _marriageDateController = TextEditingController();
  final _divorceCertificateNoController = TextEditingController();
  final _divorceCertificateDateController = TextEditingController();
  final _fatherController = TextEditingController();
  final _nikFatherController = TextEditingController();
  final _motherController = TextEditingController();
  final _nikMotherController = TextEditingController();
  final _hamletController = TextEditingController();
  // Hidden/readonly fields to mirror website
  final _coordinateController = TextEditingController();
  final _foreignAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _foreignPostalCodeController = TextEditingController();
  final _statusController = TextEditingController();

  // Wilayah IDs
  int? _provinceId;
  int? _districtId;
  int? _subDistrictId;
  int? _villageId;

  // Dropdown sources
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _subDistricts = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _jobs = [];
  Map<String, List<Map<String, dynamic>>> _enums = {};

  // Selected values
  String? _selectedGender;
  String? _selectedReligion;
  String? _selectedMaritalStatus;
  String? _selectedMaritalCertificate;
  String? _selectedDivorceCertificate;
  String? _selectedBirthCertificate;
  String? _selectedBloodType;
  String? _selectedCitizenStatus;
  String? _selectedFamilyStatus;
  String? _selectedMentalDisorders;
  String? _selectedDisabilities;
  String? _selectedEducationStatus;
  int? _selectedJobTypeId;

  bool _loading = false;
  // Hapus fitur hasil pencarian terpisah; pakai dropdown terfilter saja
  // Tidak diperlukan lagi cache terpisah

  late final PendudukApiService _pendudukService =
      PendudukApiService(client: http.Client());

  // Dropdown NIK & pencarian seperti Tagihan Form
  List<Map<String, dynamic>> _pendudukDropdown = [];
  String _nikSearch = '';
  String? _selectedNik;
  bool _loadingPenduduk = false;
  static const int _maxDropdownItems = 200; // batasi untuk hindari OOM Dropdown

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _kkController.dispose();
    _genderController.dispose();
    _birthDateController.dispose();
    _ageController.dispose();
    _birthPlaceController.dispose();
    _addressController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _postalCodeController.dispose();
    _rfidController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _birthCertificateNoController.dispose();
    _maritalCertificateNoController.dispose();
    _marriageDateController.dispose();
    _divorceCertificateNoController.dispose();
    _divorceCertificateDateController.dispose();
    _fatherController.dispose();
    _nikFatherController.dispose();
    _motherController.dispose();
    _nikMotherController.dispose();
    _hamletController.dispose();
    _coordinateController.dispose();
    _foreignAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _foreignPostalCodeController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredPenduduk() {
    if (_nikSearch.isEmpty) return _pendudukDropdown;
    return _pendudukDropdown.where((e) {
      final nik = (e['nik'] ?? '').toString().toLowerCase();
      final nama = (e['full_name'] ?? '').toString().toLowerCase();
      return nik.contains(_nikSearch) || nama.contains(_nikSearch);
    }).toList();
  }

  Future<void> _loadPendudukByVillage() async {
    try {
      setState(() => _loadingPenduduk = true);
      final villageId = _extractVillageId(widget.adminData);
      List<Map<String, dynamic>> list = [];
      if (villageId != null) {
        list = await _pendudukService.getCitizensByVillageId(villageId);
      } else {
        list = await _pendudukService.getAllCitizensLite();
      }
      list.sort((a, b) => (a['full_name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['full_name'] ?? '').toString().toLowerCase()));
      setState(() {
        _pendudukDropdown = list;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPenduduk = false);
    }
  }

  int? _extractVillageId(Map<String, dynamic> adminData) {
    try {
      final user = adminData['data']?['user'] ?? adminData['user'] ?? {};
      final pemdes = adminData['data']?['pemerintah_desa'] ??
          adminData['pemerintah_desa'] ??
          {};
      final candidates = [
        user['village_id'],
        user['villageId'],
        user['villages_id'],
        pemdes['village_id'],
        pemdes['villageId'],
        pemdes['villages_id'],
        (user is Map && user['village'] is Map) ? user['village']['id'] : null,
        (pemdes is Map && pemdes['village'] is Map)
            ? pemdes['village']['id']
            : null,
      ];
      for (final c in candidates) {
        if (c == null) continue;
        final v = int.tryParse(c.toString());
        if (v != null) return v;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isValidDate(String dateString) {
    try {
      if (dateString.isEmpty) return false;

      // Coba format YYYY-MM-DD
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (dateRegex.hasMatch(dateString)) {
        final parts = dateString.split('-');
        if (parts.length != 3) return false;

        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);

        if (year == null || month == null || day == null) return false;

        // Validasi range
        if (year < 1900 || year > DateTime.now().year) return false;
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;

        // Validasi tanggal yang valid
        final date = DateTime(year, month, day);
        if (date.year != year || date.month != month || date.day != day)
          return false;

        // Pastikan tidak di masa depan
        if (date.isAfter(DateTime.now())) return false;

        return true;
      }

      // Coba format DD/MM/YYYY
      final dateRegex2 = RegExp(r'^\d{2}/\d{2}/\d{4}$');
      if (dateRegex2.hasMatch(dateString)) {
        final parts = dateString.split('/');
        if (parts.length != 3) return false;

        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (year == null || month == null || day == null) return false;

        // Validasi range
        if (year < 1900 || year > DateTime.now().year) return false;
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;

        // Validasi tanggal yang valid
        final date = DateTime(year, month, day);
        if (date.year != year || date.month != month || date.day != day)
          return false;

        // Pastikan tidak di masa depan
        if (date.isAfter(DateTime.now())) return false;

        return true;
      }

      return false;
    } catch (e) {
      print('Error validating date: $e');
      return false;
    }
  }

  String _convertDateFormat(String dateString) {
    try {
      if (dateString.isEmpty) return dateString;

      // Jika sudah format YYYY-MM-DD, return as is
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (dateRegex.hasMatch(dateString)) {
        return dateString;
      }

      // Konversi dari DD/MM/YYYY ke YYYY-MM-DD
      final dateRegex2 = RegExp(r'^\d{2}/\d{2}/\d{4}$');
      if (dateRegex2.hasMatch(dateString)) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[2];
          return '$year-$month-$day';
        }
      }

      return dateString;
    } catch (e) {
      print('Error converting date format: $e');
      return dateString;
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final authLocalStorage = GetIt.instance<AuthLocalStorage>();
    final rawToken = await authLocalStorage.getStoredToken();
    String? bearer;
    if (rawToken != null && rawToken.isNotEmpty) {
      bearer = rawToken.contains('|') ? rawToken.split('|').last : rawToken;
    }
    return {
      'Accept': 'application/json',
      if (bearer != null) 'Authorization': 'Bearer $bearer',
      'X-API-Key': AppConstants.apiKey,
      'Content-Type': 'application/json',
    };
  }

  Future<void> _loadDropdownEnumsAndJobs() async {
    try {
      final headers = await _authHeaders();
      final enumsResp = await http.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/dropdowns/enums'),
        headers: headers,
      );
      if (enumsResp.statusCode == 200) {
        final jsonData = json.decode(enumsResp.body);
        if (jsonData['status'] == 'OK') {
          setState(() {
            _enums = Map<String, List<dynamic>>.from(jsonData['data'])
                .map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)));
          });
        }
      }

      final jobsResp = await http.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/dropdowns/jobs'),
        headers: headers,
      );
      if (jobsResp.statusCode == 200) {
        final jsonData = json.decode(jobsResp.body);
        if (jsonData['status'] == 'OK') {
          setState(() {
            _jobs = List<Map<String, dynamic>>.from(jsonData['data']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadProvinces() async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/dropdowns/provinces'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['status'] == 'OK') {
          setState(() {
            _provinces = List<Map<String, dynamic>>.from(jsonData['data']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureProvincesLoaded() async {
    if (_provinces.isEmpty) {
      await _loadProvinces();
    }
  }

  Future<void> _loadDistricts(String provinceCode) async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/dropdowns/districts/$provinceCode'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['status'] == 'OK') {
          setState(() {
            _districts = List<Map<String, dynamic>>.from(jsonData['data']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSubDistricts(String districtCode) async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/dropdowns/sub-districts/$districtCode'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['status'] == 'OK') {
          setState(() {
            _subDistricts = List<Map<String, dynamic>>.from(jsonData['data']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVillages(String subDistrictCode) async {
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/dropdowns/villages/$subDistrictCode'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['status'] == 'OK') {
          setState(() {
            _villages = List<Map<String, dynamic>>.from(jsonData['data']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDetailByNik(String nik) async {
    if (nik.isEmpty) return;
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();
      final resp = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/user/admin/biodata/$nik'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['status'] == 'OK' && jsonData['data'] != null) {
          final data = Map<String, dynamic>.from(jsonData['data']);
          // Pastikan enums sudah tersedia sebelum memetakan label -> value
          await _loadDropdownEnumsAndJobs();
          setState(() {
            // isi controller
            _nameController.text = (data['full_name'] ?? '').toString();
            _kkController.text = (data['kk'] ?? '').toString();
            _ageController.text = (data['age'] ?? '').toString();
            _birthPlaceController.text = (data['birth_place'] ?? '').toString();
            _birthDateController.text =
                _convertDateFormat((data['birth_date'] ?? '').toString());
            _addressController.text = (data['address'] ?? '').toString();
            _rtController.text = (data['rt'] ?? '').toString();
            _rwController.text = (data['rw'] ?? '').toString();
            _postalCodeController.text = (data['postal_code'] ?? '').toString();
            _telephoneController.text = (data['telephone'] ?? '').toString();
            _emailController.text = (data['email'] ?? '').toString();
            _rfidController.text = (data['rf_id_tag'] ?? '').toString();
            // Pastikan RFID adalah string yang valid
            try {
              if (_rfidController.text == 'null' ||
                  _rfidController.text == '0' ||
                  _rfidController.text.isEmpty) {
                _rfidController.clear();
              } else {
                // Validasi format RFID saat loading
                final rfidValue = int.tryParse(_rfidController.text);
                if (rfidValue == null || rfidValue <= 0) {
                  _rfidController.clear();
                }
              }
            } catch (e) {
              print('Error loading RFID: $e');
              _rfidController.clear();
            }
            _fatherController.text = (data['father'] ?? '').toString();
            _nikFatherController.text = (data['nik_father'] ?? '').toString();
            _motherController.text = (data['mother'] ?? '').toString();
            _nikMotherController.text = (data['nik_mother'] ?? '').toString();
            _hamletController.text = (data['hamlet'] ?? '').toString();
            _coordinateController.text = (data['coordinate'] ?? '').toString();
            _foreignAddressController.text =
                (data['foreign_address'] ?? '').toString();
            _cityController.text = (data['city'] ?? '').toString();
            _stateController.text = (data['state'] ?? '').toString();
            _countryController.text = (data['country'] ?? '').toString();
            _foreignPostalCodeController.text =
                (data['foreign_postal_code'] ?? '').toString();
            _statusController.text = (data['status'] ?? 'Active').toString();
            _birthCertificateNoController.text =
                (data['birth_certificate_no'] ?? '').toString();
            _maritalCertificateNoController.text =
                (data['marital_certificate_no'] ?? '').toString();
            _marriageDateController.text =
                _convertDateFormat((data['marriage_date'] ?? '').toString());
            _divorceCertificateNoController.text =
                (data['divorce_certificate_no'] ?? '').toString();
            _divorceCertificateDateController.text = _convertDateFormat(
                (data['divorce_certificate_date'] ?? '').toString());

            // enums: petakan label dari API -> value sesuai enums
            _selectedGender = _pickEnumValue('gender', data['gender']);
            _selectedReligion = _pickEnumValue('religion', data['religion']);
            _selectedMaritalStatus =
                _pickEnumValue('marital_status', data['marital_status']);
            _selectedMaritalCertificate = _pickEnumValue(
                'marital_certificate', data['marital_certificate']);
            _selectedDivorceCertificate = _pickEnumValue(
                'divorce_certificate', data['divorce_certificate']);
            _selectedBirthCertificate =
                _pickEnumValue('birth_certificate', data['birth_certificate']);
            _selectedBloodType =
                _pickEnumValue('blood_type', data['blood_type']);
            _selectedCitizenStatus =
                _pickEnumValue('citizen_status', data['citizen_status']);
            _selectedFamilyStatus =
                _pickEnumValue('family_status', data['family_status']);
            _selectedMentalDisorders =
                _pickEnumValue('mental_disorders', data['mental_disorders']);
            _selectedEducationStatus =
                _pickEnumValue('education_status', data['education_status']);
            _selectedJobTypeId = _toInt(data['job_type_id']);
            _selectedDisabilities =
                _pickEnumValue('disabilities', data['disabilities']);

            // wilayah
            _provinceId = _toInt(data['province_id']);
            _districtId = _toInt(data['district_id']);
            _subDistrictId = _toInt(data['sub_district_id']);
            _villageId = _toInt(data['village_id']);
          });

          // Load cascading dropdown sesuai pilihan (API butuh code, data dari NIK berupa id)
          await _ensureProvincesLoaded();
          final provinceCode = _getCodeById(_provinces, _provinceId);
          if (provinceCode != null) {
            await _loadDistricts(provinceCode);
          }
          final districtCode = _getCodeById(_districts, _districtId);
          if (districtCode != null) {
            await _loadSubDistricts(districtCode);
          }
          final subDistrictCode = _getCodeById(_subDistricts, _subDistrictId);
          if (subDistrictCode != null) {
            await _loadVillages(subDistrictCode);
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String? _toStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  String? _normalizeLabel(String? s) {
    if (s == null) return null;
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _pickEnumValue(String enumKey, dynamic incoming) {
    final incomingStr = _normalizeLabel(_toStr(incoming));
    if (incomingStr == null) return null;
    // Jika numerik, kembalikan numerik sebagai string
    final asInt = int.tryParse(incomingStr);
    if (asInt != null) return asInt.toString();

    // Penanganan khusus nilai yang sering berbeda dari label enums
    String normalized = incomingStr;
    if (enumKey == 'family_status') {
      // Normalisasikan kapitalisasi, contoh: KEPALA KELUARGA -> Kepala Keluarga
      normalized = incomingStr
          .toLowerCase()
          .split(' ')
          .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
          .join(' ');
    } else if (enumKey == 'mental_disorders') {
      // Data bisa berisi "Tidak Ada" -> petakan ke label enums "Tidak"
      if (incomingStr.toLowerCase().startsWith('tidak')) {
        normalized = 'Tidak';
      } else if (incomingStr.toLowerCase().startsWith('ya')) {
        normalized = 'Ya';
      }
    } else if (enumKey == 'disabilities') {
      // Data bisa berupa "null" atau kosong -> "Tidak Ada" (value 0)
      if (incomingStr.toLowerCase() == 'null' || incomingStr.isEmpty) {
        normalized = 'Tidak Ada';
      }
    }

    final list = _enums[enumKey] ?? const [];
    for (final item in list) {
      final itemLabel = _normalizeLabel(item['label']?.toString());
      if (itemLabel != null &&
          itemLabel.toLowerCase() == normalized.toLowerCase()) {
        return item['value']?.toString();
      }
    }

    // Jika tidak ditemukan padanan, kembalikan null agar dropdown tidak memilih nilai salah
    return null;
  }

  String? _getCodeById(List<Map<String, dynamic>> list, int? id) {
    if (id == null) return null;
    for (final e in list) {
      final int? itemId = _toInt(e['id']);
      if (itemId == id) {
        return e['code']?.toString();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Biodata',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Pilih Penduduk',
                Icons.person_search_outlined,
              ),

              // RF ID
              _textField(
                controller: _rfidController,
                label: 'RF ID Tag (opsional)',
                hintText: '123 atau kosong',
                keyboardType: TextInputType.text,
              ),

              // Search NIK / Nama
              _buildLabel('Cari NIK / Nama'),
              TextField(
                controller: _nikController,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
                decoration: _inputDecoration(
                  hintText: 'Cari berdasarkan NIK atau nama',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
                onChanged: (v) => setState(() {
                  _nikSearch = v.trim().toLowerCase();
                  final filtered = _filteredPenduduk();
                  if (filtered.isNotEmpty) {
                    _selectedNik = (filtered.first['nik'] ?? '').toString();
                  }
                }),
              ),
              const SizedBox(height: 16),

              _buildLabel('Pilih NIK Penduduk'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedNik,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      menuMaxHeight: 320,
                      decoration: _inputDecoration(),
                      hint: const Text(
                        'Pilih penduduk...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      items: _filteredPenduduk()
                          .take(_maxDropdownItems)
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e['nik'] as String,
                              child: Text(
                                '${e['full_name'] ?? '-'} (${e['nik']})',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      selectedItemBuilder: (context) {
                        final list = _filteredPenduduk()
                            .take(_maxDropdownItems)
                            .toList();
                        return list
                            .map(
                              (e) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${e['full_name'] ?? '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            )
                            .toList();
                      },
                      onChanged: (v) async {
                        setState(() {
                          _selectedNik = v;
                          _nikController.text = v ?? '';
                        });
                        await _loadDetailByNik(v ?? '');
                      },
                    ),
                  ),
                  if (_loadingPenduduk) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),

              _buildSectionHeader(
                'Data Pribadi',
                Icons.badge_outlined,
              ),

              _textField(
                controller: _kkController,
                label: 'No KK',
                keyboardType: TextInputType.number,
              ),
              _textField(
                controller: _nameController,
                label: 'Nama Lengkap',
              ),
              _dropdownField(
                'Jenis Kelamin',
                'gender',
                _selectedGender,
                (val) => setState(() => _selectedGender = val),
              ),
              _textField(
                controller: _birthPlaceController,
                label: 'Tempat Lahir',
              ),
              _textField(
                controller: _birthDateController,
                label: 'Tanggal Lahir',
              ),
              _textField(
                controller: _ageController,
                label: 'Umur',
                keyboardType: TextInputType.number,
              ),

              _buildSectionHeader(
                'Alamat & Wilayah',
                Icons.location_on_outlined,
              ),

              _dropdownWilayah(
                'Provinsi',
                _provinces,
                _provinceId,
                (value) async {
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
                    final provinceCode = _getCodeById(_provinces, value);
                    if (provinceCode != null) {
                      await _loadDistricts(provinceCode);
                    }
                  }
                },
              ),
              _dropdownWilayah(
                'Kabupaten/Kota',
                _districts,
                _districtId,
                (value) async {
                  setState(() {
                    _districtId = value;
                    _subDistrictId = null;
                    _villageId = null;
                    _subDistricts = [];
                    _villages = [];
                  });
                  if (value != null) {
                    final districtCode = _getCodeById(_districts, value);
                    if (districtCode != null) {
                      await _loadSubDistricts(districtCode);
                    }
                  }
                },
              ),
              _dropdownWilayah(
                'Kecamatan',
                _subDistricts,
                _subDistrictId,
                (value) async {
                  setState(() {
                    _subDistrictId = value;
                    _villageId = null;
                    _villages = [];
                  });
                  if (value != null) {
                    final subDistrictCode = _getCodeById(_subDistricts, value);
                    if (subDistrictCode != null) {
                      await _loadVillages(subDistrictCode);
                    }
                  }
                },
              ),
              _dropdownWilayah(
                'Desa',
                _villages,
                _villageId,
                (value) {
                  setState(() {
                    _villageId = value;
                  });
                },
              ),
              _textField(
                controller: _addressController,
                label: 'Alamat',
                maxLines: 3,
                enabled: false,
              ),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _rtController,
                      label: 'RT',
                      keyboardType: TextInputType.number,
                      enabled: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _rwController,
                      label: 'RW',
                      keyboardType: TextInputType.number,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              _textField(
                controller: _postalCodeController,
                label: 'Kode Pos',
                keyboardType: TextInputType.number,
                enabled: false,
              ),
              _textField(
                controller: _hamletController,
                label: 'Dusun',
                enabled: false,
              ),

              _buildSectionHeader(
                'Data Kependudukan',
                Icons.account_balance_outlined,
              ),

              _dropdownField(
                'Golongan Darah',
                'blood_type',
                _selectedBloodType,
                (val) => setState(() => _selectedBloodType = val),
              ),
              _dropdownField(
                'Agama',
                'religion',
                _selectedReligion,
                (val) => setState(() => _selectedReligion = val),
              ),
              _dropdownField(
                'Status Kawin',
                'marital_status',
                _selectedMaritalStatus,
                (val) => setState(() => _selectedMaritalStatus = val),
              ),

              _buildSectionHeader(
                'Dokumen Kependudukan',
                Icons.description_outlined,
              ),

              _dropdownField(
                'Akta Kawin',
                'marital_certificate',
                _selectedMaritalCertificate,
                (val) => setState(() => _selectedMaritalCertificate = val),
              ),
              _textField(
                controller: _maritalCertificateNoController,
                label: 'No Akta Kawin',
              ),
              _textField(
                controller: _marriageDateController,
                label: 'Tanggal Kawin',
              ),
              _dropdownField(
                'Akta Cerai',
                'divorce_certificate',
                _selectedDivorceCertificate,
                (val) => setState(() => _selectedDivorceCertificate = val),
              ),
              _textField(
                controller: _divorceCertificateNoController,
                label: 'No Akta Cerai',
              ),
              _textField(
                controller: _divorceCertificateDateController,
                label: 'Tanggal Akta Cerai',
              ),
              _dropdownField(
                'Akta Lahir',
                'birth_certificate',
                _selectedBirthCertificate,
                (val) => setState(() => _selectedBirthCertificate = val),
              ),
              _textField(
                controller: _birthCertificateNoController,
                label: 'No Akta Lahir',
              ),

              _buildSectionHeader(
                'Status & Kondisi',
                Icons.fact_check_outlined,
              ),

              _dropdownField(
                'Kewarganegaraan',
                'citizen_status',
                _selectedCitizenStatus,
                (val) => setState(() => _selectedCitizenStatus = val),
              ),
              _dropdownField(
                'Status Dalam Keluarga',
                'family_status',
                _selectedFamilyStatus,
                (val) => setState(() => _selectedFamilyStatus = val),
              ),
              _dropdownField(
                'Kelainan Fisik & Mental',
                'mental_disorders',
                _selectedMentalDisorders,
                (val) => setState(() => _selectedMentalDisorders = val),
              ),
              _dropdownField(
                'Pendidikan',
                'education_status',
                _selectedEducationStatus,
                (val) => setState(() => _selectedEducationStatus = val),
              ),
              _dropdownField(
                'Penyandang Cacat',
                'disabilities',
                _selectedDisabilities,
                (val) => setState(() => _selectedDisabilities = val),
              ),
              _dropdownJobs(),

              _buildSectionHeader(
                'Kontak & Keluarga',
                Icons.family_restroom_outlined,
              ),

              _textField(
                controller: _telephoneController,
                label: 'Telepon',
              ),
              _textField(
                controller: _emailController,
                label: 'Email',
              ),
              _textField(
                controller: _fatherController,
                label: 'Nama Ayah',
              ),
              _textField(
                controller: _nikFatherController,
                label: 'NIK Ayah',
                keyboardType: TextInputType.number,
              ),
              _textField(
                controller: _motherController,
                label: 'Nama Ibu',
              ),
              _textField(
                controller: _nikMotherController,
                label: 'NIK Ibu',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _clearAllFields,
                        icon: const Icon(Icons.clear_rounded),
                        label: const Text(
                          'Bersihkan Form',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: const Color(0xFF475569),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text(
                          'Simpan Perubahan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.whiteColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        items: [
          AppBottomNavBar.item(icon: Icons.home_outlined, label: ''),
          AppBottomNavBar.item(icon: Icons.receipt_long_outlined, label: ''),
          AppBottomNavBar.item(icon: Icons.person, label: ''),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminBerandaPage(adminData: widget.adminData),
                ),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminTagihanPage(adminData: widget.adminData),
                ),
              );
              break;
            case 2:
              break;
          }
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Saat masuk pertama kali, form kosong. Hanya load sumber dropdown.
    _loadDropdownEnumsAndJobs();
    _loadProvinces();
    // Muat dropdown penduduk di awal agar bisa dipilih langsung
    _loadPendudukByVillage();
  }

  // Hapus helper pencarian lama; dropdown sudah menampung semua penduduk

  void _clearAllFields() {
    _nikController.clear();
    _nameController.clear();
    _kkController.clear();
    _genderController.clear();
    _birthDateController.clear();
    _ageController.clear();
    _birthPlaceController.clear();
    _addressController.clear();
    _rtController.clear();
    _rwController.clear();
    _postalCodeController.clear();
    _rfidController.clear();
    _telephoneController.clear();
    _emailController.clear();
    _birthCertificateNoController.clear();
    _maritalCertificateNoController.clear();
    _marriageDateController.clear();
    _divorceCertificateNoController.clear();
    _divorceCertificateDateController.clear();
    _fatherController.clear();
    _nikFatherController.clear();
    _motherController.clear();
    _nikMotherController.clear();
    _hamletController.clear();
    _coordinateController.clear();
    _foreignAddressController.clear();
    _cityController.clear();
    _stateController.clear();
    _countryController.clear();
    _foreignPostalCodeController.clear();
    _statusController.clear();

    setState(() {
      _selectedNik = null;
      _selectedGender = null;
      _selectedReligion = null;
      _selectedMaritalStatus = null;
      _selectedMaritalCertificate = null;
      _selectedDivorceCertificate = null;
      _selectedBirthCertificate = null;
      _selectedBloodType = null;
      _selectedCitizenStatus = null;
      _selectedFamilyStatus = null;
      _selectedMentalDisorders = null;
      _selectedDisabilities = null;
      _selectedEducationStatus = null;
      _selectedJobTypeId = null;

      _provinceId = null;
      _districtId = null;
      _subDistrictId = null;
      _villageId = null;
      _districts = [];
      _subDistricts = [];
      _villages = [];
    });
  }

  InputDecoration _inputDecoration({
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF94A3B8),
      ),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(
          color: Color(0xFF4A47DC),
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool readOnly = false,
    bool enabled = true,
    int maxLines = 1,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            enabled: enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryColor,
              fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
            ),
            decoration: _inputDecoration(hintText: hintText),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField(
    String label,
    String enumKey,
    String? value,
    Function(String?) onChanged,
  ) {
    final rawOptions = _enums[enumKey] ?? [];

    final Set<String> seen = {};
    final options = rawOptions
        .map(
          (e) => {
            'value': (e['value']?.toString() ?? '').trim(),
            'label': (e['label']?.toString() ?? '').trim(),
          },
        )
        .where((e) => (e['value'] as String).isNotEmpty)
        .where((e) => seen.add(e['value'] as String))
        .toList();

    final values = options.map<String>((e) => e['value'] as String).toSet();
    final String? safeValue =
        (value != null && values.contains(value)) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          DropdownButtonFormField<String>(
            value: safeValue,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            decoration: _inputDecoration(),
            hint: const Text(
              'Pilih',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            items: options
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e['value'] as String,
                    child: Text(
                      e['label'] as String,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _dropdownWilayah(
    String label,
    List<Map<String, dynamic>> items,
    int? value,
    Function(int?)? onChanged,
  ) {
    final Set<int> seen = {};
    final normalized = items
        .map(
          (e) => {
            'id': _toInt(e['id']) ?? _toInt(e['code']) ?? _toInt(e['value']),
            'label': (e['name'] ?? e['label'] ?? e['text'] ?? '').toString(),
          },
        )
        .where((e) => e['id'] != null)
        .where((e) => seen.add(e['id'] as int))
        .toList();

    final ids = normalized.map<int>((e) => e['id'] as int).toSet();
    final int? safeValue =
        (value != null && ids.contains(value)) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          DropdownButtonFormField<int>(
            value: safeValue,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            decoration: _inputDecoration(),
            hint: const Text(
              'Pilih',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            items: normalized
                .map(
                  (e) => DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(
                      e['label'] as String,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _dropdownJobs() {
    final Set<int> seen = {};
    final normalized = _jobs
        .map(
          (e) => {
            'id': _toInt(e['id']),
            'label': (e['name'] ?? e['label'] ?? '').toString(),
          },
        )
        .where((e) => e['id'] != null)
        .where((e) => seen.add(e['id'] as int))
        .toList();

    final ids = normalized.map<int>((e) => e['id'] as int).toSet();
    final int? safeValue =
        (_selectedJobTypeId != null && ids.contains(_selectedJobTypeId))
            ? _selectedJobTypeId
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Pekerjaan'),
          DropdownButtonFormField<int>(
            value: safeValue,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            decoration: _inputDecoration(),
            hint: const Text(
              'Pilih pekerjaan',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            items: normalized
                .map(
                  (e) => DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(
                      e['label'] as String,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedJobTypeId = v),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_nikController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih NIK terlebih dahulu')));
      return;
    }

    // Validasi NIK (16 digit)
    final nik = _nikController.text.trim();
    if (nik.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nik)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NIK harus 16 digit angka')));
      return;
    }

    // Validasi KK (16 digit)
    final kk = _kkController.text.trim();
    if (kk.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No KK harus diisi')));
      return;
    }
    if (kk.length != 16 || !RegExp(r'^\d{16}$').hasMatch(kk)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No KK harus 16 digit angka')));
      return;
    }

    // Validasi nama lengkap
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama lengkap harus diisi')));
      return;
    }

    // Validasi panjang nama
    if (_nameController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama lengkap minimal 2 karakter')));
      return;
    }

    if (_nameController.text.trim().length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama lengkap maksimal 100 karakter')));
      return;
    }

    // Validasi tempat lahir
    if (_birthPlaceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tempat lahir harus diisi')));
      return;
    }

    // Validasi panjang tempat lahir
    if (_birthPlaceController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tempat lahir minimal 2 karakter')));
      return;
    }

    if (_birthPlaceController.text.trim().length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tempat lahir maksimal 50 karakter')));
      return;
    }

    // Validasi tanggal lahir
    if (_birthDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal lahir harus diisi')));
      return;
    }

    // Validasi format tanggal lahir
    final birthDate = _birthDateController.text.trim();
    if (!_isValidDate(birthDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Format tanggal lahir tidak valid. Gunakan format YYYY-MM-DD atau DD/MM/YYYY')));
      return;
    }

    // Validasi umur
    if (_ageController.text.trim().isNotEmpty) {
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 0 || age > 150) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Umur harus berupa angka 0-150')));
        return;
      }
    }

    // Validasi alamat
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Alamat harus diisi')));
      return;
    }

    // Alamat bebas panjang - tidak ada validasi

    // Validasi wilayah
    if (_provinceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Provinsi harus dipilih')));
      return;
    }
    if (_districtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kabupaten/Kota harus dipilih')));
      return;
    }
    if (_subDistrictId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kecamatan harus dipilih')));
      return;
    }
    if (_villageId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Desa harus dipilih')));
      return;
    }

    // Validasi RT/RW
    if (_rtController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('RT harus diisi')));
      return;
    }
    if (_rwController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('RW harus diisi')));
      return;
    }

    // Validasi format RT/RW
    final rt = _rtController.text.trim();
    final rw = _rwController.text.trim();
    if (!RegExp(r'^\d+$').hasMatch(rt) ||
        int.tryParse(rt) == null ||
        int.parse(rt) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RT harus berupa angka positif')));
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(rw) ||
        int.tryParse(rw) == null ||
        int.parse(rw) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RW harus berupa angka positif')));
      return;
    }

    // Validasi email jika diisi
    if (_emailController.text.trim().isNotEmpty) {
      final emailRegex =
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(_emailController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Format email tidak valid')));
        return;
      }
    }

    // Validasi nomor telepon jika diisi
    if (_telephoneController.text.trim().isNotEmpty) {
      final phoneRegex = RegExp(r'^[0-9+\-\s()]+$');
      if (!phoneRegex.hasMatch(_telephoneController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Format nomor telepon tidak valid')));
        return;
      }
    }

    // Kode pos opsional - tidak ada validasi input user
    // Backend tetap memerlukan 5 digit, jadi kita handle di sanitasi

    // Validasi NIK ayah jika diisi
    if (_nikFatherController.text.trim().isNotEmpty) {
      final nikFather = _nikFatherController.text.trim();
      if (nikFather.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikFather)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('NIK ayah harus 16 digit angka')));
        return;
      }
    }

    // Validasi NIK ibu jika diisi
    if (_nikMotherController.text.trim().isNotEmpty) {
      final nikMother = _nikMotherController.text.trim();
      if (nikMother.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikMother)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('NIK ibu harus 16 digit angka')));
        return;
      }
    }

    // Validasi nama ayah jika diisi
    if (_fatherController.text.trim().isNotEmpty) {
      if (_fatherController.text.trim().length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama ayah minimal 2 karakter')));
        return;
      }
      if (_fatherController.text.trim().length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama ayah maksimal 100 karakter')));
        return;
      }
    }

    // Validasi nama ibu jika diisi
    if (_motherController.text.trim().isNotEmpty) {
      if (_motherController.text.trim().length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama ibu minimal 2 karakter')));
        return;
      }
      if (_motherController.text.trim().length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nama ibu maksimal 100 karakter')));
        return;
      }
    }

    // Validasi dusun jika diisi
    if (_hamletController.text.trim().isNotEmpty) {
      if (_hamletController.text.trim().length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dusun minimal 2 karakter')));
        return;
      }
      if (_hamletController.text.trim().length > 50) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dusun maksimal 50 karakter')));
        return;
      }
    }

    // Validasi nomor akta lahir jika diisi
    if (_birthCertificateNoController.text.trim().isNotEmpty) {
      if (_birthCertificateNoController.text.trim().length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No akta lahir minimal 3 karakter')));
        return;
      }
      if (_birthCertificateNoController.text.trim().length > 50) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No akta lahir maksimal 50 karakter')));
        return;
      }
    }

    // Validasi nomor akta kawin jika diisi
    if (_maritalCertificateNoController.text.trim().isNotEmpty) {
      if (_maritalCertificateNoController.text.trim().length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No akta kawin minimal 3 karakter')));
        return;
      }
      if (_maritalCertificateNoController.text.trim().length > 50) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No akta kawin maksimal 50 karakter')));
        return;
      }
    }

    // Validasi nomor akta cerai jika diisi
    if (_divorceCertificateNoController.text.trim().isNotEmpty) {
      if (_divorceCertificateNoController.text.trim().length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No akta cerai minimal 3 karakter')));
        return;
      }
      if (_divorceCertificateNoController.text.trim().length > 50) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No akta cerai maksimal 50 karakter')));
        return;
      }
    }

    // Validasi tanggal kawin jika diisi
    if (_marriageDateController.text.trim().isNotEmpty) {
      if (!_isValidDate(_marriageDateController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Format tanggal kawin tidak valid. Gunakan format YYYY-MM-DD atau DD/MM/YYYY')));
        return;
      }
    }

    // Validasi tanggal cerai jika diisi
    if (_divorceCertificateDateController.text.trim().isNotEmpty) {
      if (!_isValidDate(_divorceCertificateDateController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Format tanggal cerai tidak valid. Gunakan format YYYY-MM-DD atau DD/MM/YYYY')));
        return;
      }
    }

    // RFID opsional - tidak ada validasi format

    // Validasi enum fields yang required
    final requiredEnumErrors = <String>[];
    if (_selectedGender == null) requiredEnumErrors.add('Jenis Kelamin');
    if (_selectedBloodType == null) requiredEnumErrors.add('Golongan Darah');
    if (_selectedReligion == null) requiredEnumErrors.add('Agama');
    if (_selectedCitizenStatus == null)
      requiredEnumErrors.add('Kewarganegaraan');
    if (_selectedMaritalCertificate == null)
      requiredEnumErrors.add('Akta Kawin');
    if (_selectedFamilyStatus == null)
      requiredEnumErrors.add('Status Dalam Keluarga');
    if (_selectedMentalDisorders == null)
      requiredEnumErrors.add('Kelainan Fisik & Mental');
    if (_selectedEducationStatus == null) requiredEnumErrors.add('Pendidikan');
    if (_selectedJobTypeId == null) requiredEnumErrors.add('Pekerjaan');
    if (requiredEnumErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lengkapi: ${requiredEnumErrors.join(', ')}')));
      return;
    }
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();

      dynamic _numOrString(String? s) {
        if (s == null) return null;
        final trimmed = s.trim();
        if (trimmed.isEmpty) return null;
        final asInt = int.tryParse(trimmed);
        // Untuk enum fields, pastikan mengembalikan integer jika bisa di-parse
        // atau string jika tidak bisa di-parse
        return asInt ?? trimmed;
      }

      // Validasi enum values sebelum mengirim
      void _validateEnumValue(
          Map<String, dynamic> payload, String key, dynamic value) {
        if (value == null) return;
        // Pastikan value adalah integer atau string yang valid
        if (value is String && value.isNotEmpty) {
          final asInt = int.tryParse(value);
          if (asInt != null) {
            payload[key] = asInt;
          }
        }
      }

      String? _sanitizePostalCode(String input) {
        final trimmed = input.trim();
        if (trimmed.isEmpty) return '00000'; // Default 5 digit untuk backend

        // Jika input hanya angka, pastikan 5 digit
        if (RegExp(r'^\d+$').hasMatch(trimmed)) {
          // Pad dengan 0 di depan jika kurang dari 5 digit
          if (trimmed.length < 5) {
            return trimmed.padLeft(5, '0');
          } else if (trimmed.length > 5) {
            return trimmed.substring(0, 5);
          }
          return trimmed; // Sudah 5 digit
        }

        // Jika bukan angka, gunakan default
        return '00000';
      }

      final payload = {
        'kk': kk,
        'full_name': _nameController.text.trim(),
        'gender': _numOrString(_selectedGender),
        'birth_date': _convertDateFormat(_birthDateController.text.trim()),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'birth_place': _birthPlaceController.text.trim(),
        'address': _addressController.text.trim(),
        'province_id': _provinceId!,
        'district_id': _districtId!,
        'sub_district_id': _subDistrictId!,
        'village_id': _villageId!,
        'rt': _rtController.text.trim(),
        'rw': _rwController.text.trim(),
        'postal_code': _sanitizePostalCode(_postalCodeController.text),
        'citizen_status': _numOrString(_selectedCitizenStatus),
        'birth_certificate': _numOrString(_selectedBirthCertificate),
        'birth_certificate_no':
            _birthCertificateNoController.text.trim().isNotEmpty
                ? _birthCertificateNoController.text.trim()
                : null,
        'blood_type': _numOrString(_selectedBloodType),
        'religion': _numOrString(_selectedReligion),
        'marital_status': _numOrString(_selectedMaritalStatus),
        'marital_certificate': _numOrString(_selectedMaritalCertificate),
        'marital_certificate_no':
            _maritalCertificateNoController.text.trim().isNotEmpty
                ? _maritalCertificateNoController.text.trim()
                : null,
        'marriage_date': _marriageDateController.text.trim().isNotEmpty
            ? _convertDateFormat(_marriageDateController.text.trim())
            : null,
        'divorce_certificate': _numOrString(_selectedDivorceCertificate),
        'divorce_certificate_no':
            _divorceCertificateNoController.text.trim().isNotEmpty
                ? _divorceCertificateNoController.text.trim()
                : null,
        'divorce_certificate_date': _divorceCertificateDateController.text
                .trim()
                .isNotEmpty
            ? _convertDateFormat(_divorceCertificateDateController.text.trim())
            : null,
        'family_status': _numOrString(_selectedFamilyStatus),
        'mental_disorders': _numOrString(_selectedMentalDisorders),
        'disabilities': _numOrString(_selectedDisabilities),
        'education_status': _numOrString(_selectedEducationStatus),
        'job_type_id': _selectedJobTypeId!,
        'rf_id_tag': _rfidController.text.trim().isNotEmpty
            ? _rfidController.text.trim()
            : null,
        'telephone': _telephoneController.text.trim().isNotEmpty
            ? _telephoneController.text.trim()
            : null,
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'father': _fatherController.text.trim().isNotEmpty
            ? _fatherController.text.trim()
            : null,
        'nik_father': _nikFatherController.text.trim().isNotEmpty
            ? _nikFatherController.text.trim()
            : null,
        'mother': _motherController.text.trim().isNotEmpty
            ? _motherController.text.trim()
            : null,
        'nik_mother': _nikMotherController.text.trim().isNotEmpty
            ? _nikMotherController.text.trim()
            : null,
        'hamlet': _hamletController.text.trim().isNotEmpty
            ? _hamletController.text.trim()
            : null,
        'coordinate': _coordinateController.text.trim().isNotEmpty
            ? _coordinateController.text.trim()
            : null,
        'foreign_address': _foreignAddressController.text.trim().isNotEmpty
            ? _foreignAddressController.text.trim()
            : null,
        'city': _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : null,
        'state': _stateController.text.trim().isNotEmpty
            ? _stateController.text.trim()
            : null,
        'country': _countryController.text.trim().isNotEmpty
            ? _countryController.text.trim()
            : null,
        'foreign_postal_code':
            _foreignPostalCodeController.text.trim().isNotEmpty
                ? _foreignPostalCodeController.text.trim()
                : null,
        'status': 'Active',
      };

      // Validasi enum values
      _validateEnumValue(payload, 'gender', payload['gender']);
      _validateEnumValue(payload, 'blood_type', payload['blood_type']);
      _validateEnumValue(payload, 'religion', payload['religion']);
      _validateEnumValue(payload, 'citizen_status', payload['citizen_status']);
      _validateEnumValue(
          payload, 'birth_certificate', payload['birth_certificate']);
      _validateEnumValue(payload, 'marital_status', payload['marital_status']);
      _validateEnumValue(
          payload, 'marital_certificate', payload['marital_certificate']);
      _validateEnumValue(
          payload, 'divorce_certificate', payload['divorce_certificate']);
      _validateEnumValue(payload, 'family_status', payload['family_status']);
      _validateEnumValue(
          payload, 'mental_disorders', payload['mental_disorders']);
      _validateEnumValue(payload, 'disabilities', payload['disabilities']);
      _validateEnumValue(
          payload, 'education_status', payload['education_status']);

      // RFID opsional - tidak ada validasi khusus

      // Clean up payload untuk menghindari masalah JSON parsing
      payload.removeWhere((key, value) => value == null);

      // Pastikan tidak ada field yang berisi data tidak valid untuk JSON
      payload.removeWhere((key, value) {
        if (value is String) {
          // Hapus field yang berisi string kosong atau hanya whitespace
          return value.trim().isEmpty;
        }
        return false;
      });

      // Pastikan string fields tidak kosong
      final stringFields = ['full_name', 'birth_place', 'address', 'rt', 'rw'];
      for (final field in stringFields) {
        if (payload[field] == null ||
            payload[field].toString().trim().isEmpty) {
          payload[field] = '';
        }
      }

      // Pastikan postal_code selalu ada dan valid
      if (payload['postal_code'] == null ||
          payload['postal_code'].toString().trim().isEmpty) {
        payload['postal_code'] = '00000';
      }

      // Pastikan status selalu ada
      if (payload['status'] == null ||
          payload['status'].toString().trim().isEmpty) {
        payload['status'] = 'Active';
      }

      // Pastikan enum fields tidak null
      final enumFields = [
        'gender',
        'blood_type',
        'religion',
        'citizen_status',
        'birth_certificate',
        'marital_status',
        'marital_certificate',
        'divorce_certificate',
        'family_status',
        'mental_disorders',
        'disabilities',
        'education_status'
      ];
      for (final field in enumFields) {
        if (payload[field] == null) {
          payload[field] = '1'; // Default value untuk enum
        }
      }

      // Pastikan job_type_id tidak null
      if (payload['job_type_id'] == null) {
        payload['job_type_id'] = 1; // Default job type
      }

      // Validasi field yang mungkin bermasalah untuk JSON
      final problematicFields = [
        'coordinate',
        'foreign_address',
        'city',
        'state',
        'country'
      ];
      for (final field in problematicFields) {
        if (payload[field] != null) {
          final value = payload[field].toString();
          // Hapus karakter yang mungkin bermasalah untuk JSON
          payload[field] = value.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
          if (payload[field].toString().isEmpty) {
            payload[field] = null;
          }
        }
      }

      // Debug logging
      String jsonBody;
      try {
        // Debug setiap field untuk mencari yang bermasalah
        print('=== PAYLOAD DEBUG ===');
        payload.forEach((key, value) {
          print('$key: $value (${value.runtimeType})');
        });
        print('===================');

        // Coba encode field per field untuk mencari yang bermasalah
        final cleanPayload = <String, dynamic>{};
        for (final entry in payload.entries) {
          try {
            // Test encode individual field
            json.encode({entry.key: entry.value});
            cleanPayload[entry.key] = entry.value;
          } catch (e) {
            print('Field ${entry.key} bermasalah: $e');
            // Skip field yang bermasalah
          }
        }

        jsonBody = json.encode(cleanPayload);
        print('Payload yang dikirim: $jsonBody');
        print('RFID value: ${cleanPayload['rf_id_tag']}');
        print('RFID type: ${cleanPayload['rf_id_tag'].runtimeType}');
      } catch (e) {
        print('Error encoding JSON: $e');
        print('Error details: ${e.toString()}');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error encoding data: $e')));
        return;
      }

      final resp = await http.put(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/biodata/${_nikController.text}'),
        headers: headers,
        body: jsonBody,
      );

      // Debug logging response
      print('Response status: ${resp.statusCode}');
      print('Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['status'] == 'OK') {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonData['message'] ?? 'Berhasil')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(jsonData['message'] ?? 'Gagal menyimpan')));
        }
      } else {
        String errorMessage = 'Gagal menyimpan: ${resp.statusCode}';
        try {
          final jsonData = json.decode(resp.body);
          if (resp.statusCode == 422) {
            // Handle validation errors
            if (jsonData['errors'] != null) {
              final errors = jsonData['errors'];
              if (errors is Map<String, dynamic>) {
                final errorList = <String>[];
                errors.forEach((key, value) {
                  if (value is List && value.isNotEmpty) {
                    errorList.add('$key: ${value.join(', ')}');
                  } else if (value is String) {
                    errorList.add('$key: $value');
                  }
                });
                errorMessage = 'Validasi gagal:\n${errorList.join('\n')}';
              } else if (errors is List && errors.isNotEmpty) {
                errorMessage = 'Validasi gagal: ${errors.join(', ')}';
              }
            } else if (jsonData['message'] != null) {
              errorMessage = jsonData['message'];
            }
          } else if (jsonData['message'] != null) {
            errorMessage = jsonData['message'];
          }
        } catch (e) {
          // If JSON parsing fails, use default message
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
