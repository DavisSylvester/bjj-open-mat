import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';

class DirectionsInfo {
  final String mapsUrl;
  const DirectionsInfo({required this.mapsUrl});
}

DirectionsInfo parseDirections(Map<String, dynamic> body) {
  final data = unwrapData(body);
  return DirectionsInfo(mapsUrl: data['mapsUrl'] as String? ?? '');
}

String addressMapsUrl(String address) =>
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';

/// Opens the platform maps app with directions to a gym (preferred) or a
/// raw address fallback. Shows a snackbar on any failure.
Future<void> openDirections(
  WidgetRef ref,
  BuildContext context, {
  String? gymId,
  String? address,
}) async {
  String url = '';
  try {
    if (gymId != null && gymId.isNotEmpty) {
      final dio = ref.read(apiClientProvider).dio;
      final res = await dio.get(Endpoints.gymDirections(gymId));
      url = parseDirections(res.data as Map<String, dynamic>).mapsUrl;
    }
  } catch (_) {
    url = '';
  }
  if (url.isEmpty && address != null && address.isNotEmpty) {
    url = addressMapsUrl(address);
  }
  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location available for directions')),
      );
    }
    return;
  }
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open maps")),
    );
  }
}
