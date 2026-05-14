import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_endpoints.dart';
import '../storage/token_storage.dart';

/// Owns one Socket.IO connection per namespace (`/driver`, `/rider`).
/// Lifecycle is tied to auth: connect on login/startup, disconnect on logout.
class SocketManager {
  SocketManager._();
  static final SocketManager instance = SocketManager._();

  io.Socket? _driver;
  io.Socket? _rider;

  bool get driverConnected => _driver?.connected ?? false;
  bool get riderConnected  => _rider?.connected  ?? false;

  io.Socket? get driverSocket => _driver;
  io.Socket? get riderSocket  => _rider;

  /// Connect to the `/driver` namespace. Returns an already-connected socket
  /// if one exists. Throws if no access token is stored.
  Future<io.Socket> connectDriver() async {
    if (_driver != null && _driver!.connected) return _driver!;
    _driver?.dispose();
    _driver = await _connect('/driver');
    return _driver!;
  }

  /// Connect to the `/rider` namespace. Returns an already-connected socket
  /// if one exists. Throws if no access token is stored.
  Future<io.Socket> connectRider() async {
    if (_rider != null && _rider!.connected) return _rider!;
    _rider?.dispose();
    _rider = await _connect('/rider');
    return _rider!;
  }

  Future<io.Socket> _connect(String namespace) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Cannot connect socket: no access token');
    }

    final url = '${ApiEndpoints.baseUrl}$namespace';
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );
    socket.connect();
    return socket;
  }

  /// Disconnect and dispose both sockets. Safe to call multiple times.
  void disconnectAll() {
    _driver?.dispose();
    _rider?.dispose();
    _driver = null;
    _rider = null;
  }
}
