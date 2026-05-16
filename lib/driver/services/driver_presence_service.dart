import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/socket/socket_manager.dart';

/// Presence + location streaming over the `/driver` Socket.IO namespace.
///
/// Backend contract (see geo.gateway.ts):
///   - `online:start { vehicleId, lat, lng }` → ack `{ok}` / `{ok:false, error}`
///   - `location:update { lat, lng, heading?, speed?, accuracy? }` every ~4s
///   - `online:stop {}`
///
/// The alive-beacon TTL on the server is 60s, so any throttle under ~30s is safe.
class DriverPresenceService {
  static StreamSubscription<Position>? _locationSub;
  static Timer? _heartbeatTimer;
  static DateTime? _lastEmit;
  static String? _lastVehicleId;
  static double? _lastLat;
  static double? _lastLng;
  static const _minInterval = Duration(seconds: 4);
  static const _heartbeatInterval = Duration(seconds: 25);

  /// Emit `online:start`. Returns true on `{ok: true}` ack.
  /// Throws [PresenceException] on negative ack or socket error.
  static Future<void> goOnline({
    required String vehicleId,
    required double lat,
    required double lng,
  }) async {
    _lastVehicleId = vehicleId;
    _lastLat = lat;
    _lastLng = lng;
    final socket = await SocketManager.instance.connectDriver();
    await _waitConnected(socket);
    final ack = await _emitWithAck(socket, 'online:start', {
      'vehicleId': vehicleId,
      'lat': lat,
      'lng': lng,
    });
    _throwIfNotOk(ack);
  }

  /// Re-emits `online:start` after a socket reconnect so the server continues
  /// routing ride offers to this socket. Best-effort; never throws.
  static Future<void> refreshPresence() async {
    final vehicleId = _lastVehicleId;
    if (vehicleId == null) return;
    final socket = SocketManager.instance.driverSocket;
    if (socket == null || !socket.connected) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _emitWithAck(socket, 'online:start', {
        'vehicleId': vehicleId,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (_) {}
  }

  /// Emit `online:stop` and stop streaming GPS. Best-effort; doesn't throw on
  /// transport errors, only on explicit server NACK.
  static Future<void> goOffline() async {
    stopLocationStream();
    final socket = SocketManager.instance.driverSocket;
    if (socket == null || !socket.connected) return;
    try {
      final ack = await _emitWithAck(socket, 'online:stop', <String, dynamic>{});
      _throwIfNotOk(ack);
    } on TimeoutException {
      // Server is unreachable — local state is already cleared.
    }
  }

  /// Begin streaming GPS positions and emit `location:update` at most every 4s.
  /// Also starts a 25s heartbeat so stationary drivers keep their server
  /// alive-beacon alive (TTL = 60s) even without any movement.
  /// Requires location permission already granted; call [ensurePermission] first.
  static void startLocationStream() {
    if (_locationSub != null) return;
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPosition, onError: (_) {});
    _heartbeatTimer ??=
        Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  static void stopLocationStream() {
    _locationSub?.cancel();
    _locationSub = null;
    _lastEmit = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static void _sendHeartbeat() {
    final lat = _lastLat;
    final lng = _lastLng;
    if (lat == null || lng == null) return;
    final socket = SocketManager.instance.driverSocket;
    if (socket == null || !socket.connected) return;
    socket.emit('location:update', {'lat': lat, 'lng': lng});
  }

  static void _onPosition(Position pos) {
    _lastLat = pos.latitude;
    _lastLng = pos.longitude;
    final now = DateTime.now();
    if (_lastEmit != null && now.difference(_lastEmit!) < _minInterval) return;
    final socket = SocketManager.instance.driverSocket;
    if (socket == null || !socket.connected) return;
    _lastEmit = now;
    socket.emit('location:update', {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (pos.heading >= 0) 'heading': pos.heading,
      if (pos.speed >= 0) 'speed': pos.speed,
      if (pos.accuracy >= 0) 'accuracy': pos.accuracy,
    });
  }

  /// Requests location permission if needed. Returns true if granted.
  static Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Returns current GPS position. Throws on permission denied.
  static Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ── internals ──────────────────────────────────────────────────────────────

  static Future<void> _waitConnected(io.Socket socket) async {
    if (socket.connected) return;
    final completer = Completer<void>();
    void onConnect(dynamic _) {
      if (!completer.isCompleted) completer.complete();
    }
    void onError(dynamic err) {
      if (!completer.isCompleted) {
        completer.completeError(PresenceException(err.toString()));
      }
    }
    socket.once('connect', onConnect);
    socket.once('connect_error', onError);
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw PresenceException('Socket connect timed out'),
    );
  }

  static Future<Map<String, dynamic>> _emitWithAck(
    io.Socket socket,
    String event,
    Map<String, dynamic> data,
  ) {
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      data,
      ack: (dynamic response) {
        if (!completer.isCompleted) {
          completer.complete(
            response is Map ? Map<String, dynamic>.from(response) : {'ok': false, 'error': 'Bad ack'},
          );
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('No ack from server for $event'),
    );
  }

  static void _throwIfNotOk(Map<String, dynamic> ack) {
    if (ack['ok'] == true) return;
    throw PresenceException(ack['error']?.toString() ?? 'Server rejected request');
  }
}

class PresenceException implements Exception {
  final String message;
  const PresenceException(this.message);

  @override
  String toString() => message;
}
