import 'package:firebase_messaging/firebase_messaging.dart';
import 'push_messaging.dart';

class FirebasePushMessaging implements PushMessaging {
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _fm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;
}
