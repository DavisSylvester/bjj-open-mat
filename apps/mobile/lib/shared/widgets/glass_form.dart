import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

/// Filled, borderless input decoration matching Find's glass field language:
/// `t.surfaceHi` fill, radius 16, no visible border, muted hint.
InputDecoration glassInput(AppTokens t, String hint) {
  final radius = BorderRadius.circular(16);
  return InputDecoration(
    filled: true,
    fillColor: t.surfaceHi,
    hintText: hint,
    hintStyle: t.bodyStyle.copyWith(color: t.faint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    disabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
  );
}

/// Canonical indigo pill segmented control — the shared replacement for both
/// Report's Bug/Feature toggle style and Edit Profile's (formerly green)
/// segmented controls. Selected segment is solid `t.primary` with white
/// label/icon; unselected segments are transparent with `t.body` label, all
/// riding on a `t.surfaceHi` track.
class GlassSegmented extends StatelessWidget {
  final List<({String value, String label, IconData? icon})> options;
  final String value;
  final ValueChanged<String> onChanged;
  final AppTokens? t;

  const GlassSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = t ?? Theme.of(context).extension<AppTokens>()!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceHi,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: options.map((opt) {
          final selected = opt.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? tokens.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (opt.icon != null) ...[
                      Icon(opt.icon, size: 15, color: selected ? Colors.white : tokens.body),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        opt.label,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.bodyStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected ? Colors.white : tokens.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ALL-CAPS muted section label, matching Find's `WHEN` / `WITHIN` headers.
Widget glassSectionLabel(AppTokens t, String text) => Text(text.toUpperCase(), style: t.labelStyle);
