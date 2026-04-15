import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bjj_open_mat/main.dart';

void main() {
  testWidgets('App starts without error', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BjjOpenMatApp()));
    await tester.pump();
    expect(find.byType(BjjOpenMatApp), findsOneWidget);
  });
}
