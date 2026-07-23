import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Requests App Tracking Transparency authorization on iOS 14+.
/// On Android (or if status is already determined) this is a no-op.
/// Call once before requesting device location.
Future<void> requestTrackingIfNeeded() async {
  if (!Platform.isIOS) return;
  final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  if (status == TrackingStatus.notDetermined) {
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}
