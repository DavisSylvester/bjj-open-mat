import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/push/data/push_messaging.dart';
import 'package:bjj_open_mat/features/push/data/device_repository.dart';
import 'package:bjj_open_mat/features/push/push_controller.dart';

class _FakeMessaging implements PushMessaging {
  final bool granted;
  final String? token;
  final _refresh = StreamController<String>.broadcast();
  _FakeMessaging({this.granted = true, this.token = 'tok-1'});
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => _refresh.stream;
  void emit(String t) => _refresh.add(t);
}

class _FakeDeviceRepo implements DeviceRepository {
  final registered = <String>[];
  final unregistered = <String>[];
  @override
  Future<void> registerDevice(String token, String platform) async => registered.add('$token:$platform');
  @override
  Future<void> unregisterDevice(String token) async => unregistered.add(token);
}

void main() {
  test('start registers the token when permission granted', () async {
    final repo = _FakeDeviceRepo();
    final c = PushController(_FakeMessaging(), repo, platform: 'ios');
    await c.start();
    expect(repo.registered, ['tok-1:ios']);
  });

  test('start does nothing when permission denied', () async {
    final repo = _FakeDeviceRepo();
    final c = PushController(_FakeMessaging(granted: false), repo, platform: 'ios');
    await c.start();
    expect(repo.registered, isEmpty);
  });

  test('token refresh re-registers', () async {
    final repo = _FakeDeviceRepo();
    final msg = _FakeMessaging();
    final c = PushController(msg, repo, platform: 'android');
    await c.start();
    msg.emit('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(repo.registered, ['tok-1:android', 'tok-2:android']);
  });
}
