import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app/router.dart';
import 'core/design/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'features/push/push_controller.dart';
import 'features/push/data/device_repository.dart';
import 'features/push/data/firebase_push_messaging.dart';
import 'features/push/push_routing.dart';

// ---------------------------------------------------------------------------
// Background message handler — must be a top-level function.
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled silently; the OS notification is shown
  // automatically by the FCM SDK when the notification payload is present.
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Controls whether Firebase is initialised. Returns false in tests so no
/// Firebase code runs inside widgets. main() overrides it to _PushReadyTrue.
class _PushReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

class _PushReadyTrue extends _PushReadyNotifier {
  @override
  bool build() => true;
}

final pushReadyProvider =
    NotifierProvider<_PushReadyNotifier, bool>(_PushReadyNotifier.new);

/// The real PushMessaging implementation backed by FirebaseMessaging.
final firebasePushMessagingProvider = Provider<FirebasePushMessaging>(
  (_) => FirebasePushMessaging(),
);

/// The PushController wired to the real Firebase impl and the API device repo.
final pushControllerProvider = Provider<PushController>((ref) {
  final messaging = ref.read(firebasePushMessagingProvider);
  final devices = ref.read(deviceRepositoryProvider);
  final platform = Platform.isIOS ? 'ios' : 'android';
  return PushController(messaging, devices, platform: platform);
});

// ---------------------------------------------------------------------------
// Local notifications plugin (foreground banners)
// ---------------------------------------------------------------------------
final _localNotifications = FlutterLocalNotificationsPlugin();

const _androidChannel = AndroidNotificationChannel(
  'bjj_open_mat_default',
  'BJJ Open Mat Notifications',
  description: 'General notifications for BJJ Open Mat Finder',
  importance: Importance.high,
);

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await _localNotifications.initialize(settings: settings);
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

void _showForegroundBanner(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  _localNotifications.show(
    id: notification.hashCode,
    title: notification.title,
    body: notification.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: _androidChannel.importance,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await _initLocalNotifications();

  runApp(
    ProviderScope(
      overrides: [
        pushReadyProvider.overrideWith(_PushReadyTrue.new),
      ],
      child: const BjjOpenMatApp(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------
class BjjOpenMatApp extends ConsumerStatefulWidget {
  const BjjOpenMatApp({super.key});

  @override
  ConsumerState<BjjOpenMatApp> createState() => _BjjOpenMatAppState();
}

class _BjjOpenMatAppState extends ConsumerState<BjjOpenMatApp> {
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  String? _currentToken;
  bool _pushListenersStarted = false;

  @override
  void initState() {
    super.initState();
    // Auth check disabled — dev mode starts pre-authenticated
    // To re-enable: ref.read(authStateProvider.notifier).checkAuth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pushReady = ref.read(pushReadyProvider);
    if (pushReady && !_pushListenersStarted) {
      _pushListenersStarted = true;
      _startPushListeners();
    }
  }

  void _open(Map<String, dynamic> data, GoRouter router) {
    final route = routeForPushData(Map<String, dynamic>.from(data));
    if (route != null) router.go(route);
  }

  void _startPushListeners() {
    final router = ref.read(routerProvider);

    // Foreground banner
    _fgSub = FirebaseMessaging.onMessage.listen(_showForegroundBanner);

    // Tap on notification while app is in background
    _tapSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _open(m.data, router),
    );

    // App opened from a terminated state via a notification
    FirebaseMessaging.instance.getInitialMessage().then((initial) {
      if (initial != null) _open(initial.data, router);
    });
  }

  @override
  void dispose() {
    _fgSub?.cancel();
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Watch auth state to start/stop PushController — only when Firebase is ready.
    final pushReady = ref.watch(pushReadyProvider);
    if (pushReady) {
      ref.listen<AuthState>(authStateProvider, (prev, next) async {
        final controller = ref.read(pushControllerProvider);
        if (next.status == AuthStatus.authenticated &&
            prev?.status != AuthStatus.authenticated) {
          await controller.start();
          _currentToken = await FirebaseMessaging.instance.getToken();
        } else if (next.status == AuthStatus.unauthenticated &&
            prev?.status == AuthStatus.authenticated) {
          await controller.stop(_currentToken);
          _currentToken = null;
        }
      });
    }

    return MaterialApp.router(
      title: 'BJJ Open Mat Finder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.glass(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
