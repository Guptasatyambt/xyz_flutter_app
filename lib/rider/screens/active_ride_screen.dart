import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/auth_models.dart';
import '../../core/models/ride_models.dart';
import '../services/ride_service.dart';
import '../../core/services/route_service.dart';
import '../../core/socket/socket_manager.dart';
import '../../core/widgets/ride_map_widget.dart';
import 'rating_screen.dart';
import '../../core/models/chat_models.dart';
import 'chat_screen.dart';

class ActiveRideScreen extends StatefulWidget {
  final Ride initialRide;
  const ActiveRideScreen({super.key, required this.initialRide});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  static const _navy = Color(0xFF1A1A2E);

  late Ride _ride;
  bool _cancelling = false;
  bool _rated = false;
  io.Socket? _socket;
  ({double lat, double lng})? _driverLocation;
  List<LatLng> _routePoints = [];
  bool _routeLoading = true;

  // Approach route: driver → pickup, shown during DRIVER_ARRIVING
  List<LatLng> _approachPoints = [];
  bool _approachLoading = false;
  LatLng? _lastApproachFetchDriver;

  // OTP shown to rider when driver has arrived
  String? _rideOtp;

  // Chat
  final List<ChatMessage> _messages = [];
  int _unreadMsgCount = 0;

  static const _steps = [
    'Finding',
    'On the way',
    'Arrived',
    'In progress',
    'Done',
  ];
  static const _stepIcons = [
    Icons.search,
    Icons.directions_car,
    Icons.location_on,
    Icons.play_arrow,
    Icons.check_circle,
  ];

  @override
  void initState() {
    super.initState();
    _ride = widget.initialRide;
    if (!_ride.isTerminal) {
      _attachSocket();
      _refetchOnce();
    }
    _fetchRoute();
  }

  @override
  void dispose() {
    _detachSocket();
    super.dispose();
  }

  Future<void> _attachSocket() async {
    try {
      final socket = await SocketManager.instance.connectRider();
      if (!mounted) return;
      _socket = socket;
      socket.on('ride:state', _onRideState);
      socket.on('ride:driver-location', _onDriverLocation);
      socket.on('chat:message', _onChatMsg);
      socket.on('ride:otp', _onRideOtp);
      socket.emit('ride:subscribe', {'rideId': _ride.id});
    } catch (_) {}
  }

  void _detachSocket() {
    final s = _socket;
    if (s == null) return;
    s.off('ride:state', _onRideState);
    s.off('ride:driver-location', _onDriverLocation);
    s.off('chat:message', _onChatMsg);
    s.off('ride:otp', _onRideOtp);
    try {
      s.emit('ride:unsubscribe', {'rideId': _ride.id});
    } catch (_) {}
    _socket = null;
  }

  void _onRideState(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['id'] != _ride.id) return;
      final updated = Ride.fromSocketJson(map, current: _ride);
      final driverJustAssigned =
          _ride.driverId == null && updated.driverId != null;
      setState(() => _ride = updated);
      if (driverJustAssigned) _fetchDriverInfo();
      if (updated.isTerminal) _detachSocket();
    } catch (_) {}
  }

  void _onDriverLocation(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['rideId'] != _ride.id) return;
      final newLoc = (
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      );
      setState(() => _driverLocation = newLoc);

      if (_ride.status == 'DRIVER_ARRIVING' && !_approachLoading) {
        final driverLatLng = LatLng(newLoc.lat, newLoc.lng);
        final last = _lastApproachFetchDriver;
        final moved = last == null ||
            const Distance().as(LengthUnit.Meter, last, driverLatLng) > 300;
        if (moved) { _fetchApproachRoute(driverLatLng); }
      }
    } catch (_) {}
  }

  Future<void> _fetchApproachRoute(LatLng driverPos) async {
    if (_approachLoading) return;
    if (mounted) setState(() => _approachLoading = true);
    _lastApproachFetchDriver = driverPos;
    try {
      final result = await RouteService.fetchRoute(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: _ride.pickupLat,
        destLng: _ride.pickupLng,
      );
      if (mounted) {
        setState(() {
          _approachPoints = result.points;
          _approachLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _approachLoading = false);
    }
  }

  void _onChatMsg(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['rideId'] != _ride.id) return;
      setState(() {
        _messages.add(ChatMessage(
          text: map['text'] as String,
          senderRole: 'DRIVER',
          time: DateTime.now(),
        ));
        _unreadMsgCount++;
      });
    } catch (_) {}
  }

  void _onRideOtp(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['rideId'] != _ride.id) return;
      setState(() => _rideOtp = map['otp'] as String?);
    } catch (_) {}
  }

  Future<void> _fetchDriverInfo() async {
    try {
      final fresh = await RideService.getRide(_ride.id);
      if (!mounted) return;
      if (fresh.driverInfo != null) {
        setState(() => _ride = fresh);
      }
    } catch (_) {}
  }

  Future<void> _fetchRoute() async {
    try {
      final result = await RouteService.fetchRoute(
        originLat: _ride.pickupLat,
        originLng: _ride.pickupLng,
        destLat: _ride.dropLat,
        destLng: _ride.dropLng,
      );
      if (mounted) {
        setState(() {
          _routePoints = result.points;
          _routeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [LatLng(_ride.pickupLat, _ride.pickupLng), LatLng(_ride.dropLat, _ride.dropLng)];
          _routeLoading = false;
        });
      }
    }
  }

  /// Bridge any missed state changes between booking and socket subscribe by
  /// fetching once via HTTP.
  Future<void> _refetchOnce() async {
    try {
      final fresh = await RideService.getRide(_ride.id);
      if (!mounted) return;
      setState(() => _ride = fresh);
      if (fresh.isTerminal) _detachSocket();
    } catch (_) {}
  }

  Future<void> _callDriver() async {
    final phone = _ride.driverInfo?.phone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel ride?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep ride',
                style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel ride',
                style: TextStyle(
                    color: Colors.red[600],
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await RideService.cancelRide(_ride.id);
      if (!mounted) return;
      setState(() {
        _ride = updated;
        _cancelling = false;
      });
      _detachSocket();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      _showError(e.message);
    } catch (_) {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _goRate() async {
    final rated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => RatingScreen(rideId: _ride.id)),
    );
    if (rated == true && mounted) setState(() => _rated = true);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _openChat() async {
    _socket?.off('chat:message', _onChatMsg);
    final result = await Navigator.push<List<ChatMessage>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          rideId: _ride.id,
          isDriver: false,
          socket: _socket,
          initialMessages: List.of(_messages),
        ),
      ),
    );
    _socket?.on('chat:message', _onChatMsg);
    if (result != null && mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(result);
        _unreadMsgCount = 0;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _ride.isTerminal,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildHeader(),
            _buildMapSection(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 12),
                    _buildRouteCard(),
                    const SizedBox(height: 12),
                    _buildFareCard(),
                    if (_ride.driverId != null && !_ride.isTerminal) ...[
                      const SizedBox(height: 12),
                      _buildDriverCard(),
                    ],
                    if (_rideOtp != null &&
                        _ride.status == 'DRIVER_ARRIVED') ...[
                      const SizedBox(height: 12),
                      _buildOtpCard(),
                    ],
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    final pickup = LatLng(_ride.pickupLat, _ride.pickupLng);
    final drop   = LatLng(_ride.dropLat,   _ride.dropLng);
    final driver = _driverLocation != null
        ? LatLng(_driverLocation!.lat, _driverLocation!.lng)
        : null;

    // During DRIVER_ARRIVING: show route from driver's position to the pickup.
    // Mirrors the driver-side view so both sides see the same approach path.
    if (_ride.status == 'DRIVER_ARRIVING' && driver != null) {
      final route = _approachPoints.isNotEmpty
          ? _approachPoints
          : [driver, pickup];
      return SizedBox(
        height: 240,
        child: RideMapWidget(
          routePoints: route,
          pickup: driver,  // green dot at driver (route start)
          drop: pickup,    // red dot at pickup (route end)
          driverLocation: driver,
          vehicleType: _ride.vehicleType,
        ),
      );
    }

    // All other statuses: pickup → drop route with live car marker.
    return SizedBox(
      height: 240,
      child: _routeLoading
          ? Container(
              color: const Color(0xFFF0F0F0),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : RideMapWidget(
              routePoints: _routePoints,
              pickup: pickup,
              drop: drop,
              driverLocation: driver,
              vehicleType: _ride.vehicleType,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_ride.isTerminal)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                )
              else
                const SizedBox(width: 8),
              const Expanded(
                child: Text('Your Ride',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              _StatusChip(status: _ride.status),
            ],
          ),
          if (!_ride.isTerminal || _ride.isCompleted) ...[
            const SizedBox(height: 16),
            _buildStepBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildStepBar() {
    final step = _ride.stepIndex;
    if (step < 0) return const SizedBox.shrink();

    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineStep = i ~/ 2;
          final active = lineStep < step;
          return Expanded(
            child: Container(
              height: 2,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
            ),
          );
        }
        final s = i ~/ 2;
        final done = s < step;
        final current = s == step;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || current
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                  color: done || current
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(
                _stepIcons[s],
                size: 14,
                color: done || current
                    ? _navy
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _steps[s],
              style: TextStyle(
                color: done || current
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
                fontWeight: current
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatusCard() {
    final isBad =
        _ride.isCancelled || _ride.status == 'NO_DRIVERS_FOUND' || _ride.status == 'FAILED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isBad
            ? Colors.red.withValues(alpha: 0.05)
            : _ride.isCompleted
                ? const Color(0xFF4CAF50).withValues(alpha: 0.05)
                : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBad
              ? Colors.red.withValues(alpha: 0.15)
              : _ride.isCompleted
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                  : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBad
                  ? Colors.red.withValues(alpha: 0.1)
                  : _ride.isCompleted
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                      : _navy.withValues(alpha: 0.06),
            ),
            child: Icon(
              isBad
                  ? Icons.cancel_outlined
                  : _ride.isCompleted
                      ? Icons.check_circle_outline
                      : _stepIcons[_ride.stepIndex.clamp(0, 4)],
              size: 26,
              color: isBad
                  ? Colors.red[600]
                  : _ride.isCompleted
                      ? const Color(0xFF4CAF50)
                      : _navy,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_ride.statusLabel,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isBad
                            ? Colors.red[700]
                            : _ride.isCompleted
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF1C1C1E))),
                const SizedBox(height: 4),
                Text(_ride.statusDescription,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF666666))),
                if (_driverLocation != null && !_ride.isTerminal) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live location',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!_ride.isTerminal)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _navy),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle)),
              Container(
                  width: 1.5,
                  height: 30,
                  color: const Color(0xFFDDDDDD)),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF1A1A2E), width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ride.pickupAddress ?? 'Pickup location',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Text(
                  _ride.dropAddress ?? 'Drop location',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_vehicleIcon(_ride.vehicleType),
                size: 22, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_ride.vehicleDisplayName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 3),
                Text('${_ride.distanceText}  ·  ${_ride.durationText}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${_ride.fareToShow.round()}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E))),
              Text(
                _ride.actualFare != null ? 'final' : 'estimated',
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_ride.canCancel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _cancelling ? null : _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[600],
            side: BorderSide(color: Colors.red[300]!),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _cancelling
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red[600]))
              : const Text('Cancel Ride',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
    }

    if (_ride.isCompleted && !_rated) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _goRate,
          icon: const Icon(Icons.star_outline, size: 20),
          label: const Text('Rate Your Ride',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    if (_ride.isTerminal) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Back to Home',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  static IconData _vehicleIcon(String type) => switch (type) {
        'BIKE' => Icons.two_wheeler,
        'AUTO' => Icons.electric_rickshaw,
        'CAR_MINI' => Icons.directions_car,
        'CAR_SEDAN' => Icons.drive_eta,
        'CAR_SUV' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };

  Widget _buildOtpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Share this OTP with your driver to start the ride',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            _rideOtp ?? '----',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final info = _ride.driverInfo;
    final initials = (info?.displayName ?? 'D')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _navy.withValues(alpha: 0.1),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info?.displayName ?? 'Your Driver',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 3),
                        Text(
                          info?.ratingText ?? '5.0',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF666666)),
                        ),
                        if (info?.vehicle != null) ...[
                          const SizedBox(width: 8),
                          const Text('·',
                              style: TextStyle(color: Color(0xFFCCCCCC))),
                          const SizedBox(width: 8),
                          Text(
                            '${info!.vehicle!.make} ${info.vehicle!.model}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF666666)),
                          ),
                        ],
                      ],
                    ),
                    if (info?.vehicle?.plateNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          info!.vehicle!.plateNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openChat,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      if (_unreadMsgCount > 0)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$_unreadMsgCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: Text(_unreadMsgCount > 0
                      ? 'Chat · $_unreadMsgCount'
                      : 'Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    side: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _callDriver,
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ── Status chip ────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isGood = status == 'COMPLETED';
    final isBad = status == 'CANCELLED_BY_RIDER' ||
        status == 'CANCELLED_BY_DRIVER' ||
        status == 'NO_DRIVERS_FOUND' ||
        status == 'FAILED';

    final color = isBad
        ? Colors.red
        : isGood
            ? const Color(0xFF4CAF50)
            : Colors.amber;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isGood
            ? 'Done'
            : isBad
                ? 'Ended'
                : 'Live',
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
