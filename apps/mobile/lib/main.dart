import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'core/design/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BjjOpenMatApp()));
}

class BjjOpenMatApp extends ConsumerStatefulWidget {
  const BjjOpenMatApp({super.key});

  @override
  ConsumerState<BjjOpenMatApp> createState() => _BjjOpenMatAppState();
}

class _BjjOpenMatAppState extends ConsumerState<BjjOpenMatApp> {
  @override
  void initState() {
    super.initState();
    // Auth check disabled — dev mode starts pre-authenticated
    // To re-enable: ref.read(authStateProvider.notifier).checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BJJ Open Mat Finder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.glass(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
