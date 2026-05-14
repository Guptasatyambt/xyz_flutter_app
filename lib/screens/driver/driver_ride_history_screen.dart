import 'package:flutter/material.dart';
import '../../core/models/ride_models.dart';
import '../../core/services/driver_ride_service.dart';
import 'driver_active_ride_screen.dart';

class DriverRideHistoryScreen extends StatefulWidget {
  const DriverRideHistoryScreen({super.key});

  @override
  State<DriverRideHistoryScreen> createState() => _DriverRideHistoryScreenState();
}

class _DriverRideHistoryScreenState extends State<DriverRideHistoryScreen> {
  final List<Ride> _rides = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await DriverRideService.listRides(limit: 20);
      setState(() {
        _rides
          ..clear()
          ..addAll(result.items);
        _cursor = result.nextCursor;
        _hasMore = result.nextCursor != null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await DriverRideService.listRides(limit: 20, cursor: _cursor);
      setState(() {
        _rides.addAll(result.items);
        _cursor = result.nextCursor;
        _hasMore = result.nextCursor != null;
      });
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ride History',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: BackButton(color: const Color(0xFF1A1A2E)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _rides.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 64, color: Color(0xFFBDBDBD)),
                          SizedBox(height: 12),
                          Text(
                            'No rides yet',
                            style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _rides.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          if (i == _rides.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _DriverRideTile(
                            ride: _rides[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DriverActiveRideScreen(
                                  initialRide: _rides[i],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── Ride tile ──────────────────────────────────────────────────────────────────

class _DriverRideTile extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;

  const _DriverRideTile({required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (ride.isCompleted) {
      statusColor = const Color(0xFF2E7D32);
    } else if (ride.isCancelled) {
      statusColor = const Color(0xFFC62828);
    } else {
      statusColor = const Color(0xFF5C6BC0);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.directions_car, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ride.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _relativeDate(ride.requestedAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ride.dropAddress ?? '${ride.dropLat.toStringAsFixed(4)}, ${ride.dropLng.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        ride.distanceText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                      ),
                      const Text(
                        ' · ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                      Text(
                        ride.durationText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                      ),
                      const Spacer(),
                      Text(
                        '₹${ride.fareToShow.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
