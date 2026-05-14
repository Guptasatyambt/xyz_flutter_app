import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/auth_models.dart';
import '../navigation/app_navigator.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';

class ApiClient {
  // ── Headers ────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await TokenStorage.getAccessToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ── Public request methods ─────────────────────────────────────────────────

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool retry = true,
  }) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode == 401 && auth && retry) {
      if (await _tryRefresh()) {
        return post(path, body: body, auth: auth, retry: false);
      }
      _handleExpired();
      throw const SessionExpiredException();
    }
    return res;
  }

  static Future<http.Response> get(
    String path, {
    bool auth = true,
    bool retry = true,
  }) async {
    final res = await http.get(_uri(path), headers: await _headers(auth: auth));
    if (res.statusCode == 401 && auth && retry) {
      if (await _tryRefresh()) return get(path, auth: auth, retry: false);
      _handleExpired();
      throw const SessionExpiredException();
    }
    return res;
  }

  static Future<http.Response> postMultipart(
    String path, {
    required String filePath,
    Map<String, String> fields = const {},
    bool auth = true,
  }) async {
    final uri = _uri(path);
    final headers = await _headers(auth: auth);
    headers.remove('Content-Type');
    final mime = _mimeFromPath(filePath);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType.parse(mime),
      ));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  static String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      'webp'          => 'image/webp',
      'heic'          => 'image/heic',
      'pdf'           => 'application/pdf',
      _               => 'image/jpeg',
    };
  }

  static Future<http.Response> delete(
    String path, {
    bool retry = true,
  }) async {
    final res = await http.delete(_uri(path), headers: await _headers());
    if (res.statusCode == 401 && retry) {
      if (await _tryRefresh()) return delete(path, retry: false);
      _handleExpired();
      throw const SessionExpiredException();
    }
    return res;
  }

  static Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final res = await http.patch(
      _uri(path),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode == 401 && retry) {
      if (await _tryRefresh()) return patch(path, body: body, retry: false);
      _handleExpired();
      throw const SessionExpiredException();
    }
    return res;
  }

  // ── Error parser ───────────────────────────────────────────────────────────

  static ApiException parseError(http.Response res) {
    try {
      final data  = jsonDecode(res.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>? ?? {};
      return ApiException(
        code: error['code'] as String? ?? 'UNKNOWN',
        message: error['message'] as String? ?? 'Something went wrong',
        statusCode: res.statusCode,
      );
    } catch (_) {
      return ApiException(
        code: 'UNKNOWN',
        message: 'Something went wrong',
        statusCode: res.statusCode,
      );
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Uri _uri(String path) =>
      Uri.parse('${ApiEndpoints.baseUrl}$path');

  static Future<bool> _tryRefresh() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await http.post(
        _uri(ApiEndpoints.authRefresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await TokenStorage.save(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {}
    await TokenStorage.clear();
    return false;
  }

  static void _handleExpired() {
    TokenStorage.clear();
    onSessionExpired?.call();
  }
}
