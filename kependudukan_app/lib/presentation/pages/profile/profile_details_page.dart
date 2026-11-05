import 'package:flutter/material.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/presentation/widgets/profile/profile_header.dart';
import 'package:ladimas/presentation/widgets/profile/update_phone_password_form.dart';
import 'package:ladimas/domain/entities/penduduk.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({
    Key? key,
    required this.nik,
    this.penduduk,
    this.biodata,
  }) : super(key: key);
  final String nik;
  final Penduduk? penduduk;
  final Map<String, dynamic>? biodata;

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.biodata != null || widget.penduduk != null) {
      _profileData = _normalizeProfileData({});
    }
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = GetIt.instance<AuthRepository>();
      final profileResult = await repository.getUserProfile();

      profileResult.fold(
        (failure) {
          _loadPendudukDetail(repository);
        },
        (data) {
          setState(() {
            _profileData = _normalizeProfileData(data);
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = MessageService.getErrorMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendudukDetail(AuthRepository repository) async {
    try {
      final result = await repository.getPendudukDetail(widget.nik);

      result.fold(
        (failure) {
          setState(() {
            _errorMessage = failure.message;
            _isLoading = false;
          });
        },
        (data) {
          setState(() {
            _profileData = _normalizeProfileData(data);
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = MessageService.getErrorMessage(e.toString());
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeProfileData(Map<String, dynamic> data) {
    return {
      'nik': data['nik']?.toString() ??
          data['id']?.toString() ??
          widget.biodata?['nik']?.toString() ??
          widget.penduduk?.nik ??
          '-',
      'kk': data['kk']?.toString() ??
          data['no_kk']?.toString() ??
          widget.biodata?['kk']?.toString() ??
          '-',
      'full_name': data['full_name']?.toString() ??
          data['name']?.toString() ??
          data['nama_lengkap']?.toString() ??
          widget.biodata?['full_name']?.toString() ??
          widget.penduduk?.name ??
          '-',
      'gender': data['gender']?.toString() ??
          data['jenis_kelamin']?.toString() ??
          widget.biodata?['gender']?.toString() ??
          '-',
      'age': data['age'] ?? data['umur'] ?? widget.biodata?['age'] ?? 0,
      'birth_place': data['birth_place']?.toString() ??
          data['tempat_lahir']?.toString() ??
          widget.biodata?['birth_place']?.toString() ??
          '-',
      'birth_date': data['birth_date']?.toString() ??
          data['tanggal_lahir']?.toString() ??
          widget.biodata?['birth_date']?.toString() ??
          '-',
      'address': data['address']?.toString() ??
          data['alamat']?.toString() ??
          widget.biodata?['address']?.toString() ??
          '-',
      'rt': data['rt']?.toString() ?? widget.biodata?['rt']?.toString() ?? '-',
      'rw': data['rw']?.toString() ?? widget.biodata?['rw']?.toString() ?? '-',
      'province_name': data['province_name']?.toString() ??
          data['provinsi']?.toString() ??
          '-',
      'district_name': data['district_name']?.toString() ??
          data['kabupaten']?.toString() ??
          '-',
      'sub_district_name': data['sub_district_name']?.toString() ??
          data['kecamatan']?.toString() ??
          '-',
      'village_name':
          data['village_name']?.toString() ?? data['desa']?.toString() ?? '-',
      'no_hp': data['no_hp']?.toString() ??
          data['phone']?.toString() ??
          widget.biodata?['no_hp']?.toString() ??
          widget.penduduk?.noHp ??
          '-',
      'blood_type': data['blood_type']?.toString() ??
          data['golongan_darah']?.toString() ??
          '-',
      'education_status': data['education_status']?.toString() ??
          data['pendidikan']?.toString() ??
          '-',
      'religion':
          data['religion']?.toString() ?? data['agama']?.toString() ?? '-',
      'marital_status': data['marital_status']?.toString() ??
          data['status_perkawinan']?.toString() ??
          '-',
      'family_status': data['family_status']?.toString() ??
          data['status_keluarga']?.toString() ??
          '-',
      'citizen_status': data['citizen_status']?.toString() ??
          data['status_kewarganegaraan']?.toString() ??
          '-',
    };
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '-';
    }
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Data Profil',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Cukup gunakan SingleChildScrollView satu kali di sini
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 100),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildProfileContent();
  }

  Widget _buildProfileContent() {
    // Hapus SingleChildScrollView & Padding ganda di sini
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileHeader(
          name: _profileData?['full_name'] ?? 'Tidak ada nama',
          nik: _profileData?['nik']?.toString() ?? '-',
        ),
        const SizedBox(height: 12), // Jarak disesuaikan jadi 12 agar rapat
        UpdatePhonePasswordForm(
          currentPhone: _profileData?['no_hp']?.toString() ?? '-',
          onSuccess: () {
            _loadProfileData();
          },
        ),
      ],
    );
  }
}
