import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kAccess  = 'qr_access_token';
  static const _kRefresh = 'qr_refresh_token';

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) =>
      Future.wait([
        _store.write(key: _kAccess,  value: accessToken),
        _store.write(key: _kRefresh, value: refreshToken),
      ]).then((_) {});

  static Future<String?> getAccessToken()  => _store.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _store.read(key: _kRefresh);

  static Future<void> clear() =>
      Future.wait([
        _store.delete(key: _kAccess),
        _store.delete(key: _kRefresh),
      ]).then((_) {});

  static Future<bool> hasSession() async {
    final t = await _store.read(key: _kRefresh);
    return t != null && t.isNotEmpty;
  }
}
