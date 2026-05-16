import 'package:flutter/material.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/ride_models.dart';
import '../services/ride_service.dart';
import 'active_ride_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  static const _navy = Color(0xFF1A1A2E);

  List<Ride> _rides = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRides();
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

  Future<void> _loadRides() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await RideService.listRides(limit: 20);
      if (!mounted) return;
      setState(() {
        _rides = result.items;
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
      final result =
          await RideService.listRides(limit: 20, cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _rides.addAll(result.items);
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

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
          const Text('Ride History',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
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
              onPressed: _loadRides,
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
    if (_rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined,
                size: 72, color: Colors.grey[200]),
            const SizedBox(height: 16),
            const Text('No rides yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333))),
            const SizedBox(height: 6),
            const Text('Your ride history will appear here.',
                style: TextStyle(
                    color: Color(0xFF999999), fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _navy,
      onRefresh: _loadRides,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _rides.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _rides.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _navy),
              ),
            );
          }
          final ride = _rides[i];
          return _RideTile(
            ride: ride,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ActiveRideScreen(initialRide: ride)),
            ),
          );
        },
      ),
    );
  }
}

// ── Ride tile ──────────────────────────────────────────────────────────────────

class _RideTile extends StatelessWidget {
  final Ride ride;
  final VoidCallback onTap;

  const _RideTile({required this.ride, required this.onTap});

  static const _navy = Color(0xFF1A1A2E);

  static IconData _vehicleIcon(String type) => switch (type) {
        'BIKE' => Icons.two_wheeler,
        'AUTO' => Icons.electric_rickshaw,
        'CAR_MINI' => Icons.directions_car,
        'CAR_SEDAN' => Icons.drive_eta,
        'CAR_SUV' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };

  @override
  Widget build(BuildContext context) {
    final isBad = ride.isCancelled ||
        ride.status == 'NO_DRIVERS_FOUND' ||
        ride.status == 'FAILED';
    final isGood = ride.isCompleted;
    final isActive = ride.isActive;

    final statusColor = isBad
        ? Colors.red[600]!
        : isGood
            ? const Color(0xFF4CAF50)
            : Colors.amber[700]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? _navy.withValues(alpha: 0.2)
                : const Color(0xFFEEEEEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isBad
                    ? Colors.red.withValues(alpha: 0.08)
                    : isActive
                        ? _navy.withValues(alpha: 0.08)
                        : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _vehicleIcon(ride.vehicleType),
                size: 22,
                color: isBad ? Colors.red[600] : _navy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ride.vehicleDisplayName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ride.statusLabel,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ride.dropAddress ?? 'Unknown destination',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF666666)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ride.distanceText}  ·  ${ride.durationText}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFAAAAAA)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${ride.fareToShow.round()}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E)),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(ride.requestedAt),
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}
