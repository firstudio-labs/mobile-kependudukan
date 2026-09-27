import 'package:flutter/material.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BiodataEditPage extends StatefulWidget {
  final Penduduk penduduk;

  const BiodataEditPage({Key? key, required this.penduduk}) : super(key: key);

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

    // Populate form dengan data dari widget.penduduk sebagai fallback
    _nikController.text = widget.penduduk.nik;
    _nameController.text = widget.penduduk.name;
    _selectedNik = widget.penduduk.nik;

    // Load data tambahan dari API menggunakan AuthRepository
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
    setState(() => _isLoading = true);

    try {
      // Load biodata dan data keluarga dari API baru
      await _loadBiodataAndFamily();
    } catch (e) {
      MessageService.showErrorSnackBar(context,
          'Gagal memuat data tambahan dari server. Menggunakan data yang tersedia.');
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
            _jobs = List<Map<String, dynamic>>.from(data['jobs'] ?? []);
            _isLoading = false;
          });

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
        setState(() => _isLoading = false);
      }
    } catch (e) {
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
          return name;
        }
      } catch (e) {}

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

  Future<void> _populateFormFields() async {
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

    final ageValue = _currentData?['age']?.toString() ?? '';
    final birthPlaceValue = _currentData?['birth_place'] ?? '';
    final birthDateValue = _currentData?['birth_date'] ?? '';
    final addressValue = _currentData?['address'] ?? '';
    final rtValue = _currentData?['rt']?.toString() ?? '';
    final rwValue = _currentData?['rw']?.toString() ?? '';

    _umurController.text = ageValue;
    _tempatLahirController.text = birthPlaceValue;
    _tanggalLahirController.text = birthDateValue;
    _alamatController.text = addressValue;
    _rtController.text = rtValue;
    _rwController.text = rwValue;

    // Field lokasi - ambil dari ID dan konversi ke nama (async)
    _provinsiController.text =
        await _getLocationName('province_id', 'province_name');
    _kabupatenController.text =
        await _getLocationName('district_id', 'district_name');
    _kecamatanController.text =
        await _getLocationName('sub_district_id', 'sub_district_name');
    _desaController.text = await _getLocationName('village_id', 'village_name');

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

    // Validasi dan set dropdown values
    _selectedBloodType =
        _validateAndSetDropdownValue(bloodTypeValue, _bloodTypes, 'blood_type');
    _selectedEducation = _validateAndSetDropdownValue(
        educationValue, _educationLevels, 'education');
    _selectedJob = _validateAndSetDropdownValue(jobValue, _jobs, 'job');

    // Final setState untuk memastikan semua field terupdate
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }

    // Validasi bahwa nilai yang dipilih ada di daftar dropdown
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

    setState(() {});
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
            : (_currentData?['age'] ?? null),
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
            : (_currentData?['job_type_id'] ?? null),
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
      MessageService.showErrorSnackBar(
          context, 'Gagal mengirim permintaan: ${e.toString()}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Edit Biodata',
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
                        label: 'Tanggal Lahir',
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

                      const SizedBox(height: 20),

                      // Golongan Darah
                      _buildBloodTypeDropdown(),

                      // Pendidikan Terakhir
                      _buildEducationDropdown(),

                      // Pekerjaan
                      _buildJobDropdown(),

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

  void _onNikChanged(String? selectedNik) async {
    if (selectedNik != null) {
      setState(() {
        _selectedNik = selectedNik;
        _isLoading = true;
        _currentData = null; // Reset current data
        _refreshKey++; // Increment refresh key untuk memaksa rebuild
      });

      try {
        // Load data lengkap untuk NIK yang dipilih
        await _loadMemberData(selectedNik);
      } catch (e) {
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
    try {
      final repository = GetIt.instance<AuthRepository>();
      final result = await repository.getPendudukDetail(nik);

      result.fold(
        (failure) async {
          await _fallbackToFamilyMemberData(nik);
        },
        (data) async {
          if (mounted) {
            setState(() {
              _currentData = data;
            });
            await _populateFormFields();
          }
        },
      );
    } catch (e) {
      await _fallbackToFamilyMemberData(nik);
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
