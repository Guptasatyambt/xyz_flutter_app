import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class RideMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final LatLng pickup;
  final LatLng drop;
  final LatLng? driverLocation;
  final String vehicleType;

  const RideMapWidget({
    super.key,
    required this.routePoints,
    required this.pickup,
    required this.drop,
    this.driverLocation,
    this.vehicleType = 'CAR_MINI',
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  MapboxMap? _map;
  PolylineAnnotationManager? _polylineMgr;
  PointAnnotationManager? _pointMgr;

  PolylineAnnotation? _routeLine;
  PointAnnotation? _pickupPin;
  PointAnnotation? _dropPin;
  PointAnnotation? _carPin;

  // Pre-generated marker images (created once in onMapCreated)
  Uint8List? _pickupImg;
  Uint8List? _dropImg;
  Uint8List? _vehicleImg;

  @override
  void didUpdateWidget(RideMapWidget old) {
    super.didUpdateWidget(old);
    if (_map == null) return;

    final routeChanged = old.routePoints.length != widget.routePoints.length ||
        old.pickup != widget.pickup ||
        old.drop != widget.drop;

    final vehicleTypeChanged = old.vehicleType != widget.vehicleType;

    if (vehicleTypeChanged) {
      // Regenerate vehicle image and redraw the car pin with updated icon
      _vehicleImage(widget.vehicleType).then((img) async {
        _vehicleImg = img;
        await _redrawAll();
      });
    } else if (routeChanged) {
      _redrawAll();
    } else if (old.driverLocation != widget.driverLocation) {
      _updateCarPin();
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;

    // Disable compass and scale bar for a clean embedded map look
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    _polylineMgr = await map.annotations.createPolylineAnnotationManager();
    _pointMgr    = await map.annotations.createPointAnnotationManager();

    // Generate marker images once
    _pickupImg  = await _circleImage(const Color(0xFF4CAF50));
    _dropImg    = await _circleImage(const Color(0xFFE53935));
    _vehicleImg = await _vehicleImage(widget.vehicleType);

    await _redrawAll();
  }

  Future<void> _redrawAll() async {
    await _drawRoute();
    await _drawStaticMarkers();
    await _drawCarPin();
    await _fitCamera();
  }

  Future<void> _drawRoute() async {
    final mgr = _polylineMgr;
    if (mgr == null) return;
    if (_routeLine != null) {
      await mgr.delete(_routeLine!);
      _routeLine = null;
    }
    if (widget.routePoints.length > 1) {
      _routeLine = await mgr.create(PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: widget.routePoints
              .map((p) => Position(p.longitude, p.latitude))
              .toList(),
        ),
        lineColor: const Color(0xFF5C6BC0).toARGB32(),
        lineWidth: 4.0,
        lineOpacity: 0.9,
      ));
    }
  }

  Future<void> _drawStaticMarkers() async {
    final mgr = _pointMgr;
    if (mgr == null) return;

    if (_pickupPin != null) { await mgr.delete(_pickupPin!); _pickupPin = null; }
    if (_dropPin != null)   { await mgr.delete(_dropPin!);   _dropPin   = null; }

    _pickupPin = await mgr.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(widget.pickup.longitude, widget.pickup.latitude)),
      image: _pickupImg,
      iconSize: 1.0,
    ));
    _dropPin = await mgr.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(widget.drop.longitude, widget.drop.latitude)),
      image: _dropImg,
      iconSize: 1.0,
    ));
  }

  Future<void> _drawCarPin() async {
    final mgr = _pointMgr;
    if (mgr == null) return;
    if (_carPin != null) { await mgr.delete(_carPin!); _carPin = null; }
    final loc = widget.driverLocation;
    if (loc == null) return;
    _carPin = await mgr.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(loc.longitude, loc.latitude)),
      image: _vehicleImg,
      iconSize: 1.5,
    ));
  }

  Future<void> _updateCarPin() async {
    final mgr = _pointMgr;
    if (mgr == null) return;
    final loc = widget.driverLocation;

    if (loc == null) {
      if (_carPin != null) { await mgr.delete(_carPin!); _carPin = null; }
      return;
    }

    final newPt = Point(coordinates: Position(loc.longitude, loc.latitude));
    if (_carPin != null) {
      // Update position in-place — no camera re-fit on every GPS ping
      _carPin!.geometry = newPt;
      await mgr.update(_carPin!);
    } else {
      // First appearance — create and re-fit to include driver
      _carPin = await mgr.create(PointAnnotationOptions(
        geometry: newPt,
        image: _vehicleImg,
        iconSize: 1.5,
      ));
      await _fitCamera();
    }
  }

  Future<void> _fitCamera() async {
    final map = _map;
    if (map == null) return;

    final pts = <LatLng>[widget.pickup, widget.drop, ...widget.routePoints];
    if (widget.driverLocation != null) pts.add(widget.driverLocation!);

    double minLat = pts.first.latitude,  maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts.skip(1)) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Ensure non-zero bounds when points are very close
    const delta = 0.002;
    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng - delta, minLat - delta)),
        northeast: Point(coordinates: Position(maxLng + delta, maxLat + delta)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
      null, null, null, null,
    );
    await map.setCamera(camera);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
    );
  }

  // ── Marker image generators ────────────────────────────────────────────────

  static Future<Uint8List> _circleImage(Color color) async {
    const sz = 44.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, sz, sz));
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      15,
      Paint()..color = color,
    );
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static Future<Uint8List> _vehicleImage(String vehicleType) async {
    const sz = 80.0;
    const cx = sz / 2; // 40
    const cy = sz / 2; // 40
    const r  = 34.0;   // circle radius

    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, sz, sz));

    // ── 1. Drop-shadow oval beneath the circle ────────────────────────────
    final shadowPaint = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      const Rect.fromLTWH(cx - r + 4, cy + r - 4, (r - 4) * 2, 14),
      shadowPaint,
    );

    // ── 2. Gradient circle background ────────────────────────────────────
    final gradientPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(cx - 8, cy - 10), // light source offset (top-left)
        r,
        const [
          Color(0xFF5C9EE8), // top-light blue
          Color(0xFF1A3A6E), // dark-navy
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(const Offset(cx, cy), r, gradientPaint);

    // ── 3. White border stroke ────────────────────────────────────────────
    canvas.drawCircle(
      const Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── 4. Glossy highlight oval (top) ────────────────────────────────────
    final glossPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(cx, cy - r + 4),
        const Offset(cx, cy - r + 18),
        const [Color(0x99FFFFFF), Color(0x00FFFFFF)],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy - r * 0.45),
        width: r * 1.1,
        height: r * 0.45,
      ),
      glossPaint,
    );

    // ── 5. Vehicle silhouette (white, top-down view) ──────────────────────
    final vPaint  = Paint()..color = Colors.white;
    final darkBlue = const Color(0xFF1A3A6E);

    final type = vehicleType.toUpperCase();

    if (type == 'BIKE') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(cx, cy), width: 8, height: 28),
          const Radius.circular(4),
        ),
        vPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy - 14), width: 12, height: 8),
        vPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 14), width: 12, height: 8),
        vPaint,
      );
      canvas.drawLine(
        Offset(cx - 9, cy - 10),
        Offset(cx + 9, cy - 10),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    } else if (type == 'AUTO') {
      final bodyPath = ui.Path()
        ..moveTo(cx - 8,  cy - 16)
        ..lineTo(cx + 8,  cy - 16)
        ..lineTo(cx + 14, cy + 14)
        ..lineTo(cx - 14, cy + 14)
        ..close();
      canvas.drawPath(bodyPath, vPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 7, cy - 12, 14, 12),
          const Radius.circular(2),
        ),
        Paint()..color = darkBlue,
      );

      canvas.drawCircle(Offset(cx, cy - 18), 5, vPaint);
      canvas.drawCircle(Offset(cx - 15, cy + 16), 5, vPaint);
      canvas.drawCircle(Offset(cx + 15, cy + 16), 5, vPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(cx, cy), width: 26, height: 36),
          const Radius.circular(6),
        ),
        vPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 9, cy - 16, 18, 7),
          const Radius.circular(2),
        ),
        Paint()..color = darkBlue,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 9, cy + 9, 18, 7),
          const Radius.circular(2),
        ),
        Paint()..color = darkBlue,
      );

      final wheelPaint = Paint()..color = const Color(0xFF333355);
      canvas.drawCircle(Offset(cx - 13, cy - 14), 5, wheelPaint);
      canvas.drawCircle(Offset(cx + 13, cy - 14), 5, wheelPaint);
      canvas.drawCircle(Offset(cx - 13, cy + 14), 5, wheelPaint);
      canvas.drawCircle(Offset(cx + 13, cy + 14), 5, wheelPaint);
    }

    final img   = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
