import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Report')),
      body: Center(child: Text('Report a bug or request a feature', style: t.bodyStyle)),
    );
  }
}
