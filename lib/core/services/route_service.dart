import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class RouteResult {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RouteService {
  static Future<RouteResult> fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final path = '${ApiEndpoints.geoRoute}'
        '?originLat=$originLat&originLng=$originLng'
        '&destLat=$destLat&destLng=$destLng';
    final res = await ApiClient.get(path);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final encoded = data['polyline'] as String?;
      final points = encoded != null
          ? _decodePolyline(encoded)
          : [LatLng(originLat, originLng), LatLng(destLat, destLng)];
      return RouteResult(
        points: points,
        distanceMeters: (data['distanceMeters'] as num).toInt(),
        durationSeconds: (data['durationSeconds'] as num).toInt(),
      );
    }
    // On any error fall back to straight line so the map still renders.
    return RouteResult(
      points: [LatLng(originLat, originLng), LatLng(destLat, destLng)],
      distanceMeters: 0,
      durationSeconds: 0,
    );
  }

  // Google Polyline Encoding Algorithm (precision 5).
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
