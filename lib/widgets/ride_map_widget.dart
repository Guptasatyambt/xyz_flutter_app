import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RideMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng pickup;
  final LatLng drop;
  final LatLng? driverLocation;

  const RideMapWidget({
    super.key,
    required this.routePoints,
    required this.pickup,
    required this.drop,
    this.driverLocation,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  late final MapController _ctrl;
  bool _fittedWithDriver = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MapController();
  }

  @override
  void didUpdateWidget(RideMapWidget old) {
    super.didUpdateWidget(old);

    final driverFirstArrival =
        !_fittedWithDriver && widget.driverLocation != null;
    final routeChanged =
        old.routePoints.length != widget.routePoints.length ||
        (old.pickup != widget.pickup || old.drop != widget.drop);

    if (driverFirstArrival || routeChanged) {
      if (driverFirstArrival) _fittedWithDriver = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ctrl.fitCamera(
          CameraFit.bounds(
            bounds: _boundsFromPoints(_allPoints()),
            padding: const EdgeInsets.all(52),
          ),
        );
      });
    }
  }

  List<LatLng> _allPoints() {
    final pts = <LatLng>[widget.pickup, widget.drop, ...widget.routePoints];
    if (widget.driverLocation != null) pts.add(widget.driverLocation!);
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: _boundsFromPoints(_allPoints()),
          padding: const EdgeInsets.all(52),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.xyz',
        ),
        if (widget.routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                strokeWidth: 4,
                color: const Color(0xFF5C6BC0),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // Pickup — green filled circle
            Marker(
              point: widget.pickup,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Drop — red pin (tip aligned to coordinate)
            Marker(
              point: widget.drop,
              width: 30,
              height: 36,
              alignment: Alignment.bottomCenter,
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFE53935),
                size: 36,
              ),
            ),
            // Driver car marker
            if (widget.driverLocation != null)
              Marker(
                point: widget.driverLocation!,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }
}
