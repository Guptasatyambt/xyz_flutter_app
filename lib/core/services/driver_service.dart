import 'dart:convert';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/driver_models.dart';

class DriverService {
  static Future<DriverProfile> getProfile() async {
    final res = await ApiClient.get(ApiEndpoints.driverMe);
    if (res.statusCode == 200) {
      return DriverProfile.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<DriverProfile> goOnline({
    required String vehicleId,
    required double lat,
    required double lng,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverOnline,
      body: {'vehicleId': vehicleId, 'lat': lat, 'lng': lng},
      auth: true,
    );
    if (res.statusCode == 200) {
      return DriverProfile.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<DriverProfile> goOffline() async {
    final res = await ApiClient.post(ApiEndpoints.driverOffline, auth: true);
    if (res.statusCode == 200) {
      return DriverProfile.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  // ── Vehicles ─────────────────────────────────────────────────────────────────

  static Future<List<DriverVehicle>> listVehicles() async {
    final res = await ApiClient.get(ApiEndpoints.driverVehicles);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => DriverVehicle.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiClient.parseError(res);
  }

  static Future<DriverVehicle> createVehicle({
    required String type,
    required String make,
    required String model,
    required int year,
    required String plateNumber,
    String? color,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.driverVehicles,
      body: {
        'type': type,
        'make': make,
        'model': model,
        'year': year,
        'plateNumber': plateNumber,
        'color': ?color,
      },
      auth: true,
    );
    if (res.statusCode == 201) {
      return DriverVehicle.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<DriverVehicle> updateVehicle(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final res = await ApiClient.patch(
      ApiEndpoints.driverVehicle(id),
      body: fields,
    );
    if (res.statusCode == 200) {
      return DriverVehicle.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  static Future<void> deleteVehicle(String id) async {
    final res = await ApiClient.delete(ApiEndpoints.driverVehicle(id));
    // 204 = deleted successfully, no body
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiClient.parseError(res);
    }
  }

  // ── Documents ─────────────────────────────────────────────────────────────────

  static Future<List<DriverDocument>> listDocuments() async {
    final res = await ApiClient.get(ApiEndpoints.driverDocuments);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => DriverDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiClient.parseError(res);
  }

  static Future<DriverDocument> uploadDocument({
    required String filePath,
    required String type,
    String? expiresAt,
  }) async {
    final res = await ApiClient.postMultipart(
      ApiEndpoints.driverDocuments,
      filePath: filePath,
      fields: {
        'type': type,
        'expiresAt': ?expiresAt,
      },
    );
    if (res.statusCode == 201) {
      return DriverDocument.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }
}
