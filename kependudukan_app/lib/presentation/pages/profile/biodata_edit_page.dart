import 'package:flutter/material.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BiodataEditPage extends StatefulWidget {
  final Penduduk penduduk;
  final Map<String, dynamic>? initialBiodata;

  const BiodataEditPage({Key? key, required this.penduduk, this.initialBiodata})
      : super(key: key);

  @override
  State<BiodataEditPage> createState() => _BiodataEditPageState();
}

class _BiodataEditPageState extends State<BiodataEditPage> {
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
  int _memberLoadToken = 0; // Guard anti-race saat ganti anggota beruntun

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

  @override
  void initState() {
    super.initState();

    // Inisialisasi dropdown dasar
    _initializeDropdownOptions();

    // Populate form langsung dengan data yang ada tanpa delay
    _nikController.text = widget.penduduk.nik;
    _nameController.text = widget.penduduk.name;
    _selectedNik = widget.penduduk.nik;

    final cachedPayload = CacheService()
        .get<Map<String, dynamic>>(BiodataCacheKeys.apiBiodataPayload);
    final initialData = widget.initialBiodata ??
        (cachedPayload != null && cachedPayload['biodata'] != null
            ? Map<String, dynamic>.from(cachedPayload['biodata'])
            : null);

    if (initialData != null && initialData.isNotEmpty) {
      _currentData = initialData;
      if (cachedPayload != null) {
        _familyMembers = List<Map<String, dynamic>>.from(
            cachedPayload['family_members'] ?? []);
        _jobs = List<Map<String, dynamic>>.from(cachedPayload['jobs'] ?? []);
        final userNik = _currentData!['nik']?.toString();
        final userExists = _familyMembers
            .any((member) => member['nik']?.toString() == userNik);
        if (!userExists && userNik != null) {
          _familyMembers.insert(0, _currentData!);
        }
      }
    }

    // Populate seluruh field secara instan/sinkron
    _populateFormFieldsSync();

    // Muat data background jika belum ada
    _loadCurrentData();
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
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    final hasData = _currentData != null && _currentData!.isNotEmpty;
    if (!hasData) {
      setState(() => _isLoading = true);
    }

    try {
      await _loadBiodataAndFamily();
    } catch (e) {
      if (!mounted) return;
      if (!hasData) {
        MessageService.showErrorSnackBar(context,
            'Gagal memuat data tambahan dari server. Menggunakan data yang tersedia.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBiodataAndFamily() async {
    try {
      // Cek cache in-memory dulu (dishare dengan DatakuPage)
      final cachedData = CacheService()
          .get<Map<String, dynamic>>(BiodataCacheKeys.apiBiodataPayload);
      if (cachedData != null) {
        _applyBiodataData(cachedData);
        return;
      }

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
          CacheService().set<Map<String, dynamic>>(
            BiodataCacheKeys.apiBiodataPayload,
            jsonResp['data'],
            ttl: const Duration(minutes: 30),
          );
          _applyBiodataData(jsonResp['data']);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyBiodataData(Map<String, dynamic> data) {
    final newBiodata = Map<String, dynamic>.from(data['biodata'] ?? {});
    // Pertahankan nama wilayah yang sudah ter-resolve sebelumnya agar tidak hilang
    if (_currentData != null) {
      for (final key in [
        'province_name',
        'district_name',
        'sub_district_name',
        'village_name'
      ]) {
        if ((newBiodata[key] == null || newBiodata[key].toString().isEmpty) &&
            _currentData![key] != null &&
            _currentData![key].toString().isNotEmpty) {
          newBiodata[key] = _currentData![key];
        }
      }
    }

    setState(() {
      _currentData = newBiodata;
      _familyMembers =
          List<Map<String, dynamic>>.from(data['family_members'] ?? []);
      _jobs = List<Map<String, dynamic>>.from(data['jobs'] ?? []);
      _isLoading = false;
    });

    // Tambahkan data user sendiri ke daftar keluarga jika belum ada
    if (_currentData != null && _currentData!.isNotEmpty) {
      final userNik = _currentData!['nik']?.toString();
      final userExists =
          _familyMembers.any((member) => member['nik']?.toString() == userNik);

      if (!userExists && userNik != null) {
        _familyMembers.insert(0, _currentData!);
      }
    }

    // Initialize dropdown options
    _initializeDropdownOptions();
    _populateFormFields();
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
      // noop log
    }

    // Validasi education levels
    final educationIds = _educationLevels.map((e) => e['id']).toList();
    final educationDuplicates = educationIds
        .where((id) => educationIds.indexOf(id) != educationIds.lastIndexOf(id))
        .toList();
    if (educationDuplicates.isNotEmpty) {
      // noop log
    }

    // Validasi jobs
    final jobIds = _jobs.map((e) => e['id']?.toString()).toList();
    final jobDuplicates = jobIds
        .where((id) => jobIds.indexOf(id) != jobIds.lastIndexOf(id))
        .toList();
    if (jobDuplicates.isNotEmpty) {
      // noop log
    }
  }

  String? _validateAndSetDropdownValue(
      String? value, List<Map<String, dynamic>> options, String type) {
    if (value == null || value.isEmpty) {
      return null;
    }

    // Cek apakah value ada dalam options berdasarkan ID
    final validIds = options.map((e) => e['id']?.toString()).toList();
    if (validIds.contains(value)) {
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
      return foundId;
    }

    return null;
  }

  Future<String> _getLocationName(String idKey, String nameKey) async {
    if (_currentData == null) return '';

    // Coba ambil nama langsung dulu
    final nameValue = _currentData![nameKey];
    if (nameValue != null && nameValue.toString().isNotEmpty) {
      return nameValue.toString();
    }

    // Jika nama tidak ada, coba konversi dari ID menggunakan WilayahService
    final idValue = _currentData![idKey];
    if (idValue != null) {
      try {
        final wilayahService = WilayahService();
        Map<String, dynamic>? locationData;

        if (idKey == 'province_id') {
          locationData = await wilayahService.getProvince(idValue.toString());
        } else if (idKey == 'district_id') {
          locationData = await wilayahService.getDistrict(
              idValue.toString(), _currentData?['province_id']?.toString());
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
          return name;
        }
      } catch (_) {}

      // Fallback ke ID jika konversi gagal
      return 'ID: $idValue';
    }

    return '';
  }

  void _clearAllFields() {
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
  }

  void _populateFormFieldsSync() {
    _clearAllFields();

    final nikValue = _currentData?['nik']?.toString() ?? widget.penduduk.nik;
    final nameValue = _currentData?['full_name'] ??
        _currentData?['name'] ??
        widget.penduduk.name;
    final kkValue = _currentData?['kk']?.toString() ?? '';

    _nikController.text = nikValue;
    _nameController.text = nameValue;
    _kkController.text = kkValue;

    final genderValue = _currentData?['gender'];
    String genderText = '';
    if (genderValue is int) {
      genderText = genderValue == 1 ? 'Laki-laki' : 'Perempuan';
    } else if (genderValue is String) {
      genderText = genderValue;
    }
    _jenisKelaminController.text = genderText;

    _umurController.text = _currentData?['age']?.toString() ?? '';
    _tempatLahirController.text =
        _currentData?['birth_place']?.toString() ?? '';
    _tanggalLahirController.text =
        _currentData?['birth_date']?.toString() ?? '';
    _alamatController.text = _currentData?['address']?.toString() ?? '';
    _rtController.text = _currentData?['rt']?.toString() ?? '';
    _rwController.text = _currentData?['rw']?.toString() ?? '';

    // Nama wilayah jika sudah ada
    final provName = _currentData?['province_name']?.toString() ?? '';
    final distName = _currentData?['district_name']?.toString() ?? '';
    final subName = _currentData?['sub_district_name']?.toString() ?? '';
    final villName = _currentData?['village_name']?.toString() ?? '';

    if (provName.isNotEmpty) _provinsiController.text = provName;
    if (distName.isNotEmpty) _kabupatenController.text = distName;
    if (subName.isNotEmpty) _kecamatanController.text = subName;
    if (villName.isNotEmpty) _desaController.text = villName;

    // Dropdown values
    final bloodTypeValue = _currentData?['blood_type']?.toString() ??
        _currentData?['golongan_darah']?.toString() ??
        _currentData?['bloodtype']?.toString();
    final educationValue = _currentData?['education_status']?.toString() ??
        _currentData?['pendidikan']?.toString() ??
        _currentData?['education']?.toString();
    final jobValue = _currentData?['job_type_id']?.toString() ??
        _currentData?['pekerjaan_id']?.toString() ??
        _currentData?['job_id']?.toString();

    _selectedBloodType =
        _validateAndSetDropdownValue(bloodTypeValue, _bloodTypes, 'blood_type');
    _selectedEducation = _validateAndSetDropdownValue(
        educationValue, _educationLevels, 'education');
    _selectedJob = _validateAndSetDropdownValue(jobValue, _jobs, 'job');

    if (_selectedBloodType != null &&
        !_bloodTypes.any((item) => item['id'] == _selectedBloodType)) {
      _selectedBloodType = null;
    }
    if (_selectedEducation != null &&
        !_educationLevels.any((item) => item['id'] == _selectedEducation)) {
      _selectedEducation = null;
    }
    if (_selectedJob != null &&
        !_jobs.any((item) => item['id']?.toString() == _selectedJob)) {
      _selectedJob = null;
    }

    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }

    // Resolusi nama wilayah di background jika belum lengkap
    if (provName.isEmpty ||
        distName.isEmpty ||
        subName.isEmpty ||
        villName.isEmpty) {
      _resolveLocationNamesInBackground();
    }
  }

  Future<void> _resolveLocationNamesInBackground() async {
    if (!mounted || _currentData == null) return;
    try {
      final provName = _currentData?['province_name']?.toString() ?? '';
      final distName = _currentData?['district_name']?.toString() ?? '';
      final subName = _currentData?['sub_district_name']?.toString() ?? '';
      final villName = _currentData?['village_name']?.toString() ?? '';

      final results = await Future.wait<String>([
        provName.isNotEmpty
            ? Future.value(provName)
            : _getLocationName('province_id', 'province_name'),
        distName.isNotEmpty
            ? Future.value(distName)
            : _getLocationName('district_id', 'district_name'),
        subName.isNotEmpty
            ? Future.value(subName)
            : _getLocationName('sub_district_id', 'sub_district_name'),
        villName.isNotEmpty
            ? Future.value(villName)
            : _getLocationName('village_id', 'village_name'),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].isNotEmpty) _provinsiController.text = results[0];
          if (results[1].isNotEmpty) _kabupatenController.text = results[1];
          if (results[2].isNotEmpty) _kecamatanController.text = results[2];
          if (results[3].isNotEmpty) _desaController.text = results[3];
        });
      }
    } catch (_) {}
  }

  Future<void> _populateFormFields() async {
    _populateFormFieldsSync();
  }

  Future<void> _requestAdminApproval() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRequestingApproval = true);

    try {
      // Ambil token dari storage
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

      if (_selectedNik == null || _selectedNik!.isEmpty) {
        throw Exception('Pilih anggota keluarga terlebih dahulu.');
      }

      final normalizedGender = _normalizeGender(_jenisKelaminController.text);
      if (normalizedGender == null) {
        throw Exception("Jenis kelamin harus 'Laki-laki' atau 'Perempuan'.");
      }

      if (_currentData?['province_id'] == null ||
          _currentData?['district_id'] == null ||
          _currentData?['sub_district_id'] == null ||
          _currentData?['village_id'] == null) {
        throw Exception(
            'Data wilayah tidak lengkap. Muat ulang data profil dan coba lagi.');
      }

      final Map<String, dynamic> payload = {
        'nik': _selectedNik!,
        'full_name': _nameController.text.isNotEmpty
            ? _nameController.text
            : (_currentData?['full_name'] ?? ''),
        'kk': _kkController.text.isNotEmpty
            ? _kkController.text
            : (_currentData?['kk'] ?? ''),
        'gender': normalizedGender,
        'age': _umurController.text.isNotEmpty
            ? int.tryParse(_umurController.text)
            : _currentData?['age'],
        'birth_place': _tempatLahirController.text.isNotEmpty
            ? _tempatLahirController.text
            : (_currentData?['birth_place'] ?? ''),
        'birth_date': _tanggalLahirController.text.isNotEmpty
            ? _tanggalLahirController.text
            : (_currentData?['birth_date'] ?? ''),
        'address': _alamatController.text.isNotEmpty
            ? _alamatController.text
            : (_currentData?['address'] ?? ''),
        'rt': _rtController.text.isNotEmpty
            ? _rtController.text
            : (_currentData?['rt'] ?? ''),
        'rw': _rwController.text.isNotEmpty
            ? _rwController.text
            : (_currentData?['rw'] ?? ''),
        'province_id': _currentData?['province_id'] ?? 0,
        'district_id': _currentData?['district_id'] ?? 0,
        'sub_district_id': _currentData?['sub_district_id'] ?? 0,
        'village_id': _currentData?['village_id'] ?? 0,
        'blood_type': _selectedBloodType ?? (_currentData?['blood_type'] ?? ''),
        'education_status':
            _selectedEducation ?? (_currentData?['education_status'] ?? ''),
        'job_type_id': _selectedJob != null
            ? int.tryParse(_selectedJob!)
            : _currentData?['job_type_id'],
      };

      final response = await http.post(
        Uri.parse('${AppConstants.authApiUrl}/biodata/request-update'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String msg = responseData['message'] ??
            'Permintaan perubahan data telah dikirim ke admin desa. Silakan tunggu persetujuan.';
        final bool isPending = responseData['is_pending_alert'] == true;

        // Invalidate cache supaya perubahan tidak tertimpa data lama
        CacheService().invalidate(BiodataCacheKeys.apiBiodataPayload);

        if (mounted) {
          if (isPending) {
            MessageService.showInfoSnackBar(context, msg);
          } else {
            MessageService.showSuccessSnackBar(context, msg);
          }
          Navigator.pop(context);
        }
      } else {
        String serverMessage =
            'Gagal mengirim permintaan: ${response.statusCode}';
        try {
          final Map<String, dynamic> body = json.decode(response.body);
          final msg = body['message'] ?? body['error'] ?? body['status'] ?? '';
          if (msg is String && msg.isNotEmpty) {
            serverMessage = msg;
          }
          if (response.statusCode == 422 && body['errors'] != null) {
            serverMessage = 'Validasi gagal: ${body['errors'].toString()}';
          }
        } catch (_) {}
        throw Exception(serverMessage);
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(
            context, 'Gagal mengirim permintaan: ${e.toString()}');
      }
    } finally {
      setState(() => _isRequestingApproval = false);
    }
  }

  String? _normalizeGender(String input) {
    final value = input.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'laki-laki' ||
        value == 'laki laki' ||
        value == 'l' ||
        value == 'male' ||
        value == 'pria') {
      return 'Laki-laki';
    }
    if (value == 'perempuan' ||
        value == 'p' ||
        value == 'female' ||
        value == 'wanita') {
      return 'Perempuan';
    }
    return null;
  }

  // Komponen Label yang lebih elegan
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569), // Warna slate yang modern
        ),
      ),
    );
  }

  // Komponen Header Section
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white, // Background terang dan bersih
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Edit Biodata',
            style: TextStyle(
              color:
                  AppTheme.primaryColor, // Teks biru gelap yang lebih berwibawa
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        ),
        body: Stack(children: [
          Form(
            key: _formKey,
            child: KeyedSubtree(
              key: ValueKey(_refreshKey),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  _buildSectionHeader(
                      'Data Pribadi', Icons.person_outline_rounded),

                  // Dropdown NIK
                  _buildNikDropdown(),

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

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _rtController,
                          label: 'RT',
                          enabled: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _rwController,
                          label: 'RW',
                          enabled: false,
                        ),
                      ),
                    ],
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

                  const SizedBox(height: 8),

                  // Golongan Darah
                  _buildBloodTypeDropdown(),

                  // Pendidikan Terakhir
                  _buildEducationDropdown(),

                  // Pekerjaan
                  _buildJobDropdown(),

                  const SizedBox(height: 16),

                  // Tombol Request Approval
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          _isRequestingApproval ? null : _requestAdminApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor:
                            AppTheme.primaryColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRequestingApproval
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
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
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Kotak Informasi Biru (Clean and Modern)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF), // Indigo 50
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFC7D2FE)), // Indigo 200
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFF4338CA), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Perubahan data akan diproses setelah mendapat persetujuan dari admin desa',
                            style: TextStyle(
                              color: Color(0xFF4338CA),
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ]));
  }

  // Desain TextField yang elegan
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextFormField(
            key: ValueKey('${label}_$_refreshKey'),
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            enabled: enabled,
            validator: validator,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF1E293B),
              fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: enabled ? Colors.grey[300]! : Colors.transparent),
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
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNikDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Pilih Anggota Keluarga'),
          DropdownButtonFormField<String>(
            value: _selectedNik,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            hint: const Text(
              'Pilih anggota keluarga...',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _familyMembers.map((member) {
              final name = member['full_name'] ?? member['name'] ?? 'N/A';
              final nik = member['nik']?.toString() ?? '-';
              return DropdownMenuItem<String>(
                value: member['nik']?.toString(),
                child: Text(
                  '$nik - $name',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
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

  void _onNikChanged(String? selectedNik) async {
    if (selectedNik == null) return;

    // Isi instan dari data lokal anggota keluarga (tanpa menunggu API)
    final selectedMember = _familyMembers.firstWhere(
      (member) => member['nik']?.toString() == selectedNik,
      orElse: () => {},
    );

    setState(() {
      _selectedNik = selectedNik;
      if (selectedMember.isNotEmpty) {
        _currentData = selectedMember;
      } else {
        // Hanya tampilkan spinner jika tidak ada data lokal sama sekali
        _isLoading = true;
        _currentData = null;
      }
      _refreshKey++;
    });

    // Refresh data terbaru dari API (di belakang) lalu update ulang form
    await _loadMemberData(selectedNik);
  }

  Future<void> _loadMemberData(String nik) async {
    final token = ++_memberLoadToken;
    bool isStale() => !mounted || token != _memberLoadToken;
    final cache = CacheService();

    try {
      // Cek cache detail penduduk untuk NIK ini
      final cachedDetail = cache
          .get<Map<String, dynamic>>('${BiodataCacheKeys.citizenDetail}_$nik');
      if (cachedDetail != null) {
        if (!isStale()) {
          setState(() => _currentData = cachedDetail);
          await _populateFormFields();
        }
        if (mounted && _isLoading) setState(() => _isLoading = false);
        return;
      }

      final repository = GetIt.instance<AuthRepository>();
      final result = await repository.getPendudukDetail(nik);

      result.fold(
        (failure) async {
          // Data lokal sudah diisi di _onNikChanged; tampilkan error saja jika kosong
          if (isStale()) return;
          if (_currentData == null || _currentData!.isEmpty) {
            setState(() => _isLoading = false);
            await _fallbackToFamilyMemberData(nik);
            if (mounted) setState(() => _isLoading = false);
          } else if (mounted && _isLoading) {
            setState(() => _isLoading = false);
          }
        },
        (data) async {
          if (isStale()) return;
          cache.set<Map<String, dynamic>>(
            '${BiodataCacheKeys.citizenDetail}_$nik',
            data,
            ttl: const Duration(minutes: 5),
          );
          setState(() => _currentData = data);
          await _populateFormFields();
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      if (isStale()) return;
      await _fallbackToFamilyMemberData(nik);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fallbackToFamilyMemberData(String nik) async {
    final selectedMember = _familyMembers.firstWhere(
      (member) => member['nik']?.toString() == nik,
      orElse: () => {},
    );

    if (selectedMember.isNotEmpty) {
      setState(() {
        _currentData = selectedMember;
      });
      await _populateFormFields();
      if (mounted) {
        setState(() {});
      }
    } else {
      MessageService.showErrorSnackBar(
          context, 'Data anggota keluarga tidak ditemukan');
    }
  }

  Widget _buildBloodTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Golongan Darah'),
          DropdownButtonFormField<String>(
            value: _selectedBloodType,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            hint: const Text(
              'Pilih golongan darah',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _bloodTypes.map((bloodType) {
              return DropdownMenuItem<String>(
                value: bloodType['id'],
                child: Text(
                  bloodType['name'],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
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
          _buildLabel('Pendidikan Terakhir'),
          DropdownButtonFormField<String>(
            value: _selectedEducation,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            hint: const Text(
              'Pilih pendidikan terakhir',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _educationLevels.map((education) {
              return DropdownMenuItem<String>(
                value: education['id'],
                child: Text(
                  education['name'],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
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
          _buildLabel('Pekerjaan'),
          DropdownButtonFormField<String>(
            value: _selectedJob,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
            menuMaxHeight: 300,
            hint: const Text(
              'Pilih pekerjaan',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide:
                    BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _jobs.map((job) {
              return DropdownMenuItem<String>(
                value: job['id']?.toString(),
                child: Text(
                  job['name'] ?? job['job_name'] ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
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
