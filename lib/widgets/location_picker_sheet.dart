import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final double radius;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

class LocationPickerSheet extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double? initialRadius;

  const LocationPickerSheet({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialRadius,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late final MapController _mapController;
  late LatLng _selectedPoint;
  late double _selectedRadius;
  bool _isLoadingCurrentLocation = false;

  // Default coordinate: Ankara Center (39.9334, 32.8597)
  static const LatLng defaultLocation = LatLng(39.9334, 32.8597);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPoint = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : defaultLocation;
    _selectedRadius = widget.initialRadius ?? 250.0;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLoadingCurrentLocation = true);
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required for GPS'),
              ),
            );
          }
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final newPoint = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedPoint = newPoint;
      });
      _mapController.move(newPoint, 15.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to fetch GPS: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCurrentLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dragHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GEOFENCE LOCATION',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedPoint.latitude.toStringAsFixed(4)}, ${_selectedPoint.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Radius selector pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Text(
                  'RADIUS:',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                for (final r in [100.0, 250.0, 500.0, 1000.0])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${r.toInt()}m'),
                      labelStyle: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _selectedRadius == r
                            ? AppColors.canvas
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      selected: _selectedRadius == r,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surfaceInteractive,
                      side: BorderSide(
                        color: _selectedRadius == r
                            ? AppColors.accent
                            : AppColors.borderInteractive,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      onSelected: (val) {
                        if (val) setState(() => _selectedRadius = r);
                      },
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Center on GPS',
                  icon: _isLoadingCurrentLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(Icons.my_location,
                          color: AppColors.accent, size: 20),
                  onPressed: _moveToCurrentLocation,
                ),
              ],
            ),
          ),

          // Map Area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.cardBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedPoint,
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedPoint = point;
                      });
                    },
                  ),
                  children: [
                    // Dark OpenStreetMap CartoDB Tiles (Zero API key needed)
                    TileLayer(
                      urlTemplate:
                          'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.reminder_app',
                    ),
                    // Geofence Circle
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _selectedPoint,
                          radius: _selectedRadius,
                          useRadiusInMeter: true,
                          color: AppColors.accent.withValues(alpha: 0.18),
                          borderColor: AppColors.accent,
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    ),
                    // Pin Marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPoint,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.accent,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check, size: 20),
                label: const Text(
                  'CONFIRM LOCATION',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    LocationPickerResult(
                      latitude: _selectedPoint.latitude,
                      longitude: _selectedPoint.longitude,
                      radius: _selectedRadius,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
