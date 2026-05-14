import 'dart:convert';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/geo_models.dart';

class GeoService {
  static Future<ReverseGeocodeResult> reverseGeocode(
      double lat, double lng) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.geoReverse}?lat=$lat&lng=$lng',
      auth: true,
    );
    if (res.statusCode == 200) {
      return ReverseGeocodeResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<List<GeocodedPlace>> geocode(String query) async {
    final q = Uri.encodeQueryComponent(query);
    final res = await ApiClient.get(
      '${ApiEndpoints.geoGeocode}?q=$q',
      auth: true,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(GeocodedPlace.fromJson)
          .toList();
    }
    throw ApiClient.parseError(res);
  }

  static Future<List<NearbyDriver>> getNearbyDrivers(
    double lat,
    double lng, {
    int radius = 3000,
    String? vehicleType,
    int limit = 20,
  }) async {
    final params = StringBuffer(
        '${ApiEndpoints.geoNearby}?lat=$lat&lng=$lng&radius=$radius&limit=$limit');
    if (vehicleType != null) params.write('&vehicleType=$vehicleType');

    final res = await ApiClient.get(params.toString(), auth: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NearbyDriver.fromJson)
          .toList();
    }
    throw ApiClient.parseError(res);
  }

  static Future<List<VehicleEstimate>> estimateAll({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.geoEstimateAll,
      body: {
        'origin': {'lat': originLat, 'lng': originLng},
        'destination': {'lat': destLat, 'lng': destLng},
      },
      auth: true,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(VehicleEstimate.fromJson)
          .toList();
    }
    throw ApiClient.parseError(res);
  }
}
