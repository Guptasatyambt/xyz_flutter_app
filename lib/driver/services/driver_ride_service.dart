import 'dart:convert';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/ride_models.dart';

class DriverRideService {
  static Future<({List<Ride> items, String? nextCursor})> listRides({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    var path = '${ApiEndpoints.driverRides}?limit=$limit';
    if (status != null) path += '&status=$status';
    if (cursor != null) path += '&cursor=$cursor';

    final res = await ApiClient.get(path, auth: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Ride.fromJson)
          .toList();
      return (items: items, nextCursor: data['nextCursor'] as String?);
    }
    throw ApiClient.parseError(res);
  }

  static Future<Ride> getRide(String id) async {
    final res = await ApiClient.get(ApiEndpoints.driverRideById(id), auth: true);
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<Ride> acceptRide(String id) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverRideAccept(id),
      auth: true,
    );
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<void> rejectRide(String id, {String? reason}) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverRideReject(id),
      body: {'reason': ?reason},
      auth: true,
    );
    // 204 = rejected successfully, no body
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiClient.parseError(res);
    }
  }

  static Future<Ride> arrivedAtPickup(String id) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverRideArrived(id),
      auth: true,
    );
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<Ride> startRide(String id, {required String otp}) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverRideStart(id),
      body: {'otp': otp},
      auth: true,
    );
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<Ride> completeRide(
    String id, {
    int? actualDistanceMeters,
    int? actualDurationSeconds,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverRideComplete(id),
      body: {
        'actualDistanceMeters': ?actualDistanceMeters,
        'actualDurationSeconds': ?actualDurationSeconds,
      },
      auth: true,
    );
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  // Returns null on 204 (accepted, no body).
  static Future<Ride?> cancelRide(
    String id, {
    String? reason,
    String? note,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverRideCancel(id),
      body: {
        'reason': ?reason,
        'note': ?note,
      },
      auth: true,
    );
    if (res.statusCode == 200) {
      return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    if (res.statusCode == 204) return null;
    throw ApiClient.parseError(res);
  }
}
