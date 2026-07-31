import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/api/friendly_error.dart';
import '../../../core/design/tokens.dart';
import '../data/gym_repository.dart';

/// Shared logo picker: opens the gallery, downscales to a small JPEG, then
/// uploads it via [GymRepository.uploadLogo]. Reports progress and outcome
/// through callbacks so callers (create/edit gym screens) own their own
/// state (e.g. what to send on submit) without duplicating picker mechanics.
class GymLogoPicker extends ConsumerStatefulWidget {
  final void Function(String url) onUploaded;
  final void Function(bool uploading)? onUploadingChanged;
  final void Function(String message)? onError;
  final String? existingLogoUrl;

  const GymLogoPicker({
    super.key,
    required this.onUploaded,
    this.onUploadingChanged,
    this.onError,
    this.existingLogoUrl,
  });

  @override
  GymLogoPickerState createState() => GymLogoPickerState();
}

class GymLogoPickerState extends ConsumerState<GymLogoPicker> {
  Uint8List? _bytes;
  bool _uploading = false;

  /// Opens the gallery, downscales, then uploads. Separated from [uploadBytes]
  /// so tests can exercise the upload path without a native picker.
  Future<void> pickAndUpload() async {
    if (_uploading) return;
    // Downscale + re-encode to JPEG (keeps logos tiny; matches upload type).
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    await uploadBytes(await file.readAsBytes());
  }

  /// Uploads already-picked bytes. Public so widget tests can drive it.
  Future<void> uploadBytes(Uint8List bytes) async {
    setState(() {
      _bytes = bytes;
      _uploading = true;
    });
    widget.onUploadingChanged?.call(true);
    try {
      final url = await ref.read(gymRepositoryProvider).uploadLogo(bytes, 'image/jpeg');
      if (!mounted) return;
      setState(() => _uploading = false);
      widget.onUploadingChanged?.call(false);
      widget.onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _bytes = null;
      });
      widget.onUploadingChanged?.call(false);
      widget.onError?.call(friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _Dropzone(
      key: const Key('gym-logo-picker'),
      t: t,
      previewBytes: _bytes,
      uploading: _uploading,
      uploaded: _bytes != null && !_uploading,
      existingLogoUrl: widget.existingLogoUrl,
      onTap: pickAndUpload,
    );
  }
}

// ── Photo drop zone ───────────────────────────────────────────
class _Dropzone extends StatelessWidget {
  final AppTokens t;
  final Uint8List? previewBytes;
  final bool uploading;
  final bool uploaded;
  final String? existingLogoUrl;
  final VoidCallback onTap;

  const _Dropzone({
    super.key,
    required this.t,
    required this.onTap,
    this.previewBytes,
    this.uploading = false,
    this.uploaded = false,
    this.existingLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(t.cardRadius + 2);
    final hasExisting = previewBytes == null && (existingLogoUrl?.isNotEmpty ?? false);
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        height: 120,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: radius,
          border: Border.all(color: t.borderHi, width: 2),
        ),
        child: Stack(fit: StackFit.expand, children: [
          if (previewBytes != null)
            Image.memory(
              previewBytes!,
              fit: BoxFit.cover,
              // Decoding happens off the widget-build path; a bad/corrupt
              // picked file should fall back quietly rather than crash.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else if (hasExisting)
            CachedNetworkImage(imageUrl: existingLogoUrl!, fit: BoxFit.cover)
          else
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: t.gi.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(t.badgeRadius + 4),
                ),
                child: Icon(LucideIcons.plus, size: 22, color: t.gi),
              ),
              const SizedBox(height: 8),
              Text('Add gym logo', style: t.miniStyle.copyWith(fontSize: 12, color: t.muted)),
            ]),
          if (uploading)
            Container(
              key: const Key('gym-logo-picker-uploading'),
              color: Colors.black.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 26, height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
            ),
          if (previewBytes != null && !uploading)
            Positioned(
              right: 8, bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (uploaded ? t.green : t.muted).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(uploaded ? LucideIcons.check : LucideIcons.pencil, size: 12, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(uploaded ? 'Logo added' : 'Change', style: t.miniStyle.copyWith(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
