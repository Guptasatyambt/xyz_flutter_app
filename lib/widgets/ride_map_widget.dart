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
  Uint8List? _carImg;

  @override
  void didUpdateWidget(RideMapWidget old) {
    super.didUpdateWidget(old);
    if (_map == null) return;

    final routeChanged = old.routePoints.length != widget.routePoints.length ||
        old.pickup != widget.pickup ||
        old.drop != widget.drop;

    if (routeChanged) {
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
    _pickupImg = await _circleImage(const Color(0xFF4CAF50));
    _dropImg   = await _circleImage(const Color(0xFFE53935));
    _carImg    = await _carImage();

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
      image: _carImg,
      iconSize: 1.0,
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
        image: _carImg,
        iconSize: 1.0,
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

  static Future<Uint8List> _carImage() async {
    const sz = 48.0;
    const bg = Color(0xFF1A1A2E);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, sz, sz));

    // Dark circle background
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      21,
      Paint()..color = bg,
    );
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      21,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Car body (white)
    final carPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(9, 22, 30, 14), const Radius.circular(3)),
      carPaint,
    );
    // Roof
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13, 13, 22, 12), const Radius.circular(3)),
      carPaint,
    );
    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF555555);
    canvas.drawCircle(const Offset(15, 36), 4, wheelPaint);
    canvas.drawCircle(const Offset(33, 36), 4, wheelPaint);

    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
