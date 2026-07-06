import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/data/gym_requests.dart';
import 'my_gyms_screen.dart';

class AddGymScreen extends ConsumerStatefulWidget {
  const AddGymScreen({super.key});

  @override
  ConsumerState<AddGymScreen> createState() => _AddGymScreenState();
}

class _AddGymScreenState extends ConsumerState<AddGymScreen> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Set<String> _amenities = {'parking', 'showers'};
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  // Gym logo: picked preview bytes, the uploaded public URL, and upload state.
  Uint8List? _logoBytes;
  String? _logoUrl;
  bool _uploadingLogo = false;

  static const _amenityOpts = [
    ('parking', 'Parking', LucideIcons.parkingSquare),
    ('showers', 'Showers', LucideIcons.droplets),
    ('wifi', 'WiFi', LucideIcons.wifi),
    ('changing', 'Changing', LucideIcons.doorOpen),
    ('shop', 'Pro Shop', LucideIcons.shoppingBag),
    ('water', 'Water', LucideIcons.glassWater),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _teamCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _siteCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _toggleAmenity(String id) => setState(() {
        if (_amenities.contains(id)) {
          _amenities = {..._amenities}..remove(id);
        } else {
          _amenities = {..._amenities, id};
        }
      });

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty && _addrCtrl.text.trim().isNotEmpty && !_uploadingLogo;

  Future<void> _pickLogo() async {
    if (_uploadingLogo) return;
    // Downscale + re-encode to JPEG (keeps logos tiny; matches upload type).
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _uploadingLogo = true;
      _error = null;
    });
    try {
      final url = await ref.read(gymRepositoryProvider).uploadLogo(bytes, 'image/jpeg');
      if (mounted) {
        setState(() {
          _logoUrl = url;
          _uploadingLogo = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _uploadingLogo = false;
          _logoBytes = null;
          _error = 'Logo upload failed: ${e.message}';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(gymRepositoryProvider).create(CreateGymRequest(
            name: _nameCtrl.text.trim(),
            address: _addrCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            website: _siteCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            logoUrl: _logoUrl,
            amenities: _amenities.toList(),
          ));
      ref.invalidate(myGymsProvider);
      if (mounted) {
        setState(() {
          _saving = false;
          _submitted = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _Header(t: t, onClose: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PhotoDropzone(
                      t: t,
                      previewBytes: _logoBytes,
                      uploading: _uploadingLogo,
                      uploaded: _logoUrl != null,
                      onTap: _pickLogo,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GymFormField(t: t, label: 'Gym Name', isRequired: true, ctrl: _nameCtrl, hint: 'e.g. Atos Jiu-Jitsu HQ'),
                          const SizedBox(height: 16),
                          _AddressField(t: t, ctrl: _addrCtrl, onChanged: () => setState(() {})),
                          const SizedBox(height: 16),
                          _GymFormField(t: t, label: 'Affiliation / Team', hint: 'e.g. Atos · IBJJF affiliate', ctrl: _teamCtrl, icon: LucideIcons.medal, hintSuffix: 'optional'),
                          const SizedBox(height: 16),
                          _FormSection(t: t, title: 'Contact'),
                          const SizedBox(height: 12),
                          _GymFormField(t: t, label: 'Phone', ctrl: _phoneCtrl, icon: LucideIcons.phone, hint: '(555) 123-4567', keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                          _GymFormField(t: t, label: 'Email', ctrl: _emailCtrl, icon: LucideIcons.mail, hint: 'hello@gym.com', keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _GymFormField(t: t, label: 'Website', ctrl: _siteCtrl, icon: LucideIcons.globe, hint: 'gym.com'),
                          const SizedBox(height: 16),
                          _FormSection(t: t, title: 'Facilities'),
                          const SizedBox(height: 12),
                          _buildAmenities(t),
                          const SizedBox(height: 16),
                          _buildDescription(t),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.bg.withValues(alpha: 0), t.bg],
                  stops: const [0, 0.35],
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null) ...[
                  Text(_error!, style: t.miniStyle.copyWith(color: t.red, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildSubmitButton(context, t),
              ]),
            ),
          ),
          if (_submitted) _SuccessOverlay(t: t, title: 'Gym submitted!', subtitle: 'We\'ll verify the location and publish it within 24 hours.', onDone: () => context.pop()),
        ]),
      ),
    );
  }

  Widget _buildAmenities(AppTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('AMENITIES', style: t.labelStyle),
          const Spacer(),
          Text('${_amenities.length} selected', style: t.miniStyle.copyWith(fontSize: 10)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _amenityOpts.map((opt) {
            final active = _amenities.contains(opt.$1);
            return GestureDetector(
              onTap: () => _toggleAmenity(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? t.gi.withValues(alpha: 0.12) : t.bg,
                  borderRadius: BorderRadius.circular(t.cardRadius + 4),
                  border: Border.all(
                    color: active ? t.gi.withValues(alpha: 0.5) : t.border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(opt.$3, size: 14, color: active ? t.gi : t.muted),
                  const SizedBox(width: 6),
                  Text(opt.$2, style: t.bodyStyle.copyWith(
                    fontSize: 13,
                    color: active ? t.gi : t.body,
                    fontWeight: FontWeight.w700,
                  )),
                  if (active) ...[
                    const SizedBox(width: 5),
                    Icon(LucideIcons.check, size: 12, color: t.gi),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescription(AppTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('DESCRIPTION', style: t.labelStyle),
          const Spacer(),
          Text('optional', style: t.miniStyle.copyWith(fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: TextField(
            controller: _descCtrl,
            style: t.bodyStyle,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Tell practitioners what to expect — vibe, schedule, drop-in policy…',
              hintStyle: t.miniStyle.copyWith(fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, AppTokens t) {
    final enabled = _valid && !_saving;
    return GestureDetector(
      onTap: enabled ? _submit : null,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          color: enabled ? t.gi : t.border,
          borderRadius: BorderRadius.circular(t.cardRadius + 2),
          boxShadow: enabled
              ? [BoxShadow(color: t.gi.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_saving)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            )
          else
            const Icon(LucideIcons.check, size: 18, color: Colors.white),
          const SizedBox(width: 9),
          Text(_saving ? 'Saving…' : 'Add Gym', style: t.h2Style.copyWith(color: Colors.white, fontSize: 16)),
        ]),
      ),
    );
  }
}

// ── Sticky header ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AppTokens t;
  final VoidCallback onClose;

  const _Header({required this.t, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: t.isSport ? t.bg2 : t.bg,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.badgeRadius + 6),
              border: Border.all(color: t.border),
            ),
            child: Icon(LucideIcons.x, size: 18, color: t.text),
          ),
        ),
        Expanded(child: Center(child: Text('Add Your Gym', style: t.h2Style.copyWith(fontSize: 16)))),
        const SizedBox(width: 36),
      ]),
    );
  }
}

// ── Photo drop zone ───────────────────────────────────────────
class _PhotoDropzone extends StatelessWidget {
  final AppTokens t;
  final Uint8List? previewBytes;
  final bool uploading;
  final bool uploaded;
  final VoidCallback onTap;

  const _PhotoDropzone({
    required this.t,
    required this.onTap,
    this.previewBytes,
    this.uploading = false,
    this.uploaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(t.cardRadius + 2);
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
            Image.memory(previewBytes!, fit: BoxFit.cover)
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

// ── Address field with verified badge ────────────────────────
class _AddressField extends StatelessWidget {
  final AppTokens t;
  final TextEditingController ctrl;
  final VoidCallback onChanged;

  const _AddressField({required this.t, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasAddr = ctrl.text.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('ADDRESS', style: t.labelStyle),
        Text(' *', style: t.labelStyle.copyWith(color: t.red)),
        const Spacer(),
        if (!hasAddr) Text('We geocode this', style: t.miniStyle.copyWith(fontSize: 10)),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(LucideIcons.search, size: 18, color: hasAddr ? t.gi : t.muted),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: t.bodyStyle,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                hintText: 'Start typing an address…',
                hintStyle: t.miniStyle.copyWith(fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
              ),
            ),
          ),
        ]),
      ),
      if (hasAddr) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: t.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.green.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: t.green, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 9),
            Text(
              'Location pinned · we\'ll verify on submit',
              style: t.miniStyle.copyWith(fontSize: 11, color: t.green),
            ),
          ]),
        ),
      ],
    ]);
  }
}

// ── Section divider ───────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final AppTokens t;
  final String title;

  const _FormSection({required this.t, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title.toUpperCase(), style: t.labelStyle.copyWith(color: t.gi)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: t.border)),
    ]);
  }
}

// ── Generic text field with optional icon ────────────────────
class _GymFormField extends StatelessWidget {
  final AppTokens t;
  final String label;
  final bool isRequired;
  final String hint;
  final String? hintSuffix;
  final TextEditingController ctrl;
  final IconData? icon;
  final TextInputType? keyboardType;

  const _GymFormField({
    required this.t,
    required this.label,
    required this.ctrl,
    required this.hint,
    this.isRequired = false,
    this.hintSuffix,
    this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label.toUpperCase(), style: t.labelStyle),
        if (isRequired) Text(' *', style: t.labelStyle.copyWith(color: t.red)),
        if (hintSuffix != null) ...[
          const Spacer(),
          Text(hintSuffix!, style: t.miniStyle.copyWith(fontSize: 10)),
        ],
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: Row(children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, size: 18, color: t.muted),
            ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: t.bodyStyle,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: t.miniStyle.copyWith(fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(icon != null ? 10 : 14, 14, 14, 14),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Success overlay ───────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  final AppTokens t;
  final String title;
  final String subtitle;
  final VoidCallback onDone;

  const _SuccessOverlay({required this.t, required this.title, required this.subtitle, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: t.bg.withValues(alpha: 0.97),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(color: t.green.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  color: t.green, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: t.green.withValues(alpha: 0.4), blurRadius: 22)],
                ),
                child: const Icon(LucideIcons.check, size: 30, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: t.h1Style.copyWith(fontSize: 24)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle, textAlign: TextAlign.center, style: t.bodyStyle.copyWith(color: t.muted)),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              decoration: BoxDecoration(
                color: t.green,
                borderRadius: BorderRadius.circular(t.cardRadius + 2),
                boxShadow: [BoxShadow(color: t.green.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.check, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text('Done', style: t.h2Style.copyWith(color: Colors.white, fontSize: 16)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
