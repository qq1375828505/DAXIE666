import 'dart:async';
import 'dart:io';

class ConnectivityService {
  static bool _isOnline = true;
  static final _controller = StreamController<bool>.broadcast();
  static Timer? _checkTimer;

  static bool get isOnline => _isOnline;
  static Stream<bool> get onStatusChanged => _controller.stream;

  static void startMonitoring() {
    // 立即检查一次
    _checkConnectivity();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnectivity());
  }

  static void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  static Future<void> _checkConnectivity() async {
    try {
      // 多域名检测：国内用 baidu，海外用 google，任一成功即在线
      final results = await Future.any([
        InternetAddress.lookup('www.baidu.com')
            .timeout(const Duration(seconds: 3)),
        InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3)),
      ]);
      final online = results.isNotEmpty && results.first.rawAddress.isNotEmpty;
      if (online != _isOnline) {
        _isOnline = online;
        if (!_controller.isClosed) _controller.add(_isOnline);
      }
    } on SocketException {
      if (_isOnline) {
        _isOnline = false;
        if (!_controller.isClosed) _controller.add(false);
      }
    } on TimeoutException {
      if (_isOnline) {
        _isOnline = false;
        if (!_controller.isClosed) _controller.add(false);
      }
    }
  }
}
