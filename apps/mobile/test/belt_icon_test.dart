import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/app/theme.dart';
import 'package:bjj_open_mat/shared/widgets/belt_icon.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('renders a CustomPaint', (tester) async {
    await _pump(tester, const BeltIcon(rank: 'purple', stripes: 2));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('renders all known ranks without throwing', (tester) async {
    for (final rank in const ['white', 'blue', 'purple', 'brown', 'black']) {
      await _pump(tester, BeltIcon(rank: rank, stripes: 3));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('unknown rank resolves to the white belt bg color', (tester) async {
    const icon = BeltIcon(rank: 'mauve');
    expect(icon.bgColor, BeltColors.beltData['white']!['bg']);
  });
}
