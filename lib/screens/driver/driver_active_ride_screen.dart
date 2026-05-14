import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/models/ride_models.dart';
import '../../core/services/driver_ride_service.dart';
import '../../core/services/route_service.dart';
import '../../core/socket/socket_manager.dart';
import '../../widgets/ride_map_widget.dart';

class DriverActiveRideScreen extends StatefulWidget {
  final Ride initialRide;

  const DriverActiveRideScreen({super.key, required this.initialRide});

  @override
  State<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  late Ride _ride;
  io.Socket? _socket;
  bool _actionLoading = false;

  // Pickup → drop route (shown during DRIVER_ARRIVED / IN_PROGRESS)
  List<LatLng> _rideRoutePoints = [];
  bool _rideRouteLoading = true;

  // Driver → pickup approach route (shown during DRIVER_ARRIVING)
  List<LatLng> _approachRoutePoints = [];
  bool _approachRouteLoading = false;
  LatLng? _lastApproachFetchPos;

  // Driver's live GPS position
  LatLng? _driverPos;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _ride = widget.initialRide;
    _attachSocket();
    _fetchRideRoute();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _detachSocket();
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Location tracking ──────────────────────────────────────────────────────

  Future<void> _startLocationTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    // Get an immediate fix — stream only fires after 15 m of movement, so
    // a stationary driver would never appear without this initial call.
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _handlePosition(initial);
    } catch (_) {}

    // Continue streaming for movement updates.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(_handlePosition);
  }

  void _handlePosition(Position pos) {
    if (!mounted) return;
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() => _driverPos = newPos);

    // Emit to backend — fans out to rider via ride:driver-location socket event.
    final h = pos.heading;
    final s = pos.speed;
    _socket?.emit('location:update', {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (!h.isNaN && h >= 0) 'heading': h,
      if (!s.isNaN && s >= 0) 'speed': s,
    });

    // Re-fetch approach route when driver moves > 300 m from last fetch.
    if (_ride.status == 'DRIVER_ARRIVING' && !_approachRouteLoading) {
      final last = _lastApproachFetchPos;
      final moved = last == null ||
          const Distance().as(LengthUnit.Meter, last, newPos) > 300;
      if (moved) { _fetchApproachRoute(newPos); }
    }
  }

  Future<void> _fetchApproachRoute(LatLng from) async {
    if (_approachRouteLoading) return;
    if (mounted) setState(() => _approachRouteLoading = true);
    _lastApproachFetchPos = from;
    try {
      final result = await RouteService.fetchRoute(
        originLat: from.latitude,
        originLng: from.longitude,
        destLat: _ride.pickupLat,
        destLng: _ride.pickupLng,
      );
      if (mounted) {
        setState(() {
          _approachRoutePoints = result.points;
          _approachRouteLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _approachRouteLoading = false);
    }
  }

  Future<void> _fetchRideRoute() async {
    try {
      final result = await RouteService.fetchRoute(
        originLat: _ride.pickupLat,
        originLng: _ride.pickupLng,
        destLat: _ride.dropLat,
        destLng: _ride.dropLng,
      );
      if (mounted) {
        setState(() {
          _rideRoutePoints = result.points;
          _rideRouteLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _rideRoutePoints = [
            LatLng(_ride.pickupLat, _ride.pickupLng),
            LatLng(_ride.dropLat, _ride.dropLng),
          ];
          _rideRouteLoading = false;
        });
      }
    }
  }

  // ── Socket ─────────────────────────────────────────────────────────────────

  Future<void> _attachSocket() async {
    try {
      final socket = await SocketManager.instance.connectDriver();
      if (!mounted) return;
      _socket = socket;
      socket.on('ride:state', _onRideState);
      // If GPS already has a fix by the time socket connects, emit immediately
      // so the rider doesn't have to wait for the next movement update.
      final pos = _driverPos;
      if (pos != null) {
        socket.emit('location:update', {
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
      }
    } catch (_) {}
  }

  void _detachSocket() {
    _socket?.off('ride:state', _onRideState);
    _socket = null;
  }

  void _onRideState(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['id'] != _ride.id) return;
      final updated = Ride.fromSocketJson(map, current: _ride);
      setState(() => _ride = updated);
      if (updated.isTerminal) _detachSocket();
    } catch (_) {}
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _doAction(Future<Ride> Function() action) async {
    setState(() => _actionLoading = true);
    try {
      final updated = await action();
      if (mounted) setState(() => _ride = updated);
      if (_ride.isTerminal) _detachSocket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  int _elapsedSinceStart() {
    final start = _ride.startedAt;
    if (start == null) return _ride.estimatedDurationSeconds;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return elapsed > 0 ? elapsed : _ride.estimatedDurationSeconds;
  }

  Future<void> _cancelRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final updated = await DriverRideService.cancelRide(
          _ride.id, reason: 'DRIVER_CANCELLED');
      if (mounted) setState(() => _ride = updated);
      _detachSocket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Active Ride',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: _ride.isTerminal
            ? BackButton(color: const Color(0xFF1A1A2E))
            : const SizedBox.shrink(),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildMapSection(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatusCard(),
                const SizedBox(height: 16),
                _buildRouteCard(),
                const SizedBox(height: 16),
                _buildFareCard(),
                const SizedBox(height: 24),
                if (!_ride.isTerminal) _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final pickup = LatLng(_ride.pickupLat, _ride.pickupLng);
    final drop = LatLng(_ride.dropLat, _ride.dropLng);

    // During DRIVER_ARRIVING show route from driver's position to the pickup.
    // Green dot = driver (navigation start), red pin = pickup (destination).
    if (_ride.status == 'DRIVER_ARRIVING' && _driverPos != null) {
      final route = _approachRoutePoints.isNotEmpty
          ? _approachRoutePoints
          : [_driverPos!, pickup];
      return SizedBox(
        height: 240,
        child: RideMapWidget(
          routePoints: route,
          pickup: _driverPos!,
          drop: pickup,
        ),
      );
    }

    // All other statuses: pickup → drop route, with driver car marker if we
    // have a GPS fix (shows the driver's progress along the route).
    return SizedBox(
      height: 240,
      child: _rideRouteLoading
          ? Container(
              color: const Color(0xFFF0F0F0),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : RideMapWidget(
              routePoints: _rideRoutePoints,
              pickup: pickup,
              drop: drop,
              driverLocation: _driverPos,
            ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    if (_ride.isCompleted) {
      statusColor = const Color(0xFF2E7D32);
    } else if (_ride.isCancelled) {
      statusColor = const Color(0xFFC62828);
    } else {
      statusColor = const Color(0xFF5C6BC0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _ride.statusLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              if (!_ride.isTerminal) ...[
                const Spacer(),
                if (_driverPos != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'GPS',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _riderStatusDescription,
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
          ),
        ],
      ),
    );
  }

  String get _riderStatusDescription => switch (_ride.status) {
        'DRIVER_ARRIVING' => 'Navigate to the pickup point.',
        'DRIVER_ARRIVED' => 'Wait for the rider to board.',
        'IN_PROGRESS' => 'Drive to the destination.',
        'COMPLETED' => 'Ride completed. Great job!',
        'CANCELLED_BY_RIDER' => 'The rider cancelled this ride.',
        'CANCELLED_BY_DRIVER' => 'You cancelled this ride.',
        _ => _ride.statusDescription,
      };

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _LocationRow(
            icon: Icons.radio_button_checked,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Pickup',
            address: _ride.pickupAddress ??
                '${_ride.pickupLat}, ${_ride.pickupLng}',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
                height: 24, width: 1.5, color: const Color(0xFFBDBDBD)),
          ),
          _LocationRow(
            icon: Icons.location_on,
            iconColor: const Color(0xFFE53935),
            label: 'Drop',
            address:
                _ride.dropAddress ?? '${_ride.dropLat}, ${_ride.dropLng}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.straighten, size: 16, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text(
                _ride.distanceText,
                style:
                    const TextStyle(color: Color(0xFF757575), fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time,
                  size: 16, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text(
                _ride.durationText,
                style:
                    const TextStyle(color: Color(0xFF757575), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Estimated fare',
            style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
          ),
          Text(
            '₹${_ride.fareToShow.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_ride.status == 'DRIVER_ARRIVING')
          _ActionButton(
            label: 'I\'ve Arrived',
            icon: Icons.where_to_vote,
            color: const Color(0xFF5C6BC0),
            loading: _actionLoading,
            onTap: () =>
                _doAction(() => DriverRideService.arrivedAtPickup(_ride.id)),
          ),
        if (_ride.status == 'DRIVER_ARRIVED')
          _ActionButton(
            label: 'Start Ride',
            icon: Icons.play_circle_outline,
            color: const Color(0xFF2E7D32),
            loading: _actionLoading,
            onTap: () => _doAction(() => DriverRideService.startRide(_ride.id)),
          ),
        if (_ride.status == 'IN_PROGRESS')
          _ActionButton(
            label: 'Complete Ride',
            icon: Icons.flag_outlined,
            color: const Color(0xFF2E7D32),
            loading: _actionLoading,
            onTap: () => _doAction(() => DriverRideService.completeRide(
                  _ride.id,
                  actualDistanceMeters: _ride.estimatedDistanceMeters,
                  actualDurationSeconds: _elapsedSinceStart(),
                )),
          ),
        if (_ride.status == 'DRIVER_ARRIVING' ||
            _ride.status == 'DRIVER_ARRIVED') ...[
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Cancel Ride',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFE53935),
            loading: _actionLoading,
            onTap: _cancelRide,
          ),
        ],
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}
