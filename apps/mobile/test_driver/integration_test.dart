import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Directory('build/e2e');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      File('build/e2e/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
