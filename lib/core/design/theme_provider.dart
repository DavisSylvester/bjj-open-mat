import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ThemeVariant { sport, glass }

class ThemeNotifier extends Notifier<ThemeVariant> {
  @override
  ThemeVariant build() => ThemeVariant.sport;

  void toggle() {
    state = state == ThemeVariant.sport ? ThemeVariant.glass : ThemeVariant.sport;
  }

  void set(ThemeVariant variant) {
    state = variant;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeVariant>(ThemeNotifier.new);
