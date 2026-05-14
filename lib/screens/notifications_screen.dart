import 'package:flutter/material.dart';
import '../core/models/auth_models.dart';
import '../core/models/ride_models.dart';
import '../core/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _navy = Color(0xFF1A1A2E);

  List<NotificationItem> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _error;
  final Set<String> _localRead = {};

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 120 &&
        !_loadingMore &&
        _nextCursor != null) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await NotificationService.getNotifications(limit: 30);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _nextCursor = result.nextCursor;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach server.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final result = await NotificationService.getNotifications(
          limit: 30, cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (_isRead(item)) return;
    setState(() => _localRead.add(item.id));
    try {
      await NotificationService.markRead(item.id);
    } catch (_) {
      if (mounted) setState(() => _localRead.remove(item.id));
    }
  }

  Future<void> _markAllRead() async {
    final unread =
        _items.where((n) => !_isRead(n)).map((n) => n.id).toList();
    if (unread.isEmpty) return;
    setState(() => _markingAll = true);
    try {
      await NotificationService.markAllRead();
      if (!mounted) return;
      setState(() {
        _localRead.addAll(unread);
        _markingAll = false;
      });
    } catch (_) {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  bool _isRead(NotificationItem item) =>
      item.isRead || _localRead.contains(item.id);

  int get _unreadCount => _items.where((n) => !_isRead(n)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Notifications',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          if (!_loading && _unreadCount > 0)
            _markingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Mark all read',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _navy));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 15)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _load,
              child: const Text('Retry',
                  style: TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined,
                size: 72, color: Colors.grey[200]),
            const SizedBox(height: 16),
            const Text('No notifications',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333))),
            const SizedBox(height: 6),
            Text("You're all caught up!",
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _navy,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _navy),
              ),
            );
          }
          final item = _items[i];
          return _NotificationTile(
            item: item,
            read: _isRead(item),
            onTap: () => _markRead(item),
          );
        },
      ),
    );
  }
}

// ── Notification tile ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final bool read;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.read,
    required this.onTap,
  });

  static IconData _iconFor(String type) => switch (type) {
        'RIDE_STATUS' => Icons.directions_car_outlined,
        'PROMO' => Icons.local_offer_outlined,
        'SYSTEM' => Icons.info_outline,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: read ? Colors.white : const Color(0xFFF0F4FF),
          border: const Border(
              bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 14, top: 2),
              decoration: BoxDecoration(
                color: read
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFF1A1A2E).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(item.type),
                size: 18,
                color: read
                    ? const Color(0xFF999999)
                    : const Color(0xFF1A1A2E),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: const Color(0xFF1C1C1E)),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 8,
                          height: 8,
                          margin:
                              const EdgeInsets.only(left: 8, top: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A2E),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF666666)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(item.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFAAAAAA)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}
