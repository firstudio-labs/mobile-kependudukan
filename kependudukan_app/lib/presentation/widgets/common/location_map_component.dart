import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum MapMode {
  view, // Just view the location
  select, // Allow user to select a location
}

class LocationMapComponent extends StatefulWidget {
  final LatLng initialPosition;
  final MapMode mode;
  final Function(LatLng)? onLocationSelected;
  final bool showCurrentMarker;
  final double height;
  final Widget? markerWidget;
  final double zoom;
  final MapController? mapController;

  const LocationMapComponent({
    Key? key,
    this.initialPosition = const LatLng(-7.310000, 110.290000),
    this.mode = MapMode.view,
    this.onLocationSelected,
    this.showCurrentMarker = true,
    this.height = 300,
    this.markerWidget,
    this.zoom = 15.0,
    this.mapController,
  }) : super(key: key);

  @override
  State<LocationMapComponent> createState() => _LocationMapComponentState();
}

class _LocationMapComponentState extends State<LocationMapComponent> {
  late LatLng _currentPosition;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _mapController = widget.mapController ?? MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPosition,
          initialZoom: widget.zoom,
          onTap: widget.mode == MapMode.select
              ? (tapPosition, point) {
                  setState(() {
                    _currentPosition = point;
                  });
                  if (widget.onLocationSelected != null) {
                    widget.onLocationSelected!(point);
                  }
                }
              : null,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.firstudio.ladimas',
          ),
          if (widget.showCurrentMarker)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition,
                  width: 80,
                  height: 80,
                  child: widget.markerWidget ??
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Add a public method to update the marker position
  void updatePosition(LatLng position) {
    setState(() {
      _currentPosition = position;
    });
    _mapController.move(position, widget.zoom);
  }
}
