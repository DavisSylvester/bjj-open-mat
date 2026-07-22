import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

/// A compact host for display, e.g. `https://www.rmelitebjj.com/x` -> `rmelitebjj.com`.
String websiteDisplayHost(String raw) {
  var s = raw.trim();
  s = s.replaceFirst(_scheme, '');
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  s = s.replaceFirst(RegExp(r'/.*$'), '');
  return s;
}

/// Ensures a launchable absolute URL — prepends https:// when no scheme is present.
String normalizeWebsiteUrl(String raw) {
  final s = raw.trim();
  return _scheme.hasMatch(s) ? s : 'https://$s';
}

/// Opens the gym's website in the default browser. Shows a snackbar on failure.
Future<void> openWebsite(BuildContext context, String rawUrl) async {
  final ok = await launchUrl(Uri.parse(normalizeWebsiteUrl(rawUrl)), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open website")),
    );
  }
}
