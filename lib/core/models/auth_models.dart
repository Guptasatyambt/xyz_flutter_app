import 'user_model.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresIn;
  final UserModel user;
  final bool isNewUser;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
    required this.user,
    required this.isNewUser,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        accessTokenExpiresIn: j['accessTokenExpiresIn'] as int,
        user: UserModel.fromJson(j['user'] as Map<String, dynamic>),
        isNewUser: j['isNewUser'] as bool? ?? false,
      );
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  bool get isUnauthorized  => statusCode == 401;
  bool get isRateLimited   => statusCode == 429;
  bool get isConflict      => statusCode == 409;
  bool get isValidation    => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();
}
