import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract class NetworkMonitor extends ChangeNotifier {
  bool get offline;
  Future<void> start();
}

class PlatformNetworkMonitor extends NetworkMonitor {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false, _disposed = false;
  @override
  bool get offline => _offline;
  void _update(List<ConnectivityResult> results) {
    if (_disposed) return;
    final offline =
        results.isNotEmpty &&
        results.every((result) => result == ConnectivityResult.none);
    if (offline != _offline) {
      _offline = offline;
      notifyListeners();
    }
  }

  @override
  Future<void> start() async {
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        _update,
        onError: (_) {},
      );
      _update(await _connectivity.checkConnectivity());
    } catch (_) {
      /* Unknown connectivity still allows normal guarded requests. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

class FixedNetworkMonitor extends NetworkMonitor {
  FixedNetworkMonitor({this.offline = false});
  @override
  bool offline;
  @override
  Future<void> start() async {}
  void setOffline(bool value) {
    offline = value;
    notifyListeners();
  }
}
