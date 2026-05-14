import 'dart:convert';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/ride_models.dart';

class NotificationService {
  static Future<({List<NotificationItem> items, String? nextCursor})>
      getNotifications({
    bool unreadOnly = false,
    int limit = 50,
    String? cursor,
  }) async {
    final buf = StringBuffer(
        '${ApiEndpoints.notifications}?limit=$limit&unreadOnly=$unreadOnly');
    if (cursor != null) buf.write('&cursor=$cursor');

    final res = await ApiClient.get(buf.toString(), auth: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        items: (data['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(NotificationItem.fromJson)
            .toList(),
        nextCursor: data['nextCursor'] as String?,
      );
    }
    throw ApiClient.parseError(res);
  }

  static Future<void> markRead(String id) async {
    final res = await ApiClient.post(
        ApiEndpoints.notificationRead(id), auth: true);
    if (res.statusCode != 200) throw ApiClient.parseError(res);
  }

  static Future<int> markAllRead() async {
    final res = await ApiClient.post(
        ApiEndpoints.notificationsReadAll, auth: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['updated'] as int;
    }
    throw ApiClient.parseError(res);
  }
}
