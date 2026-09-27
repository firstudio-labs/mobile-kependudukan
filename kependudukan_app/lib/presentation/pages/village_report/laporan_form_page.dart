import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/data/datasources/laporan_api_service.dart';
import 'package:ladimas/presentation/widgets/common/location_map_component.dart';
import 'package:ladimas/presentation/widgets/custom_button.dart';
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
  bool _isSearchingLocation = false; // Reserved for showing loading state
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
      // Debounce sederhana: hanya saat gerakan berakhir atau jeda singkat
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
        MessageService.showErrorSnackBar(
            context, 'Layanan lokasi tidak aktif. Aktifkan GPS Anda.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        MessageService.showErrorSnackBar(context, 'Izin lokasi ditolak.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        MessageService.showErrorSnackBar(context,
            'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final current = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedLocation = current);
      // Gerakkan peta ke lokasi GPS
      try {
        _mapController.move(current, 16.0);
      } catch (_) {}
      _reverseGeocode(current);
    } catch (e) {
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

      setState(() {
        _ruangLingkupOptions = options;
        _isLoadingOptions = false;
      });
    } catch (e) {
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

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
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

    // Validate that the ID is a valid integer
    if (_selectedOption!.id <= 0) {
      MessageService.showErrorSnackBar(
          context, 'ID ruang lingkup tidak valid. Silakan pilih opsi lain.');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Format coordinates with exactly 6 decimal places for consistency and accuracy
      final locationString =
          "${_selectedLocation.latitude.toStringAsFixed(6)},${_selectedLocation.longitude.toStringAsFixed(6)}";

      // Ensure we're using the integer ID
      final int ruangLingkupId = _selectedOption!.id;
      print(
          "Selected ruang lingkup ID: $ruangLingkupId (${ruangLingkupId.runtimeType})");

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

      MessageService.showSuccessSnackBar(
          context, 'Laporan berhasil dikirim dan sedang menunggu diproses.');
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      MessageService.showErrorSnackBar(context, e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Laporan Desa'),
        backgroundColor: const Color(0xFF4A47DC),
        foregroundColor: Colors.white,
      ),
      body: _isLoading || _isLoadingOptions
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ruang Lingkup dan Bidang
                    const Text(
                      'Ruang Lingkup dan Bidang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RuangLingkupData>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Pilih Ruang Lingkup',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      ),
                      value: _selectedOption,
                      items: _ruangLingkupOptions.map((option) {
                        return DropdownMenuItem<RuangLingkupData>(
                          value: option,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                option.ruangLingkup,
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                option.bidang,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
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

                    const SizedBox(height: 16),

                    // Judul Laporan
                    const Text(
                      'Judul Laporan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _judulController,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan judul laporan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Judul laporan harus diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi Laporan
                    const Text(
                      'Deskripsi Laporan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _deskripsiController,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan deskripsi lengkap laporan',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Deskripsi laporan harus diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Location Map
                    const Text(
                      'Lokasi Kejadian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        LocationMapComponent(
                          initialPosition: _selectedLocation,
                          mode: MapMode.select,
                          onLocationSelected: (position) {
                            setState(() {
                              _selectedLocation = position;
                            });
                            _reverseGeocode(position);
                            print(
                                "Selected location: ${position.latitude}, ${position.longitude}");
                          },
                          height: 250,
                          mapController: _mapController,
                          showCurrentMarker: false,
                        ),
                        // Marker lingkaran biru di tengah peta (mirip domisili)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: true,
                            child: Center(
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
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Search bar mirip halaman domisili
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
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
                                  onPressed:
                                      _isSearching ? null : _searchLocation,
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
                                  label: Text(
                                      _isSearching ? 'Mencari...' : 'Cari'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _useCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Gunakan GPS'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isSearchingLocation)
                      Row(
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Mengambil alamat dari koordinat ...'),
                        ],
                      ),
                    if (_isSearchingLocation) const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koordinat Terpilih:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Latitude: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Longitude: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText:
                                    'Alamat lokasi kejadian (otomatis dari peta, bisa diedit)',
                                prefixIcon: const Icon(Icons.place_outlined),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image Picker
                    const Text(
                      'Foto Kejadian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 40,
                                      color: AppTheme.primaryColor,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Pilih Foto',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    Center(
                      child: CustomButton(
                        text: '+ Kirim Laporan',
                        onPressed: _submitLaporan,
                        backgroundColor: const Color(0xFF4A47DC),
                        width: 200,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
