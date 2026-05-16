import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/auth_models.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/geo_models.dart';
import '../../core/models/ride_models.dart';
import '../../core/services/geo_service.dart';
import '../../core/services/route_service.dart';
import '../../core/socket/socket_manager.dart';
import '../../core/widgets/ride_map_widget.dart';
import '../services/ride_service.dart';
import 'chat_screen.dart';
import 'rating_screen.dart';

enum _Phase { estimating, active }

class RideEstimateScreen extends StatefulWidget {
  final double originLat;
  final double originLng;
  final String originAddress;
  final GeocodedPlace dest;

  const RideEstimateScreen({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.originAddress,
    required this.dest,
  });

  @override
  State<RideEstimateScreen> createState() => _RideEstimateScreenState();
}

class _RideEstimateScreenState extends State<RideEstimateScreen> {
  static const _navy = Color(0xFF1A1A2E);
  static const _searchTimeout = Duration(minutes: 5);

  _Phase _phase = _Phase.estimating;

  // ── Estimation ────────────────────────────────────────────────────────────────
  List<VehicleEstimate>? _estimates;
  String? _estimateError;
  bool _loadingEstimates = true;
  bool _booking = false;
  int _selectedIndex = 0;

  // ── Active ride ───────────────────────────────────────────────────────────────
  Ride? _ride;
  io.Socket? _socket;
  ({double lat, double lng})? _driverLocation;
  List<LatLng> _approachPoints = [];
  bool _approachLoading = false;
  LatLng? _lastApproachFetchDriver;
  String? _rideOtp;
  final List<ChatMessage> _messages = [];
  int _unreadMsgCount = 0;
  bool _cancelling = false;
  bool _rated = false;

  // ── Auto-search (silent 5-min retry when no driver found) ────────────────────
  DateTime? _searchStartTime;
  bool _autoSearching = false;  // true = retrying, show "Searching…" UI
  bool _noDriverFinal = false;  // true = 5 min elapsed, show failure UI
  Timer? _retryTimer;

  // ── Map (shared) ──────────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  bool _routeLoading = true;

  // ── Sheet ─────────────────────────────────────────────────────────────────────
  final _sheetController = DraggableScrollableController();

  static const _steps = ['Finding', 'On the way', 'Arrived', 'In progress', 'Done'];

  static const _cancelReasons = [
    'Could not find my driver',
    'Driver took too long to arrive',
    'Driver arrived at wrong location',
    'Changed my plans',
    'Booked by mistake',
    'Emergency',
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
    _loadEstimates();
    _fetchRoute();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _detachSocket();
    _sheetController.dispose();
    super.dispose();
  }

  // ── Route ─────────────────────────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    try {
      final result = await RouteService.fetchRoute(
        originLat: widget.originLat,
        originLng: widget.originLng,
        destLat: widget.dest.lat,
        destLng: widget.dest.lng,
      );
      if (mounted) setState(() { _routePoints = result.points; _routeLoading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [
            LatLng(widget.originLat, widget.originLng),
            LatLng(widget.dest.lat, widget.dest.lng),
          ];
          _routeLoading = false;
        });
      }
    }
  }

  // ── Estimates ─────────────────────────────────────────────────────────────────

  Future<void> _loadEstimates() async {
    setState(() { _loadingEstimates = true; _estimateError = null; });
    try {
      final items = await GeoService.estimateAll(
        originLat: widget.originLat,
        originLng: widget.originLng,
        destLat: widget.dest.lat,
        destLng: widget.dest.lng,
      );
      if (!mounted) return;
      setState(() {
        _estimates = items;
        _loadingEstimates = false;
        _selectedIndex = items.indexWhere((e) => e.vehicleType == 'CAR_MINI').let(
            (i) => i >= 0 ? i : 0);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _estimateError = e.message; _loadingEstimates = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _estimateError = 'Could not reach server.'; _loadingEstimates = false; });
    }
  }

  // ── Booking ───────────────────────────────────────────────────────────────────

  Future<void> _book() async {
    final est = _estimates?[_selectedIndex];
    if (est == null || _booking) return;
    setState(() => _booking = true);
    try {
      final ride = await RideService.bookRide(
        quote: est.quote,
        pickupAddress: widget.originAddress,
        dropAddress: widget.dest.formatted,
      );
      if (!mounted) return;
      _searchStartTime = DateTime.now();
      setState(() {
        _booking = false;
        _phase = _Phase.active;
        _ride = ride;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.60,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
      _attachSocket();
      _refetchOnce();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (mounted) setState(() => _booking = false);
    }
  }

  // ── Socket ────────────────────────────────────────────────────────────────────

  Future<void> _attachSocket() async {
    try {
      final socket = await SocketManager.instance.connectRider();
      if (!mounted) return;
      _socket = socket;
      socket.on('ride:state', _onRideState);
      socket.on('ride:driver-location', _onDriverLocation);
      socket.on('chat:message', _onChatMsg);
      socket.on('ride:otp', _onRideOtp);
      socket.emit('ride:subscribe', {'rideId': _ride!.id});
    } catch (_) {}
  }

  void _detachSocket() {
    final s = _socket;
    if (s == null) return;
    s.off('ride:state', _onRideState);
    s.off('ride:driver-location', _onDriverLocation);
    s.off('chat:message', _onChatMsg);
    s.off('ride:otp', _onRideOtp);
    try { s.emit('ride:unsubscribe', {'rideId': _ride?.id}); } catch (_) {}
    _socket = null;
  }

  void _onRideState(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['id'] != _ride?.id) return;
      final updated = Ride.fromSocketJson(map, current: _ride!);

      // ── No-driver handling: silently retry for up to 5 minutes ──────────────
      if (updated.status == 'NO_DRIVERS_FOUND' || updated.status == 'FAILED') {
        _handleNoDriverRide(updated);
        return;
      }

      // ── Driver assigned for the first time ────────────────────────────────────
      final driverJustAssigned = _ride!.driverId == null && updated.driverId != null;

      // If we were auto-searching and a driver was just found, stop searching
      if (_autoSearching) setState(() => _autoSearching = false);
      _retryTimer?.cancel();

      setState(() => _ride = updated);
      if (driverJustAssigned) _fetchDriverInfo();
      if (updated.isTerminal) _detachSocket();
    } catch (_) {}
  }

  // ── Auto-retry logic ──────────────────────────────────────────────────────────

  void _scheduleRetry() {
    _retryTimer?.cancel();
    // Wait 15 s before retrying to avoid hammering the server
    _retryTimer = Timer(const Duration(seconds: 15), _doRetry);
  }

  Future<void> _doRetry() async {
    if (!mounted) return;

    // Check whether the 5-minute window has elapsed
    final elapsed = DateTime.now().difference(_searchStartTime ?? DateTime.now());
    if (elapsed >= _searchTimeout) {
      if (mounted) setState(() { _autoSearching = false; _noDriverFinal = true; });
      return;
    }

    // Re-fetch estimates to get a fresh quote (old one may have expired)
    try {
      final items = await GeoService.estimateAll(
        originLat: widget.originLat,
        originLng: widget.originLng,
        destLat: widget.dest.lat,
        destLng: widget.dest.lng,
      );
      if (!mounted) return;

      // Keep same vehicle type if possible
      final prevType = _estimates?[_selectedIndex].vehicleType ?? 'CAR_MINI';
      final newIdx = items.indexWhere((e) => e.vehicleType == prevType).let(
          (i) => i >= 0 ? i : 0);
      if (items.isEmpty) { _scheduleRetry(); return; }

      setState(() { _estimates = items; _selectedIndex = newIdx; });

      final est = items[newIdx];
      final ride = await RideService.bookRide(
        quote: est.quote,
        pickupAddress: widget.originAddress,
        dropAddress: widget.dest.formatted,
      );
      if (!mounted) return;

      // New ride booked — reset relevant state and subscribe
      _detachSocket();
      setState(() {
        _ride = ride;
        _driverLocation = null;
        _approachPoints = [];
        _rideOtp = null;
      });
      _attachSocket();
      _refetchOnce();
    } catch (_) {
      // Any failure → schedule another attempt if still within window
      if (mounted) _scheduleRetry();
    }
  }

  void _onDriverLocation(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['rideId'] != _ride?.id) return;
      final newLoc = (
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      );
      setState(() => _driverLocation = newLoc);
      if (_ride?.status == 'DRIVER_ARRIVING' && !_approachLoading) {
        final driverLatLng = LatLng(newLoc.lat, newLoc.lng);
        final last = _lastApproachFetchDriver;
        final moved = last == null ||
            const Distance().as(LengthUnit.Meter, last, driverLatLng) > 300;
        if (moved) _fetchApproachRoute(driverLatLng);
      }
    } catch (_) {}
  }

  Future<void> _fetchApproachRoute(LatLng driverPos) async {
    if (_approachLoading || _ride == null) return;
    if (mounted) setState(() => _approachLoading = true);
    _lastApproachFetchDriver = driverPos;
    try {
      final result = await RouteService.fetchRoute(
        originLat: driverPos.latitude,
        originLng: driverPos.longitude,
        destLat: _ride!.pickupLat,
        destLng: _ride!.pickupLng,
      );
      if (mounted) setState(() { _approachPoints = result.points; _approachLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _approachLoading = false);
    }
  }

  void _onChatMsg(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data as Map);
      if (map['rideId'] != _ride?.id) return;
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
      if (map['rideId'] != _ride?.id) return;
      setState(() => _rideOtp = map['otp'] as String?);
    } catch (_) {}
  }

  Future<void> _fetchDriverInfo() async {
    try {
      final fresh = await RideService.getRide(_ride!.id);
      if (!mounted) return;
      if (fresh.driverInfo != null) setState(() => _ride = fresh);
    } catch (_) {}
  }

  Future<void> _refetchOnce() async {
    try {
      final fresh = await RideService.getRide(_ride!.id);
      if (!mounted) return;
      if (fresh.status == 'NO_DRIVERS_FOUND' || fresh.status == 'FAILED') {
        _handleNoDriverRide(fresh);
        return;
      }
      setState(() => _ride = fresh);
      if (fresh.isTerminal) _detachSocket();
    } catch (_) {}
  }

  void _handleNoDriverRide(Ride ride) {
    final elapsed = DateTime.now().difference(_searchStartTime ?? DateTime.now());
    if (elapsed < _searchTimeout) {
      _detachSocket();
      if (mounted) setState(() => _autoSearching = true);
      _scheduleRetry();
    } else {
      if (mounted) setState(() { _ride = ride; _autoSearching = false; _noDriverFinal = true; });
      _detachSocket();
    }
  }

  // ── Active ride actions ───────────────────────────────────────────────────────

  Future<void> _callDriver() async {
    final phone = _ride?.driverInfo?.phone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _cancel() async {
    if (_ride == null) return;

    String? cancelNote;

    if (_ride!.status == 'DRIVER_ARRIVED') {
      // Require a reason when the driver is already at the pickup point.
      cancelNote = await _showCancelReasonDialog();
      if (cancelNote == null || !mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel ride?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Are you sure you want to cancel this ride?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep ride', style: TextStyle(color: Color(0xFF999999))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Cancel ride',
                  style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    _retryTimer?.cancel();
    setState(() { _cancelling = true; _autoSearching = false; });
    try {
      if (_ride!.isTerminal) {
        _detachSocket();
        if (mounted) setState(() => _cancelling = false);
        return;
      }
      final updated = await RideService.cancelRide(_ride!.id, note: cancelNote);
      if (!mounted) return;
      setState(() { _ride = updated; _cancelling = false; });
      _detachSocket();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _detachSocket();
        setState(() => _cancelling = false);
        return;
      }
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<String?> _showCancelReasonDialog() {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? selected;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            title: const Text(
              'Why are you cancelling?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: _cancelReasons
                  .map((reason) => InkWell(
                        onTap: () => setDialogState(() => selected = reason),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected == reason
                                        ? _navy
                                        : const Color(0xFFCCCCCC),
                                    width: 2,
                                  ),
                                  color: selected == reason
                                      ? _navy
                                      : Colors.transparent,
                                ),
                                child: selected == reason
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 12)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selected == reason
                                        ? _navy
                                        : const Color(0xFF333333),
                                    fontWeight: selected == reason
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selected != null
                      ? () => Navigator.pop(ctx, selected)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Cancel Ride',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Keep Ride',
                      style: TextStyle(
                          color: Color(0xFF999999), fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _goRate() async {
    final rated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RatingScreen(rideId: _ride!.id)),
    );
    if (rated == true && mounted) setState(() => _rated = true);
  }

  Future<void> _openChat() async {
    _socket?.off('chat:message', _onChatMsg);
    final result = await Navigator.push<List<ChatMessage>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          rideId: _ride!.id,
          isDriver: false,
          socket: _socket,
          initialMessages: List.of(_messages),
        ),
      ),
    );
    _socket?.on('chat:message', _onChatMsg);
    if (result != null && mounted) {
      setState(() {
        _messages..clear()..addAll(result);
        _unreadMsgCount = 0;
      });
    }
  }

  void _tryAgain() {
    _retryTimer?.cancel();
    _detachSocket();
    setState(() {
      _phase = _Phase.estimating;
      _ride = null;
      _driverLocation = null;
      _approachPoints = [];
      _rideOtp = null;
      _messages.clear();
      _unreadMsgCount = 0;
      _cancelling = false;
      _rated = false;
      _autoSearching = false;
      _noDriverFinal = false;
      _searchStartTime = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.50,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    _loadEstimates();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String get _selectedVehicleType =>
      _estimates?[_selectedIndex].vehicleType ?? 'CAR_MINI';

  static IconData _vehicleIcon(String type) => switch (type) {
        'BIKE' => Icons.two_wheeler,
        'AUTO' => Icons.electric_rickshaw,
        'CAR_MINI' => Icons.directions_car,
        'CAR_SEDAN' => Icons.drive_eta,
        'CAR_SUV' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ride = _ride;
    final canPop = _phase == _Phase.estimating || (ride?.isTerminal ?? true);

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap()),

            // Back button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: canPop ? () => Navigator.pop(context) : null,
                  child: AnimatedOpacity(
                    opacity: canPop ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: _navy, size: 20),
                    ),
                  ),
                ),
              ),
            ),

            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.50,
              minChildSize: 0.35,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.50, 0.65, 0.92],
              builder: (ctx, sc) => _phase == _Phase.estimating
                  ? _buildEstimationPanel(sc)
                  : _buildActivePanel(sc),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map ───────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    if (_routeLoading) {
      return Container(
        color: const Color(0xFFEEEEEE),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final ride = _ride;
    if (_phase == _Phase.active && ride != null) {
      final pickup = LatLng(ride.pickupLat, ride.pickupLng);
      final drop = LatLng(ride.dropLat, ride.dropLng);
      final driver = _driverLocation != null
          ? LatLng(_driverLocation!.lat, _driverLocation!.lng)
          : null;
      if (ride.status == 'DRIVER_ARRIVING' && driver != null) {
        final route = _approachPoints.isNotEmpty ? _approachPoints : [driver, pickup];
        return RideMapWidget(
          routePoints: route, pickup: driver, drop: pickup,
          driverLocation: driver, vehicleType: ride.vehicleType,
        );
      }
      return RideMapWidget(
        routePoints: _routePoints, pickup: pickup, drop: drop,
        driverLocation: driver, vehicleType: ride.vehicleType,
      );
    }
    return RideMapWidget(
      routePoints: _routePoints,
      pickup: LatLng(widget.originLat, widget.originLng),
      drop: LatLng(widget.dest.lat, widget.dest.lng),
      vehicleType: _selectedVehicleType,
    );
  }

  // ── Estimation panel ──────────────────────────────────────────────────────────

  Widget _buildEstimationPanel(ScrollController sc) {
    final est = _estimates;
    return _PanelShell(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                  Container(width: 1.5, height: 18, color: const Color(0xFFBDBDBD)),
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE53935), width: 2))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.originAddress,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(widget.dest.formatted,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              const Text('Choose Your Ride',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
              const Spacer(),
              if (!_loadingEstimates && est != null)
                Text(
                  '${est[_selectedIndex].distanceText}  ·  ${est[_selectedIndex].etaText} away',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loadingEstimates
              ? const Center(child: CircularProgressIndicator(color: _navy))
              : _estimateError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(_estimateError!,
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 15)),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: _loadEstimates,
                            child: const Text('Retry',
                                style: TextStyle(color: _navy, fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      itemCount: est!.length,
                      itemBuilder: (_, i) => _VehicleCard(
                        estimate: est[i],
                        isSelected: _selectedIndex == i,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    ),
        ),
        if (!_loadingEstimates && _estimateError == null && est != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _booking ? null : _book,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _navy,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _booking
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          'Book ${est[_selectedIndex].displayName}  ·  ₹${est[_selectedIndex].fare.total.round()}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Active ride panel ─────────────────────────────────────────────────────────

  Widget _buildActivePanel(ScrollController sc) {
    final ride = _ride;
    if (ride == null) return const SizedBox.shrink();

    // ── 5 min elapsed with no driver — show failure panel ────────────────────────
    if (_noDriverFinal) return _buildNoDriverPanel(sc);

    // ── Normal in-progress panel ──────────────────────────────────────────────────
    return _PanelShell(
      children: [
        if (!ride.isTerminal || ride.isCompleted) _buildStepBar(ride),
        Expanded(
          child: ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            children: [
              _buildStatusCard(ride),
              const SizedBox(height: 12),
              _buildRouteCard(ride),
              const SizedBox(height: 12),
              _buildFareCard(ride),
              if (ride.driverId != null && !ride.isTerminal) ...[
                const SizedBox(height: 12),
                _buildDriverCard(ride),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _buildActiveActions(ride, isNoDriver: false),
          ),
        ),
      ],
    );
  }

  // ── No driver panel (shown after 5-min timeout) ───────────────────────────────

  Widget _buildNoDriverPanel(ScrollController sc) {
    return _PanelShell(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: sc,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car_outlined,
                          size: 36, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No drivers available right now',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We searched for several minutes but couldn\'t find a driver nearby. Try again shortly — availability changes quickly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF666666), height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _tryAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Try Again',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF666666),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back to Home',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared card builders ──────────────────────────────────────────────────────

  Widget _buildStepBar(Ride ride) {
    final step = ride.stepIndex;
    if (step < 0) return const SizedBox.shrink();
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: (i ~/ 2) < step
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
                width: 26, height: 26,
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
                child: Icon(_stepIcons[s], size: 13,
                    color: done || current
                        ? _navy
                        : Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 3),
              Text(_steps[s],
                  style: TextStyle(
                    color: done || current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                  )),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatusCard(Ride ride) {
    final isBad = ride.isCancelled;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isBad
            ? Colors.red.withValues(alpha: 0.05)
            : ride.isCompleted
                ? const Color(0xFF4CAF50).withValues(alpha: 0.05)
                : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBad
              ? Colors.red.withValues(alpha: 0.15)
              : ride.isCompleted
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                  : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBad
                  ? Colors.red.withValues(alpha: 0.1)
                  : ride.isCompleted
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                      : _navy.withValues(alpha: 0.06),
            ),
            child: Icon(
              isBad
                  ? Icons.cancel_outlined
                  : ride.isCompleted
                      ? Icons.check_circle_outline
                      : _stepIcons[ride.stepIndex.clamp(0, 4)],
              size: 24,
              color: isBad
                  ? Colors.red[600]
                  : ride.isCompleted
                      ? const Color(0xFF4CAF50)
                      : _navy,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride.statusLabel,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: isBad
                          ? Colors.red[700]
                          : ride.isCompleted
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF1C1C1E),
                    )),
                if (ride.status != 'DRIVER_ARRIVED') ...[
                  const SizedBox(height: 3),
                  Text(ride.statusDescription,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                  if (_driverLocation != null && !ride.isTerminal) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('Live location',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: Color(0xFF4CAF50))),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (ride.status == 'DRIVER_ARRIVED')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _rideOtp ?? '···',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            )
          else if (!ride.isTerminal)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _navy)),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Ride ride) {
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
              Container(width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50), shape: BoxShape.circle)),
              Container(width: 1.5, height: 30, color: const Color(0xFFDDDDDD)),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _navy, width: 2))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride.pickupAddress ?? 'Pickup location',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 18),
                Text(ride.dropAddress ?? 'Drop location',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard(Ride ride) {
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
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_vehicleIcon(ride.vehicleType), size: 22, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride.vehicleDisplayName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E))),
                const SizedBox(height: 3),
                Text('${ride.distanceText}  ·  ${ride.durationText}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${ride.fareToShow.round()}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E))),
              Text(ride.actualFare != null ? 'final' : 'estimated',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Ride ride) {
    final info = ride.driverInfo;
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
                radius: 24,
                backgroundColor: _navy.withValues(alpha: 0.1),
                child: Text(initials,
                    style: const TextStyle(
                        color: _navy, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info?.displayName ?? 'Your Driver',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E))),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 3),
                        Text(info?.ratingText ?? '5.0',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF666666))),
                        if (info?.vehicle != null) ...[
                          const SizedBox(width: 8),
                          const Text('·',
                              style: TextStyle(color: Color(0xFFCCCCCC))),
                          const SizedBox(width: 8),
                          Text('${info!.vehicle!.make} ${info.vehicle!.model}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF666666))),
                        ],
                      ],
                    ),
                    if (info?.vehicle?.plateNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(info!.vehicle!.plateNumber,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: Color(0xFF444444))),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                          top: -5, right: -5,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                                color: Color(0xFFE53935), shape: BoxShape.circle),
                            child: Center(
                              child: Text('$_unreadMsgCount',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8,
                                      fontWeight: FontWeight.bold)),
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
                    side: const BorderSide(color: _navy, width: 1.5),
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

  Widget _buildActiveActions(Ride ride, {required bool isNoDriver}) {
    if (ride.canCancel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _cancelling ? null : _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[600],
            side: BorderSide(color: Colors.red[300]!),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _cancelling
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.red[600]))
              : const Text('Cancel Ride',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
    }
    if (ride.isCompleted && !_rated) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _goRate,
          icon: const Icon(Icons.star_outline, size: 20),
          label: const Text('Rate Your Ride',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }
    if (ride.isTerminal) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Back to Home',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Panel shell ────────────────────────────────────────────────────────────────

class _PanelShell extends StatelessWidget {
  final List<Widget> children;
  const _PanelShell({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

// ── Vehicle card ───────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final VehicleEstimate estimate;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.estimate,
    required this.isSelected,
    required this.onTap,
  });

  static IconData _iconFor(String type) => switch (type) {
        'BIKE' => Icons.two_wheeler,
        'AUTO' => Icons.electric_rickshaw,
        'CAR_MINI' => Icons.directions_car,
        'CAR_SEDAN' => Icons.drive_eta,
        'CAR_SUV' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1A1A2E);
    final hasSurge = estimate.fare.surgeMultiplier > 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? navy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? navy : const Color(0xFFE8E8E8),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: navy.withValues(alpha: 0.18),
                  blurRadius: 14, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(estimate.vehicleType), size: 26,
                  color: isSelected ? Colors.white : navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(estimate.displayName,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E))),
                      if (hasSurge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withValues(
                                alpha: isSelected ? 0.25 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${estimate.fare.surgeMultiplier.toStringAsFixed(1)}× surge',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFFFFB380)
                                    : const Color(0xFFFF6B35)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${estimate.distanceText}  ·  ${estimate.etaText}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.6)
                              : const Color(0xFF999999))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${estimate.fare.total.round()}',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : const Color(0xFF1C1C1E))),
                if (estimate.fare.minimumApplied)
                  Text('min fare',
                      style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFFAAAAAA))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extension helper ───────────────────────────────────────────────────────────

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
