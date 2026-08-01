import 'dart:async';
import 'data/push_messaging.dart';
import 'data/device_repository.dart';

class PushController {
  final PushMessaging _messaging;
  final DeviceRepository _devices;
  final String platform;
  StreamSubscription<String>? _sub;

  PushController(this._messaging, this._devices, {required this.platform});

  Future<void> start() async {
    final granted = await _messaging.requestPermission();
    if (!granted) return;
    final token = await _messaging.getToken();
    if (token != null) await _devices.registerDevice(token, platform);
    _sub ??= _messaging.onTokenRefresh.listen((t) {
      _devices.registerDevice(t, platform);
    });
  }

  Future<void> stop(String? token) async {
    await _sub?.cancel();
    _sub = null;
    if (token != null) await _devices.unregisterDevice(token);
  }
}
