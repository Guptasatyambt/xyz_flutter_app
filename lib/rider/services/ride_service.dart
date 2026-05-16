import 'dart:convert';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/ride_models.dart';

class RideService {
  static Future<Ride> bookRide({
    required String quote,
    String? pickupAddress,
    String? dropAddress,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.rides,
      body: {
        'quote': quote,
        'pickupAddress': ?pickupAddress,
        'dropAddress': ?dropAddress,
      },
      auth: true,
    );
    if (res.statusCode == 201) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<Ride> getRide(String rideId) async {
    final res =
        await ApiClient.get(ApiEndpoints.rideById(rideId), auth: true);
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<({List<Ride> items, String? nextCursor})> listRides({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    final buf =
        StringBuffer('${ApiEndpoints.rides}?limit=$limit');
    if (status != null) buf.write('&status=$status');
    if (cursor != null) buf.write('&cursor=$cursor');

    final res = await ApiClient.get(buf.toString(), auth: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        items: (data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(Ride.fromJson)
            .toList(),
        nextCursor: data['nextCursor'] as String?,
      );
    }
    throw ApiClient.parseError(res);
  }

  static Future<Ride> cancelRide(
    String rideId, {
    String reason = 'RIDER_CHANGED_MIND',
    String? note,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.rideCancel(rideId),
      body: {
        'reason': reason,
        'note': ?note,
      },
      auth: true,
    );
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  /// Returns the first active ride for the current rider, or null if none.
  static Future<Ride?> getActiveRide() async {
    try {
      final result = await listRides(limit: 10);
      return result.items.where((r) => r.isActive).firstOrNull;
    } catch (_) {
      return null;
    }
  }
}
