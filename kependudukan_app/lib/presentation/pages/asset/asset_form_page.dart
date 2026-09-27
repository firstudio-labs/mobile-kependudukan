import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/services/message_service.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/cubits/asset/asset_cubit.dart';
import 'package:ladimas/presentation/cubits/asset/asset_state.dart';
import 'package:ladimas/presentation/widgets/asset/asset_form_dropdown.dart';
import 'package:ladimas/presentation/widgets/asset/asset_form_image_picker.dart';
import 'package:ladimas/presentation/widgets/asset/asset_form_text_field.dart';
import 'package:ladimas/presentation/widgets/common/location_map_component.dart'
    show LocationMapComponent, MapMode;
import 'package:ladimas/presentation/widgets/common/nik_dropdown_field.dart';
import 'package:ladimas/presentation/widgets/custom_button.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';

class AssetFormPage extends StatefulWidget {
  final int? assetId;
  const AssetFormPage({Key? key, this.assetId}) : super(key: key);

  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final AssetCubit _assetCubit;
  bool _isEditing = false;

  // Controllers
  final _nikController = TextEditingController();
  final _namaPemilikController = TextEditingController();
  final _namaAsetController = TextEditingController();
  final _alamatController = TextEditingController();
  final _rtController = TextEditingController();
  final _rwController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _searchLocationController = TextEditingController();

  // Dropdown values
  String? _selectedProvinceId;
  String? _selectedDistrictId;
  String? _selectedSubdistrictId;
  String? _selectedVillageId;
  String? _selectedKlasifikasiId;
  String? _selectedJenisAsetId;

  // Data storage
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _subdistricts = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _klasifikasi = [];
  List<Map<String, dynamic>> _jenisAset = [];

  // Files
  File? _fotoDepan;
  File? _fotoSamping;

  // State
  bool _isLoading = false;
  bool _isSearchingAddress = false;
  bool _isSearching = false;

  // Map position
  LatLng _assetPosition = const LatLng(-6.200000, 106.816666);
  double _assetLatitude = -6.200000;
  double _assetLongitude = 106.816666;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _assetCubit = GetIt.instance<AssetCubit>();
    _isEditing = widget.assetId != null;
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadProvinces(),
        _loadKlasifikasi(),
        _loadJenisAset(),
      ]);

      if (_isEditing) {
        await _loadAssetData();
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssetData() async {
    try {
      await _assetCubit.loadAssetDetail(widget.assetId!);
      final state = _assetCubit.state;
      if (state is AssetDetailLoaded) {
        final asset = state.asset;
        setState(() {
          _nikController.text = asset.nikPemilik;
          _namaPemilikController.text = asset.namaPemilik;
          _namaAsetController.text = asset.namaAset;
          _alamatController.text = asset.alamat;
          _rtController.text = asset.rt ?? '';
          _rwController.text = asset.rw ?? '';
          _selectedProvinceId = asset.provinceId?.toString();
          _selectedDistrictId = asset.districtId?.toString();
          _selectedSubdistrictId = asset.subdistrictId?.toString();
          _selectedVillageId = asset.villageId?.toString();
          _selectedKlasifikasiId = asset.klasifikasiDetail.id.toString();
          _selectedJenisAsetId = asset.jenisAsetDetail.id.toString();

          if (asset.tagLokasi != null) {
            final coordinates = asset.tagLokasi!.split(',');
            if (coordinates.length == 2) {
              _assetLatitude =
                  double.tryParse(coordinates[0]) ?? _assetLatitude;
              _assetLongitude =
                  double.tryParse(coordinates[1]) ?? _assetLongitude;
              _assetPosition = LatLng(_assetLatitude, _assetLongitude);
              // Autoload alamat dari koordinat jika alamat kosong
              if (_alamatController.text.trim().isEmpty) {
                _reverseGeocode(_assetPosition);
              }
            }
          }
        });

        // Load wilayah data secara berurutan
        if (asset.provinceId != null) {
          // Cari province code dari provinces yang sudah dimuat
          final province = _provinces.firstWhere(
            (p) => p['id'].toString() == asset.provinceId.toString(),
            orElse: () => {},
          );
          if (province.containsKey('code')) {
            await _loadDistricts(province['code']);

            if (asset.districtId != null) {
              final district = _districts.firstWhere(
                (d) => d['id'].toString() == asset.districtId.toString(),
                orElse: () => {},
              );
              if (district.containsKey('code')) {
                await _loadSubdistricts(district['code']);

                if (asset.subdistrictId != null) {
                  final subdistrict = _subdistricts.firstWhere(
                    (sd) =>
                        sd['id'].toString() == asset.subdistrictId.toString(),
                    orElse: () => {},
                  );
                  if (subdistrict.containsKey('code')) {
                    await _loadVillages(subdistrict['code']);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(context, e.toString());
      }
    }
  }

  @override
  void dispose() {
    _nikController.dispose();
    _namaPemilikController.dispose();
    _namaAsetController.dispose();
    _alamatController.dispose();
    _rtController.dispose();
    _rwController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _searchLocationController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isSearchingAddress = true);
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
          _alamatController.text = display.toString();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
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
        headers: {'User-Agent': 'LADIMAS App'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = results.first;
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);
          final pos = LatLng(lat, lon);
          setState(() {
            _assetPosition = pos;
            _assetLatitude = lat;
            _assetLongitude = lon;
            _alamatController.text = result['display_name'] ?? query;
          });
          _mapController.move(pos, 15.0);
          MessageService.showSuccessSnackBar(context, 'Lokasi ditemukan');
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
          desiredAccuracy: LocationAccuracy.high);
      final current = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _assetPosition = current;
        _assetLatitude = current.latitude;
        _assetLongitude = current.longitude;
      });
      _mapController.move(current, 16.0);
      _reverseGeocode(current);
    } catch (e) {
      MessageService.showErrorSnackBar(
          context, 'Gagal mendapatkan lokasi GPS: ${e.toString()}');
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Create asset data
        final Map<String, dynamic> assetData = {
          'nama_aset': _namaAsetController.text,
          'nik_pemilik': _nikController.text,
          'nama_pemilik': _namaPemilikController.text,
          'address': _alamatController.text,
          'province_id': _selectedProvinceId,
          'district_id': _selectedDistrictId,
          'sub_district_id': _selectedSubdistrictId,
          'village_id': _selectedVillageId,
          'rt': _rtController.text,
          'rw': _rwController.text,
          'klasifikasi_id': _selectedKlasifikasiId,
          'jenis_aset_id': _selectedJenisAsetId,
          'tag_lat': _assetLatitude.toString(),
          'tag_lng': _assetLongitude.toString(),
        };

        if (_isEditing) {
          // Update existing asset
          await _assetCubit.updateAssetWithImages(
            widget.assetId!,
            assetData,
            _fotoDepan,
            _fotoSamping,
          );
        } else {
          // Create new asset
          await _assetCubit.createAssetWithImages(
            assetData,
            _fotoDepan,
            _fotoSamping,
          );
        }

        if (mounted) {
          MessageService.showSuccessSnackBar(
            context,
            _isEditing
                ? 'Aset berhasil diperbarui'
                : 'Aset berhasil ditambahkan',
          );

          // Refresh data before navigating back
          await _assetCubit.loadAssets();

          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (mounted) {
          // Display error message with proper formatting for validation errors
          MessageService.showErrorDialog(
            context,
            e.toString().replaceAll('. ', '.\n'),
            title: _isEditing
                ? 'Gagal Memperbarui Aset'
                : 'Gagal Menambahkan Aset',
          );
        }
      }
    } else {
      // Form validation failed
      MessageService.showErrorSnackBar(
        context,
        'Harap periksa kembali form Anda',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Aset' : 'Tambah Aset',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<AssetCubit, AssetState>(
        bloc: _assetCubit,
        listener: (context, state) {
          if (state is AssetError) {
            MessageService.showErrorSnackBar(context, state.message);
          } else if (state is AssetSubmitted) {
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          return _buildForm(state);
        },
      ),
    );
  }

  Widget _buildForm(AssetState state) {
    final isSubmitting = state is AssetSubmitting || _isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Informasi Pemilik'),
            NikDropdownField(
              nikController: _nikController,
              nameController: _namaPemilikController,
              onSelected: (nik, name) {
                _nikController.text = nik;
                _namaPemilikController.text = name;
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Informasi Aset'),
            AssetFormTextField(
              controller: _namaAsetController,
              label: 'Nama Aset',
              validator: (value) =>
                  value!.isEmpty ? 'Nama aset harus diisi' : null,
            ),
            const SizedBox(height: 16),
            AssetFormDropdown(
              value: _selectedKlasifikasiId,
              items: _klasifikasi.map((item) {
                return DropdownMenuItem(
                  value: item['id'].toString(),
                  child: Text(item['jenis_klasifikasi']),
                );
              }).toList(),
              hint: 'Pilih Klasifikasi',
              onChanged: (value) {
                setState(() {
                  _selectedKlasifikasiId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Klasifikasi harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            AssetFormDropdown(
              value: _selectedJenisAsetId,
              items: _jenisAset.map((item) {
                return DropdownMenuItem(
                  value: item['id'].toString(),
                  child: Text(item['jenis_aset']),
                );
              }).toList(),
              hint: 'Pilih Jenis Aset',
              onChanged: (value) {
                setState(() {
                  _selectedJenisAsetId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Jenis aset harus dipilih' : null,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Alamat'),
            AssetFormTextField(
              controller: _alamatController,
              label: 'Alamat',
              maxLines: 3,
              validator: (value) =>
                  value!.isEmpty ? 'Alamat harus diisi' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AssetFormTextField(
                    controller: _rtController,
                    label: 'RT',
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'RT harus diisi' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AssetFormTextField(
                    controller: _rwController,
                    label: 'RW',
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'RW harus diisi' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AssetFormDropdown(
              value: _selectedProvinceId,
              items: _provinces.map((province) {
                return DropdownMenuItem(
                  value: province['id'].toString(),
                  child: Text(province['name']),
                );
              }).toList(),
              hint: 'Pilih Provinsi',
              onChanged: (value) {
                setState(() {
                  _selectedProvinceId = value;
                  _selectedDistrictId = null;
                  _selectedSubdistrictId = null;
                  _selectedVillageId = null;
                });
                if (value != null) {
                  final province = _provinces.firstWhere(
                      (element) => element['id'].toString() == value);
                  _loadDistricts(province['code']);
                }
              },
              validator: (value) =>
                  value == null ? 'Provinsi harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            AssetFormDropdown(
              value: _selectedDistrictId,
              items: _districts.map((district) {
                return DropdownMenuItem(
                  value: district['id'].toString(),
                  child: Text(district['name']),
                );
              }).toList(),
              hint: 'Pilih Kabupaten/Kota',
              onChanged: (value) {
                setState(() {
                  _selectedDistrictId = value;
                  _selectedSubdistrictId = null;
                  _selectedVillageId = null;
                });
                if (value != null) {
                  final district = _districts.firstWhere(
                      (element) => element['id'].toString() == value);
                  _loadSubdistricts(district['code']);
                }
              },
              validator: (value) =>
                  value == null ? 'Kabupaten/Kota harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            AssetFormDropdown(
              value: _selectedSubdistrictId,
              items: _subdistricts.map((subdistrict) {
                return DropdownMenuItem(
                  value: subdistrict['id'].toString(),
                  child: Text(subdistrict['name']),
                );
              }).toList(),
              hint: 'Pilih Kecamatan',
              onChanged: (value) {
                setState(() {
                  _selectedSubdistrictId = value;
                  _selectedVillageId = null;
                });
                if (value != null) {
                  final subdistrict = _subdistricts.firstWhere(
                      (element) => element['id'].toString() == value);
                  _loadVillages(subdistrict['code']);
                }
              },
              validator: (value) =>
                  value == null ? 'Kecamatan harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            AssetFormDropdown(
              value: _selectedVillageId,
              items: _villages.map((village) {
                return DropdownMenuItem(
                  value: village['id'].toString(),
                  child: Text(village['name']),
                );
              }).toList(),
              hint: 'Pilih Desa/Kelurahan',
              onChanged: (value) {
                setState(() {
                  _selectedVillageId = value;
                });
              },
              validator: (value) =>
                  value == null ? 'Desa/Kelurahan harus dipilih' : null,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Lokasi'),
            const Text(
              'Lokasi Aset',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  LocationMapComponent(
                    initialPosition: _assetPosition,
                    mode: MapMode.select,
                    onLocationSelected: (position) {
                      setState(() {
                        _assetPosition = position;
                        _assetLatitude = position.latitude;
                        _assetLongitude = position.longitude;
                      });
                      _reverseGeocode(position);
                    },
                    height: 250,
                    mapController: _mapController,
                    showCurrentMarker: false,
                  ),
                  // Marker lingkaran biru di tengah peta
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            child: Icon(Icons.location_on,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Search + GPS controls
            Card(
              margin: const EdgeInsets.only(bottom: 8),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchLocationController,
                            decoration: InputDecoration(
                              hintText:
                                  'Masukkan alamat (contoh: Jl. Sudirman, Jakarta)',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onSubmitted: (_) => _searchLocation(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: ElevatedButton.icon(
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
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_isSearching ? 'Mencari...' : 'Cari'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              minimumSize: const Size(120, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Gunakan GPS'),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Latitude: ${_assetLatitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Longitude: ${_assetLongitude.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (_isSearchingAddress) ...[
              const SizedBox(height: 8),
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
            ],
            const SizedBox(height: 24),
            _buildSectionTitle('Foto Aset'),
            Row(
              children: [
                Expanded(
                  child: AssetFormImagePicker(
                    label: 'Foto Depan',
                    initialImageUrl: state is AssetDetailLoaded &&
                            state.asset.fotoDepan != null
                        ? AppConstants.storageFileUrl(state.asset.fotoDepan)
                        : null,
                    onImageSelected: (image) {
                      setState(() {
                        _fotoDepan = image;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AssetFormImagePicker(
                    label: 'Foto Samping',
                    initialImageUrl: state is AssetDetailLoaded &&
                            state.asset.fotoSamping != null
                        ? AppConstants.storageFileUrl(state.asset.fotoSamping)
                        : null,
                    onImageSelected: (image) {
                      setState(() {
                        _fotoSamping = image;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Simpan',
              onPressed: _submitForm,
              isLoading: isSubmitting,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Future<void> _loadProvinces() async {
    final response = await http.get(
      Uri.parse('${AppConstants.goBaseUrl}/api/provinces'),
      headers: {'X-API-Key': AppConstants.apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('=== Provinces Data ===');
      print('Response: ${data['data']}');
      print('====================');
      setState(() {
        _provinces = List<Map<String, dynamic>>.from(data['data']);
      });
    } else {
      throw Exception('Failed to load provinces');
    }
  }

  Future<void> _loadDistricts(String provinceCode) async {
    setState(() => _districts = []);
    final response = await http.get(
      Uri.parse('${AppConstants.goBaseUrl}/api/districts/$provinceCode'),
      headers: {'X-API-Key': AppConstants.apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _districts = List<Map<String, dynamic>>.from(data['data']);
      });
    }
  }

  Future<void> _loadSubdistricts(String districtCode) async {
    setState(() => _subdistricts = []);
    final response = await http.get(
      Uri.parse('${AppConstants.goBaseUrl}/api/sub-districts/$districtCode'),
      headers: {'X-API-Key': AppConstants.apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        _subdistricts = List<Map<String, dynamic>>.from(data['data']);
      });
    }
  }

  Future<void> _loadVillages(String subdistrictCode) async {
    setState(() => _villages = []);
    final response = await http.get(
      Uri.parse('${AppConstants.goBaseUrl}/api/villages/$subdistrictCode'),
      headers: {'X-API-Key': AppConstants.apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        _villages = List<Map<String, dynamic>>.from(data['data']);
      });
    }
  }

  Future<void> _loadKlasifikasi() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/klasifikasi'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _klasifikasi = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          throw Exception('Failed to load klasifikasi: ${data['message']}');
        }
      } else {
        throw Exception(
            'Failed to load klasifikasi. Status: ${response.statusCode}');
      }
    } catch (e) {
      MessageService.showErrorSnackBar(
          context, 'Gagal memuat data klasifikasi: $e');
    }
  }

  Future<void> _loadJenisAset() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/jenis-aset'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _jenisAset = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          throw Exception('Failed to load jenis aset: ${data['message']}');
        }
      } else {
        throw Exception(
            'Failed to load jenis aset. Status: ${response.statusCode}');
      }
    } catch (e) {
      MessageService.showErrorSnackBar(
          context, 'Gagal memuat data jenis aset: $e');
    }
  }

  Future<void> _pickImage(bool isDepan) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (isDepan) {
            _fotoDepan = File(image.path);
          } else {
            _fotoSamping = File(image.path);
          }
        });
      }
    } catch (e) {
      MessageService.showErrorSnackBar(context, 'Gagal memilih gambar: $e');
    }
  }
}
