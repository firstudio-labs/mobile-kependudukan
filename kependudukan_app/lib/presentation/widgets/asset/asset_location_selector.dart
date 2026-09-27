import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/presentation/widgets/common/location_map_component.dart';

class AssetLocationSelector extends StatefulWidget {
  final Function(LatLng) onLocationSelected;
  final LatLng? initialPosition;
  final String title;
  final double height;

  const AssetLocationSelector({
    Key? key,
    required this.onLocationSelected,
    this.initialPosition,
    this.title = 'Lokasi Aset',
    this.height = 250,
  }) : super(key: key);

  @override
  State<AssetLocationSelector> createState() => _AssetLocationSelectorState();
}

class _AssetLocationSelectorState extends State<AssetLocationSelector> {
  late LatLng _currentPosition;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _currentPosition =
        widget.initialPosition ?? const LatLng(-7.310000, 110.290000);
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        LocationMapComponent(
          initialPosition: _currentPosition,
          mode: MapMode.select,
          onLocationSelected: (position) {
            setState(() {
              _currentPosition = position;
            });
            widget.onLocationSelected(position);
          },
          height: widget.height,
          mapController: _mapController,
          markerWidget: const Icon(
            Icons.home_work,
            color: Colors.red,
            size: 40,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Latitude: ${_currentPosition.latitude.toStringAsFixed(6)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                'Longitude: ${_currentPosition.longitude.toStringAsFixed(6)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Method to update position programmatically if needed
  void updatePosition(LatLng position) {
    setState(() {
      _currentPosition = position;
    });
    _mapController.move(position, 15.0);
  }
}
