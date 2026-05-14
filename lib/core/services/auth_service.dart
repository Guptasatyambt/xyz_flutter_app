import 'dart:convert';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../socket/socket_manager.dart';
import '../storage/token_storage.dart';

class AuthService {
  /// Send OTP. Throws [ApiException] on failure.
  static Future<void> requestOtp({
    required String phone,
    required String role,
  }) async {
    final res = await ApiClient.post(
      ApiEndpoints.otpRequest,
      body: {'phone': phone, 'role': role},
    );
    if (res.statusCode != 202) throw ApiClient.parseError(res);
  }

  /// Verify OTP → saves tokens → returns [AuthResponse]. Throws [ApiException].
  static Future<AuthResponse> verifyOtp({
    required String phone,
    required String role,
    required String otp,
    String? deviceId,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'role': role,
      'otp': otp,
      'deviceId': ?deviceId,
    };
    final res = await ApiClient.post(ApiEndpoints.otpVerify, body: body);
    if (res.statusCode == 200) {
      final auth = AuthResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      await TokenStorage.save(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );
      return auth;
    }
    throw ApiClient.parseError(res);
  }

  /// Fetch the current user's profile. Throws [ApiException].
  static Future<UserModel> getMe() async {
    final res = await ApiClient.get(ApiEndpoints.userMe);
    if (res.statusCode == 200) {
      return UserModel.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  /// Update profile fields. All params are optional. Throws [ApiException].
  static Future<UserModel> updateProfile({
    String? fullName,
    String? email,
    String? gender,
  }) async {
    final body = <String, dynamic>{
      'fullName': ?fullName,
      'email': ?email,
      'gender': ?gender,
    };
    final res = await ApiClient.patch(ApiEndpoints.userMe, body: body);
    if (res.statusCode == 200) {
      return UserModel.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw ApiClient.parseError(res);
  }

  /// Revoke session(s) then wipe local tokens.
  static Future<void> logout({bool allDevices = false}) async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      await ApiClient.post(
        ApiEndpoints.authLogout,
        body: {
          'refreshToken': ?refreshToken,
          'allDevices': allDevices,
        },
        auth: true,
      );
    } finally {
      SocketManager.instance.disconnectAll();
      await TokenStorage.clear();
    }
  }

  static Future<bool> isLoggedIn() => TokenStorage.hasSession();
}
