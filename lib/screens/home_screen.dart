import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../core/models/geo_models.dart';
import '../core/models/user_model.dart';
import '../core/services/auth_service.dart';
import '../core/services/geo_service.dart';
import 'search_screen.dart';
import 'ride_estimate_screen.dart';
import 'profile_screen.dart';
import 'ride_history_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GeocodedPlace? _destination;
  double? _centerLat;
  double? _centerLng;
  bool _geocoding = false;
  bool _isMoving = false;
  bool _hasGpsFix = false;
  String _currentAddress = 'Locating…';
  List<NearbyDriver> _nearbyDrivers = [];
  UserModel? _user;

  MapboxMap? _map;
  PointAnnotationManager? _driversMgr;
  Uint8List? _driverDotImg;
  bool _programmaticMove = false;

  // Default centre: New Delhi
  static const _defaultLat = 28.6139;
  static const _defaultLng = 77.2090;

  static const _quickPlaces = <_QuickPlace>[
    _QuickPlace('Home', '123 Green Park', Icons.home, 28.5594, 77.2001),
    _QuickPlace('Work', '456 Tech Hub', Icons.work, 28.4595, 77.0266),
    _QuickPlace('Airport', 'IGI T-2', Icons.flight, 28.5562, 77.0999),
    _QuickPlace('Mall', 'City Centre', Icons.shopping_cart, 28.5275, 77.2193),
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _currentAddress = 'Location services off');
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _currentAddress = 'Location permission denied');
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        _hasGpsFix = true;
      });

      // Move map to GPS position if map is already created
      if (_map != null) {
        _programmaticMove = true;
        try {
          await _map!.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(pos.longitude, pos.latitude)),
              zoom: 15.0,
            ),
            MapAnimationOptions(duration: 800),
          );
        } catch (_) {}
      }

      // Reverse geocode
      try {
        final rev = await GeoService.reverseGeocode(pos.latitude, pos.longitude);
        if (mounted) setState(() => _currentAddress = rev.formatted ?? 'Your location');
      } catch (_) {
        if (mounted) setState(() => _currentAddress = 'Your location');
      }

      // Nearby drivers
      try {
        final drivers = await GeoService.getNearbyDrivers(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() => _nearbyDrivers = drivers);
          await _refreshDriverMarkers();
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Could not get location');
    }
  }

  // ── Mapbox callbacks ───────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;

    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    _driversMgr = await map.annotations.createPointAnnotationManager();
    _driverDotImg = await _buildDriverDotImage();

    // Fly to GPS position if already acquired
    if (_centerLat != null && _centerLng != null) {
      _programmaticMove = true;
      try {
        await map.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(_centerLng!, _centerLat!)),
            zoom: 15.0,
          ),
          MapAnimationOptions(duration: 800),
        );
      } catch (_) {}
    }

    // Render drivers already fetched before map was ready
    if (_nearbyDrivers.isNotEmpty) {
      await _refreshDriverMarkers();
    }
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
    await _onMapMoved(LatLng(lat, lng));
  }

  Future<void> _onMapMoved(LatLng center) async {
    if (!mounted) return;
    setState(() {
      _centerLat = center.latitude;
      _centerLng = center.longitude;
      _geocoding = true;
      _currentAddress = 'Finding address…';
    });

    try {
      final rev = await GeoService.reverseGeocode(center.latitude, center.longitude);
      if (mounted) {
        setState(() {
          _currentAddress = rev.formatted ?? 'Selected location';
          _geocoding = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _currentAddress = 'Selected location'; _geocoding = false; });
    }

    try {
      final drivers = await GeoService.getNearbyDrivers(center.latitude, center.longitude);
      if (mounted) {
        setState(() => _nearbyDrivers = drivers);
        await _refreshDriverMarkers();
      }
    } catch (_) {}
  }

  // ── Driver marker helpers ──────────────────────────────────────────────────

  Future<void> _refreshDriverMarkers() async {
    final mgr = _driversMgr;
    final img = _driverDotImg;
    if (mgr == null || img == null) return;

    await mgr.deleteAll();
    if (_nearbyDrivers.isEmpty) return;

    await mgr.createMulti(
      _nearbyDrivers
          .map((d) => PointAnnotationOptions(
                geometry: Point(coordinates: Position(d.lng, d.lat)),
                image: img,
                iconSize: 1.0,
              ))
          .toList(),
    );
  }

  static Future<Uint8List> _buildDriverDotImage() async {
    const sz = 20.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, sz, sz));
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      8,
      Paint()..color = const Color(0xFF4CAF50),
    );
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Mapbox map ─────────────────────────────────────────────────
            MapWidget(
              styleUri: MapboxStyles.MAPBOX_STREETS,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(_defaultLng, _defaultLat),
                ),
                zoom: 15.0,
              ),
              onMapCreated: _onMapCreated,
              onCameraChangeListener: _onCameraChange,
              onMapIdleListener: _onMapIdle,
            ),

            // ── Pickup pin overlay (stays centred, doesn't scroll with map)
            _buildLocationPin(),

            // ── Top bar ────────────────────────────────────────────────────
            _buildTopBar(),

            // ── Bottom panel ───────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPanel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPin() {
    final label = _isMoving
        ? 'Move to select location'
        : _geocoding
            ? 'Finding address…'
            : _currentAddress.length > 28
                ? '${_currentAddress.substring(0, 28)}…'
                : _currentAddress;

    return Align(
      alignment: const Alignment(0, -0.25),
      child: AnimatedScale(
        scale: _isMoving ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isMoving
                    ? const Color(0xFF2A2A4E)
                    : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: _isMoving ? 0.4 : 0.25),
                    blurRadius: _isMoving ? 14 : 8,
                    offset: Offset(0, _isMoving ? 4 : 0),
                  ),
                ],
              ),
              child: _geocoding
                  ? const SizedBox(
                      width: 60,
                      height: 14,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.location_pin,
              color: _isMoving
                  ? const Color(0xFFFF5722)
                  : const Color(0xFFE53935),
              size: 44,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isMoving ? 14 : 10,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black
                    .withValues(alpha: _isMoving ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _iconButton(Icons.history, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RideHistoryScreen()));
            }),
            const SizedBox(width: 8),
            _iconButton(Icons.notifications_outlined, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            }),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'QuickRide',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Color(0xFF1C1C1E)),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _user?.initials ?? '·',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF1C1C1E)),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    final canBook = _destination != null && _centerLat != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Current location row
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentAddress,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF666666)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Connector line
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  width: 2,
                  height: 16,
                  color: Colors.grey[200],
                ),
              ),

              // Where to? button
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<GeocodedPlace>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchScreen(currentAddress: _currentAddress),
                    ),
                  );
                  if (result != null) setState(() => _destination = result);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          color: Color(0xFF999999), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _destination == null
                              ? 'Where to?'
                              : _destination!.formatted,
                          style: TextStyle(
                            fontSize: 16,
                            color: _destination == null
                                ? const Color(0xFF999999)
                                : const Color(0xFF1C1C1E),
                            fontWeight: _destination == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_destination != null)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _destination = null),
                          child: const Icon(Icons.close,
                              color: Color(0xFF999999), size: 18),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios,
                            color: Color(0xFF999999), size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick places
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickPlaces.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _QuickPlaceChip(
                    place: _quickPlaces[i],
                    onTap: () => setState(() => _destination = GeocodedPlace(
                          formatted:
                              '${_quickPlaces[i].name} — ${_quickPlaces[i].address}',
                          lat: _quickPlaces[i].lat,
                          lng: _quickPlaces[i].lng,
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Get Estimates button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canBook
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideEstimateScreen(
                                originLat: _centerLat!,
                                originLng: _centerLng!,
                                originAddress: _currentAddress,
                                dest: _destination!,
                              ),
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _destination == null
                        ? 'Enter destination to continue'
                        : !_hasGpsFix
                            ? 'Waiting for location…'
                            : 'Get Estimates',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _QuickPlaceChip extends StatelessWidget {
  final _QuickPlace place;
  final VoidCallback onTap;
  const _QuickPlaceChip({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(place.icon, size: 14, color: const Color(0xFF1A1A2E)),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                Text(
                  place.address,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _QuickPlace {
  final String name;
  final String address;
  final IconData icon;
  final double lat;
  final double lng;
  const _QuickPlace(this.name, this.address, this.icon, this.lat, this.lng);
}
