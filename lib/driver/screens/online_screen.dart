import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/models/ride_models.dart';
import '../models/ride_offer.dart';
import '../services/driver_presence_service.dart';
import '../services/driver_ride_service.dart';
import '../../core/socket/socket_manager.dart';
import 'active_ride_screen.dart';

class DriverOnlineScreen extends StatefulWidget {
  const DriverOnlineScreen({super.key});

  @override
  State<DriverOnlineScreen> createState() => _DriverOnlineScreenState();
}

class _DriverOnlineScreenState extends State<DriverOnlineScreen>
    with SingleTickerProviderStateMixin {
  io.Socket? _socket;
  bool _goingOffline = false;
  RideOffer? _pendingOffer;
  bool _respondingToOffer = false;
  Timer? _offerCountdown;
  Duration _offerRemaining = Duration.zero;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkForActiveRide();
    _attachSocket();
  }

  @override
  void dispose() {
    _detachSocket();
    _offerCountdown?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _checkForActiveRide() async {
    for (final status in ['DRIVER_ARRIVING', 'DRIVER_ARRIVED', 'IN_PROGRESS']) {
      try {
        final result =
            await DriverRideService.listRides(status: status, limit: 1);
        if (result.items.isNotEmpty && mounted) {
          _openActiveRide(result.items.first);
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _attachSocket() async {
    try {
      final socket = await SocketManager.instance.connectDriver();
      if (!mounted) return;
      _socket = socket;
      socket.on('ride:offer', _onRideOffer);
      socket.on('ride:state', _onRideState);
      socket.on('connect', _onSocketConnect);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect: $e')),
        );
      }
    }
  }

  void _detachSocket() {
    _socket?.off('ride:offer', _onRideOffer);
    _socket?.off('ride:state', _onRideState);
    _socket?.off('connect', _onSocketConnect);
    _socket = null;
  }

  void _onSocketConnect(dynamic _) {
    // Socket reconnected — re-register presence so the server routes offers here.
    DriverPresenceService.refreshPresence();
  }

  void _onRideOffer(dynamic data) {
    if (!mounted || _pendingOffer != null) return;
    try {
      final offer = RideOffer.fromJson(Map<String, dynamic>.from(data as Map));
      setState(() {
        _pendingOffer = offer;
        _offerRemaining = offer.remaining();
      });
      // Subscribe to state updates so we're notified if the rider cancels
      // the ride before we accept or reject it.
      _socket?.emit('ride:subscribe', {'rideId': offer.rideId});
      _startCountdown();
    } catch (_) {}
  }

  void _onRideState(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      final status = map['status'] as String?;
      // If the ride we're showing an offer for got cancelled / assigned to
      // someone else, dismiss our card.
      if (_pendingOffer != null &&
          map['id'] == _pendingOffer!.rideId &&
          status != null &&
          status != 'SEARCHING') {
        _dismissOffer();
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _offerCountdown?.cancel();
    _offerCountdown = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _pendingOffer == null) return;
      final remaining = _pendingOffer!.remaining();
      if (remaining == Duration.zero) {
        _dismissOffer();
        return;
      }
      setState(() => _offerRemaining = remaining);
    });
  }

  void _dismissOffer() {
    _offerCountdown?.cancel();
    if (!mounted) return;
    if (_pendingOffer != null) {
      _socket?.emit('ride:unsubscribe', {'rideId': _pendingOffer!.rideId});
    }
    setState(() {
      _pendingOffer = null;
      _respondingToOffer = false;
    });
  }

  void _openActiveRide(Ride ride, {bool replace = false}) {
    final route = MaterialPageRoute(
      builder: (_) => DriverActiveRideScreen(initialRide: ride),
    );
    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  Future<void> _acceptOffer() async {
    if (_pendingOffer == null) return;
    final offer = _pendingOffer!;
    setState(() => _respondingToOffer = true);
    try {
      final ride = await DriverRideService.acceptRide(offer.rideId);
      _dismissOffer();
      if (mounted) _openActiveRide(ride);
    } catch (e) {
      if (mounted) {
        _dismissOffer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _rejectOffer() async {
    if (_pendingOffer == null) return;
    final rideId = _pendingOffer!.rideId;
    setState(() => _respondingToOffer = true);
    try {
      await DriverRideService.rejectRide(rideId);
    } catch (_) {}
    _dismissOffer();
  }

  Future<void> _goOffline() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go Offline?'),
        content: const Text('You will stop receiving ride requests.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Go Offline',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _goingOffline = true);
    try {
      await DriverPresenceService.goOffline();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _goingOffline = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'You\'re Online',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _goingOffline ? null : _goOffline,
            child: _goingOffline
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Go Offline',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _buildWaiting(),
          if (_pendingOffer != null) _buildOfferSheet(_pendingOffer!),
        ],
      ),
    );
  }

  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: 1.0 + (_pulse.value * 0.25),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                child!,
              ],
            ),
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car,
                size: 52,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Waiting for rides...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'ll be notified when a new\nride request comes in.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferSheet(RideOffer offer) {
    final secondsLeft = _offerRemaining.inSeconds;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C6BC0),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'New Ride Request!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Expires in ${secondsLeft}s',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${offer.estimatedFare.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            offer.vehicleDisplayName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Countdown bar ────────────────────────────────────────
                LinearProgressIndicator(
                  value: (_offerRemaining.inMilliseconds / 15000).clamp(0, 1),
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    secondsLeft <= 5
                        ? const Color(0xFFE53935)
                        : const Color(0xFF4CAF50),
                  ),
                ),

                // ── Route ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      _RouteRow(
                        icon: Icons.radio_button_checked,
                        color: const Color(0xFF5C6BC0),
                        label: 'Pickup',
                        address: offer.pickupAddress ??
                            '${offer.pickupLat.toStringAsFixed(4)}, '
                                '${offer.pickupLng.toStringAsFixed(4)}',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Container(
                          height: 18,
                          width: 1.5,
                          color: const Color(0xFFBDBDBD),
                        ),
                      ),
                      _RouteRow(
                        icon: Icons.location_on,
                        color: const Color(0xFFE53935),
                        label: 'Drop',
                        address: offer.dropAddress ??
                            '${offer.dropLat.toStringAsFixed(4)}, '
                                '${offer.dropLng.toStringAsFixed(4)}',
                      ),
                    ],
                  ),
                ),

                // ── Meta row ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten,
                          size: 15, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 4),
                      Text(offer.distanceText,
                          style: const TextStyle(
                              color: Color(0xFF757575), fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time,
                          size: 15, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 4),
                      Text(offer.durationText,
                          style: const TextStyle(
                              color: Color(0xFF757575), fontSize: 13)),
                    ],
                  ),
                ),

                // ── Buttons ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _respondingToOffer ? null : _rejectOffer,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: Color(0xFFE53935)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _respondingToOffer
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text(
                                  'Reject',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed:
                              _respondingToOffer ? null : _acceptOffer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _respondingToOffer
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
