import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class BroadcastService {
  BroadcastService._();

  static final BroadcastService _instance = BroadcastService._();

  factory BroadcastService() => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final StreamController<bool> _offlineController =
      StreamController<bool>.broadcast();
  final StreamController<String> _customBroadcastController =
      StreamController<String>.broadcast();

  bool? _isOnline;

  Stream<bool> get offlineStream => _offlineController.stream;
  Stream<String> get customBroadcastStream => _customBroadcastController.stream;

  Future<void> initialize() async {
    final current = await _connectivity.checkConnectivity();
    final isOnline = _isOnlineFromResult(current);
    _isOnline = isOnline;
    _offlineController.add(!isOnline);

    _connectivitySub ??= _connectivity.onConnectivityChanged.listen((results) {
      final onlineNow = _isOnlineFromResult(results);
      if (_isOnline == true && !onlineNow) {
        print(
          '[IMPLICIT BROADCAST] System alert: Internet connection changed.',
        );
      }
      if (_isOnline != onlineNow) {
        _offlineController.add(!onlineNow);
      }
      _isOnline = onlineNow;
    });
  }

  void sendNewOrderBroadcast({String? orderId}) {
    print(
      '[EXPLICIT BROADCAST] App alert: Internal message sent for New Order.',
    );
    final message = orderId == null
        ? 'New Order placed.'
        : 'New Order placed: $orderId';
    _customBroadcastController.add(message);
  }

  bool _isOnlineFromResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _offlineController.close();
    await _customBroadcastController.close();
  }
}
