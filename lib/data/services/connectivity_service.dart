import 'dart:async';
import 'dart:io';

class ConnectivityService {
  static bool _isOnline = true;
  static final _controller = StreamController<bool>.broadcast();
  static Timer? _checkTimer;

  static bool get isOnline => _isOnline;
  static Stream<bool> get onStatusChanged => _controller.stream;

  static void startMonitoring() {
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnectivity());
  }

  static void stopMonitoring() {
    _checkTimer?.cancel();
    _controller.close();
  }

  static Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    } on SocketException {
      if (_isOnline) {
        _isOnline = false;
        _controller.add(false);
      }
    } on TimeoutException {
      if (_isOnline) {
        _isOnline = false;
        _controller.add(false);
      }
    }
  }
}
