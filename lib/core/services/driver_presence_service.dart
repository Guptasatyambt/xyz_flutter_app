import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../socket/socket_manager.dart';

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
  static DateTime? _lastEmit;
  static const _minInterval = Duration(seconds: 4);

  /// Emit `online:start`. Returns true on `{ok: true}` ack.
  /// Throws [PresenceException] on negative ack or socket error.
  static Future<void> goOnline({
    required String vehicleId,
    required double lat,
    required double lng,
  }) async {
    final socket = await SocketManager.instance.connectDriver();
    await _waitConnected(socket);
    final ack = await _emitWithAck(socket, 'online:start', {
      'vehicleId': vehicleId,
      'lat': lat,
      'lng': lng,
    });
    _throwIfNotOk(ack);
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
  /// Requires location permission already granted; call [ensurePermission] first.
  static void startLocationStream() {
    if (_locationSub != null) return;
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  static void stopLocationStream() {
    _locationSub?.cancel();
    _locationSub = null;
    _lastEmit = null;
  }

  static void _onPosition(Position pos) {
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
