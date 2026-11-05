import 'package:ladimas/data/datasources/auth_local_storage.dart';
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
import 'package:get_it/get_it.dart';
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
              if (_alamatController.text.trim().isEmpty) {
                _reverseGeocode(_assetPosition);
              }
            }
          }
        });

        // Load wilayah data secara berurutan
        if (asset.provinceId != null) {
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
          if (!mounted) return;
          _mapController.move(pos, 15.0);
          MessageService.showSuccessSnackBar(context, 'Lokasi ditemukan');
        } else {
          if (mounted) {
            MessageService.showErrorSnackBar(
                context, 'Lokasi tidak ditemukan. Coba kata kunci lain.');
          }
        }
      } else {
        throw Exception('Gagal mencari lokasi');
      }
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(
            context, 'Gagal mencari lokasi: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          MessageService.showErrorSnackBar(
              context, 'Layanan lokasi tidak aktif. Aktifkan GPS Anda.');
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          MessageService.showErrorSnackBar(context, 'Izin lokasi ditolak.');
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          MessageService.showErrorSnackBar(context,
              'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final current = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _assetPosition = current;
        _assetLatitude = current.latitude;
        _assetLongitude = current.longitude;
      });
      _mapController.move(current, 16.0);
      _reverseGeocode(current);
    } catch (e) {
      if (mounted) {
        MessageService.showErrorSnackBar(
            context, 'Gagal mendapatkan lokasi GPS: ${e.toString()}');
      }
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
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
          await _assetCubit.updateAssetWithImages(
            widget.assetId!,
            assetData,
            _fotoDepan,
            _fotoSamping,
          );
        } else {
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

          await _assetCubit.loadAssets();

          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (mounted) {
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
      MessageService.showErrorSnackBar(
        context,
        'Harap periksa kembali form Anda',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _isEditing ? 'Edit Aset' : 'Tambah Aset',
          style: const TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------ Informasi Pemilik
            _buildSectionHeader(
              'Informasi Pemilik',
              Icons.person_outline_rounded,
            ),
            NikDropdownField(
              nikController: _nikController,
              nameController: _namaPemilikController,
              onSelected: (nik, name) {
                _nikController.text = nik;
                _namaPemilikController.text = name;
              },
            ),
            _buildDivider(),

            // -------------------------------------------------- Informasi Aset
            _buildSectionHeader(
              'Informasi Aset',
              Icons.inventory_2_outlined,
            ),
            _gap(
              AssetFormTextField(
                controller: _namaAsetController,
                label: 'Nama Aset',
                validator: (value) =>
                    value!.isEmpty ? 'Nama aset harus diisi' : null,
              ),
            ),
            _gap(
              AssetFormDropdown(
                label: 'Klasifikasi',
                value: _selectedKlasifikasiId,
                items: _klasifikasi.map((item) {
                  return DropdownMenuItem(
                    value: item['id'].toString(),
                    child: Text(
                      item['jenis_klasifikasi'],
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ),
            _gap(
              AssetFormDropdown(
                label: 'Jenis Aset',
                value: _selectedJenisAsetId,
                items: _jenisAset.map((item) {
                  return DropdownMenuItem(
                    value: item['id'].toString(),
                    child: Text(
                      item['jenis_aset'],
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ),
            _buildDivider(),

            // ----------------------------------------------------------- Alamat
            _buildSectionHeader('Alamat', Icons.home_outlined),
            _gap(
              AssetFormTextField(
                controller: _alamatController,
                label: 'Alamat',
                maxLines: 3,
                validator: (value) =>
                    value!.isEmpty ? 'Alamat harus diisi' : null,
              ),
            ),
            _gap(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(width: 12),
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
            ),
            _gap(
              AssetFormDropdown(
                label: 'Provinsi',
                value: _selectedProvinceId,
                items: _provinces.map((province) {
                  return DropdownMenuItem(
                    value: province['id'].toString(),
                    child: Text(
                      province['name'],
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ),
            _gap(
              AssetFormDropdown(
                label: 'Kabupaten/Kota',
                value: _selectedDistrictId,
                items: _districts.map((district) {
                  return DropdownMenuItem(
                    value: district['id'].toString(),
                    child: Text(
                      district['name'],
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ),
            _gap(
              AssetFormDropdown(
                label: 'Kecamatan',
                value: _selectedSubdistrictId,
                items: _subdistricts.map((subdistrict) {
                  return DropdownMenuItem(
                    value: subdistrict['id'].toString(),
                    child: Text(
                      subdistrict['name'],
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ),
            _gap(
              AssetFormDropdown(
                label: 'Desa/Kelurahan',
                value: _selectedVillageId,
                items: _villages.map((village) {
                  return DropdownMenuItem(
                    value: village['id'].toString(),
                    child: Text(
                      village['name'],
                      overflow: TextOverflow.ellipsis,
                    ),
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
            ),
            _buildDivider(),

            // ----------------------------------------------------------- Lokasi
            _buildSectionHeader('Lokasi', Icons.location_on_outlined),
            _buildLabel('Titik Lokasi pada Peta'),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
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
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.fromBorderSide(
                                    BorderSide(color: Colors.white, width: 2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search bar & GPS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchLocationController,
                          decoration: InputDecoration(
                            hintText: 'Cari alamat atau tempat...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          onSubmitted: (_) => _searchLocation(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : _searchLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Gunakan Lokasi Saat Ini (GPS)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Coordinates display
            Row(
              children: [
                Expanded(
                  child: _buildCoordinateChip(
                    'Latitude',
                    _assetLatitude.toStringAsFixed(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoordinateChip(
                    'Longitude',
                    _assetLongitude.toStringAsFixed(6),
                  ),
                ),
              ],
            ),
            if (_isSearchingAddress) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Mengambil alamat otomatis dari koordinat...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _buildDivider(),

            // --------------------------------------------------------- Foto Aset
            _buildSectionHeader(
              'Foto Aset',
              Icons.photo_camera_outlined,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 28),

            // ----------------------------------------------------------- Tombol
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Simpan Perubahan' : 'Simpan Aset',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ------------------------------------------------------ Kotak info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pastikan data pemilik, spesifikasi aset, alamat, dan pin lokasi pada peta sudah sesuai sebelum disimpan.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _gap(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: child,
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
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

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-API-Key': AppConstants.apiKey,
    };
    try {
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();
      if (rawToken != null && rawToken.isNotEmpty) {
        final token =
            rawToken.contains('|') ? rawToken.split('|')[1] : rawToken;
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<void> _loadKlasifikasi() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/klasifikasi'),
        headers: headers,
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
      if (mounted) {
        MessageService.showErrorSnackBar(
            context, 'Gagal memuat data klasifikasi: $e');
      }
    }
  }

  Future<void> _loadJenisAset() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.authApiUrl}/jenis-aset'),
        headers: headers,
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
      if (mounted) {
        MessageService.showErrorSnackBar(
            context, 'Gagal memuat data jenis aset: $e');
      }
    }
  }
}
