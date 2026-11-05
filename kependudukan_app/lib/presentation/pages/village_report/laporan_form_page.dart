import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/data/datasources/laporan_api_service.dart';
import 'package:ladimas/presentation/widgets/common/location_map_component.dart';
import 'package:ladimas/presentation/widgets/loading_indicator.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';

class LaporanFormPage extends StatefulWidget {
  const LaporanFormPage({Key? key}) : super(key: key);

  @override
  State<LaporanFormPage> createState() => _LaporanFormPageState();
}

class _LaporanFormPageState extends State<LaporanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  final VillageReportApiService _apiService =
      GetIt.instance<VillageReportApiService>();

  bool _isLoading = false;
  bool _isLoadingOptions = true;
  File? _selectedImage;
  final _imagePicker = ImagePicker();

  List<RuangLingkupData> _ruangLingkupOptions = [];
  RuangLingkupData? _selectedOption;

  // Default location - can be customized to current user's village
  LatLng _selectedLocation = const LatLng(-7.310000, 110.290000);
  final TextEditingController _addressController = TextEditingController();
  bool _isSearchingLocation = false;
  final TextEditingController _searchLocationController =
      TextEditingController();
  bool _isSearching = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadRuangLingkupOptions();

    // Dengarkan pergerakan peta untuk memakai center sebagai titik koordinat
    _mapController.mapEventStream.listen((event) {
      final center = _mapController.camera.center;
      if (event is MapEventMoveEnd) {
        setState(() {
          _selectedLocation = LatLng(center.latitude, center.longitude);
        });
        _reverseGeocode(_selectedLocation);
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        MessageService.showErrorSnackBar(
            context, 'Layanan lokasi tidak aktif. Aktifkan GPS Anda.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        MessageService.showErrorSnackBar(context, 'Izin lokasi ditolak.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        MessageService.showErrorSnackBar(context,
            'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final current = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedLocation = current);
      try {
        _mapController.move(current, 16.0);
      } catch (_) {}
      _reverseGeocode(current);
    } catch (e) {
      if (!mounted) return;
      MessageService.showErrorSnackBar(
          context, 'Gagal mendapatkan lokasi GPS: ${e.toString()}');
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isSearchingLocation = true);
    try {
      final resp = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1&accept-language=id'),
        headers: {'User-Agent': 'LADIMAS App'},
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(resp.body);
        final display = body['display_name'] ?? '';
        setState(() {
          _addressController.text = display.toString();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchLocationController.text.trim();
    if (query.isEmpty) {
      MessageService.showErrorSnackBar(
          context, 'Masukkan alamat yang ingin dicari');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=id'),
        headers: {
          'User-Agent': 'LADIMAS App',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = results.first;
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);

          final pos = LatLng(lat, lon);
          setState(() {
            _selectedLocation = pos;
            _addressController.text = result['display_name'] ?? query;
          });
          _mapController.move(pos, 15.0);
          MessageService.showSuccessSnackBar(
              context, 'Lokasi ditemukan: ${result['display_name']}');
        } else {
          MessageService.showErrorSnackBar(
              context, 'Lokasi tidak ditemukan. Coba kata kunci lain.');
        }
      } else {
        throw Exception('Gagal mencari lokasi');
      }
    } catch (e) {
      if (!mounted) return;
      MessageService.showErrorSnackBar(
          context, 'Gagal mencari lokasi: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadRuangLingkupOptions() async {
    try {
      setState(() {
        _isLoadingOptions = true;
      });

      final options = await _apiService.getLaporDesaOptions();

      if (!mounted) return;
      setState(() {
        _ruangLingkupOptions = options;
        _isLoadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOptions = false;
      });
      MessageService.showErrorSnackBar(
          context, 'Gagal memuat data ruang lingkup: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _addressController.dispose();
    _searchLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      MessageService.showErrorSnackBar(
          context, 'Gagal mengambil gambar: ${e.toString()}');
    }
  }

  Future<void> _submitLaporan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      MessageService.showErrorSnackBar(
          context, 'Mohon pilih gambar untuk laporan');
      return;
    }

    if (_selectedOption == null) {
      MessageService.showErrorSnackBar(
          context, 'Mohon pilih ruang lingkup laporan');
      return;
    }

    if (_selectedOption!.id <= 0) {
      MessageService.showErrorSnackBar(
          context, 'ID ruang lingkup tidak valid. Silakan pilih opsi lain.');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final locationString =
          "${_selectedLocation.latitude.toStringAsFixed(6)},${_selectedLocation.longitude.toStringAsFixed(6)}";

      final int ruangLingkupId = _selectedOption!.id;

      await _apiService.createVillageReport(
        judulLaporan: _judulController.text,
        deskripsiLaporan: _deskripsiController.text,
        tagLokasi: locationString,
        gambar: _selectedImage!,
        ruangLingkupId: ruangLingkupId,
        tagLat: _selectedLocation.latitude,
        tagLng: _selectedLocation.longitude,
        locationAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      if (!mounted) return;
      MessageService.showSuccessSnackBar(
          context, 'Laporan berhasil dikirim dan sedang menunggu diproses.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      MessageService.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Buat Laporan Desa',
          style: TextStyle(
            color: AppTheme.primaryColor,
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
      body: _isLoading || _isLoadingOptions
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartu Informasi Pokok Laporan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ruang Lingkup dan Bidang
                          _buildFieldLabel(
                              label: 'Ruang Lingkup & Bidang',
                              isRequired: true),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<RuangLingkupData>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Pilih Ruang Lingkup',
                              hintStyle: const TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.category_rounded,
                                  size: 20, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppTheme.primaryColor, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.5),
                              ),
                            ),
                            initialValue: _selectedOption,
                            items: _ruangLingkupOptions.map((option) {
                              return DropdownMenuItem<RuangLingkupData>(
                                value: option,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        option.ruangLingkup,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        option.bidang,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedOption = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Ruang lingkup harus dipilih';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Judul Laporan
                          _buildFieldLabel(
                              label: 'Judul Laporan', isRequired: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _judulController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Contoh: Kerusakan Lampu Jalan RT 03',
                              hintStyle: const TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.title_rounded,
                                  size: 20, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppTheme.primaryColor, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Judul laporan harus diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Deskripsi Laporan
                          _buildFieldLabel(
                              label: 'Deskripsi Laporan', isRequired: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _deskripsiController,
                            minLines: 4,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                            decoration: InputDecoration(
                              hintText:
                                  'Jelaskan rincian kejadian, kondisi saat ini, atau dampak yang ditimbulkan secara lengkap...',
                              hintStyle: const TextStyle(
                                  fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.description_rounded,
                                  size: 20, color: Color(0xFF64748B)),
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.all(16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppTheme.primaryColor, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Deskripsi laporan harus diisi';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Kartu Lokasi Kejadian & Peta
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Lokasi Kejadian',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Komponen Peta
                          Container(
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: [
                                  LocationMapComponent(
                                    initialPosition: _selectedLocation,
                                    mode: MapMode.select,
                                    onLocationSelected: (position) {
                                      setState(() {
                                        _selectedLocation = position;
                                      });
                                      _reverseGeocode(position);
                                    },
                                    height: 220,
                                    mapController: _mapController,
                                    showCurrentMarker: false,
                                  ),
                                  // Marker pin tengah peta
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      ignoring: true,
                                      child: Center(
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Tombol Gunakan GPS
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(Icons.my_location_rounded,
                                  size: 16),
                              label:
                                  const Text('Gunakan Lokasi Saat Ini (GPS)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(
                                    color: AppTheme.primaryColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Cari Lokasi
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchLocationController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Cari alamat atau nama tempat...',
                                    hintStyle: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.search_rounded,
                                        size: 18, color: Color(0xFF64748B)),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppTheme.primaryColor,
                                          width: 1.5),
                                    ),
                                  ),
                                  onSubmitted: (_) => _searchLocation(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    _isSearching ? null : _searchLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSearching
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Cari',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Indikator Loading Reverse Geocoding
                          if (_isSearchingLocation) ...[
                            const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Mendapatkan alamat dari koordinat...',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Detail Koordinat & Alamat
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Titik Koordinat',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _addressController,
                                  maxLines: 2,
                                  style: const TextStyle(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Alamat lokasi kejadian (otomatis dari peta, dapat disesuaikan)',
                                    hintStyle: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(
                                        Icons.edit_location_alt_outlined,
                                        size: 18,
                                        color: Color(0xFF64748B)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.all(10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppTheme.primaryColor,
                                          width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Kartu Foto Bukti Kejadian
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel(
                              label: 'Foto Bukti Kejadian', isRequired: true),
                          const SizedBox(height: 8),
                          if (_selectedImage != null)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(15)),
                                    child: Image.file(
                                      _selectedImage!,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _pickImage,
                                            icon: const Icon(
                                                Icons.photo_library_rounded,
                                                size: 16),
                                            label: const Text(
                                              'Ganti Foto',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primaryColor,
                                              side: const BorderSide(
                                                  color: AppTheme.primaryColor),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedImage = null;
                                            });
                                          },
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: Colors.red),
                                          label: const Text(
                                            'Hapus',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Colors.red),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 28),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 28,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Ambil / Pilih Foto Bukti',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Format JPG, PNG (Maksimal 5MB)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Submit Laporan
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitLaporan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Kirim Laporan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFieldLabel({required String label, required bool isRequired}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }
}
