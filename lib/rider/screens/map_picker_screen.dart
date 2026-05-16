import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/models/geo_models.dart';
import '../../core/services/geo_service.dart';

class MapPickerScreen extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  MapboxMap? _map;
  bool _isMoving = false;
  bool _geocoding = false;
  bool _programmaticMove = false;
  String _address = 'Locating…';
  double? _lat;
  double? _lng;

  static const _defaultLat = 28.6139;
  static const _defaultLng = 77.2090;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? _defaultLat;
    _lng = widget.initialLng ?? _defaultLng;
    _reverseGeocode(_lat!, _lng!);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    _programmaticMove = true;
    await map.setCamera(CameraOptions(
      center: Point(coordinates: Position(_lng!, _lat!)),
      zoom: 15.0,
    ));
  }

  void _onCameraChange(CameraChangedEventData _) {
    if (_programmaticMove) return;
    if (!_isMoving) setState(() => _isMoving = true);
  }

  Future<void> _onMapIdle(MapIdleEventData _) async {
    if (_programmaticMove) {
      _programmaticMove = false;
      return;
    }
    if (!_isMoving) return;
    setState(() => _isMoving = false);

    final state = await _map?.getCameraState();
    if (state == null || !mounted) return;

    final lat = state.center.coordinates.lat.toDouble();
    final lng = state.center.coordinates.lng.toDouble();
    setState(() {
      _lat = lat;
      _lng = lng;
    });
    _reverseGeocode(lat, lng);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _geocoding = true;
      _address = 'Finding address…';
    });
    try {
      final result = await GeoService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _address = result.formatted ?? 'Selected location';
          _geocoding = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _address = 'Selected location'; _geocoding = false; });
    }
  }

  void _confirm() {
    if (_lat == null || _lng == null) return;
    Navigator.pop(context, GeocodedPlace(
      formatted: _address,
      lat: _lat!,
      lng: _lng!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            MapWidget(
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
              onCameraChangeListener: _onCameraChange,
              onMapIdleListener: _onMapIdle,
            ),
            _buildCenterPin(),
            _buildTopBar(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildConfirmPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPin() {
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _isMoving ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(
              Icons.location_pin,
              color: Color(0xFF1A1A2E),
              size: 48,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isMoving ? 14 : 10,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: _isMoving ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A1A2E), size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              _geocoding
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFEEEEEE),
                        color: Color(0xFF1A1A2E),
                      ),
                    )
                  : Text(
                      _address,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 2,
                    ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_lat != null && _lng != null && !_geocoding)
                          ? _confirm
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    disabledBackgroundColor: Colors.grey[200],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm ${widget.title.replaceAll('Set ', '')}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
