import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/om_widgets.dart';

const _suggestions = [
  _AddressSuggestion('9587 Distribution Ave', 'San Diego, CA 92121', true),
  _AddressSuggestion('9587 Distribution Way', 'Vista, CA 92081',     false),
  _AddressSuggestion('9587 Distribution Blvd','Los Angeles, CA 90015',false),
];

class _AddressSuggestion {
  final String main;
  final String sub;
  final bool highlight;
  const _AddressSuggestion(this.main, this.sub, this.highlight);
}

class AddGymScreen extends StatelessWidget {
  const AddGymScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: OMColors.bg,
      body: GradientBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topPad + 8),

            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: GlassCard(
                      padding: const EdgeInsets.all(9),
                      borderRadius: 12,
                      child: const Icon(Icons.close_rounded, size: 18, color: OMColors.text),
                    ),
                  ),
                  const Spacer(),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: 'Step ', style: omEyebrow()),
                        TextSpan(text: '1', style: omNum(size: 14)),
                        TextSpan(text: ' / 3', style: omNum(color: OMColors.muted, size: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i == 0 ? OMColors.crimson : OMColors.faint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                )),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REGISTER YOUR GYM', style: omEyebrow(color: OMColors.crimson)),
                  const SizedBox(height: 4),
                  Text('Basic Info', style: omH1(size: 28)),
                  const SizedBox(height: 4),
                  const Text('Help practitioners find you.', style: TextStyle(fontFamily: 'Barlow', fontSize: 13, color: OMColors.muted)),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gym name
                    Text('GYM NAME', style: omEyebrow(size: 10)),
                    const SizedBox(height: 6),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      borderRadius: 14,
                      elevated: true,
                      child: const SizedBox(
                        height: 56,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Atos Jiu-Jitsu HQ', style: TextStyle(fontFamily: 'Barlow', fontSize: 16, fontWeight: FontWeight.w600, color: OMColors.text)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Address autocomplete
                    Text('ADDRESS', style: omEyebrow(size: 10)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: OMColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OMColors.crimson.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(color: OMColors.crimson.withValues(alpha: 0.067), blurRadius: 0, spreadRadius: 4),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        children: [
                          // Input row
                          SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                const Icon(Icons.search_rounded, size: 16, color: OMColors.crimson),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text('9587 Distribution', style: TextStyle(fontFamily: 'Barlow', fontSize: 15, color: OMColors.text)),
                                ),
                                Container(width: 1, height: 22, color: OMColors.borderDark),
                                const SizedBox(width: 10),
                                const Icon(Icons.location_on_rounded, size: 16, color: OMColors.muted),
                                const SizedBox(width: 14),
                              ],
                            ),
                          ),
                          // Suggestions dropdown
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: OMColors.borderDark)),
                            ),
                            child: Column(
                              children: List.generate(_suggestions.length, (i) {
                                final s = _suggestions[i];
                                return Column(
                                  children: [
                                    if (i > 0) const Divider(height: 1, color: OMColors.borderDark),
                                    Container(
                                      color: s.highlight ? OMColors.crimson.withValues(alpha: 0.067) : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 14, color: s.highlight ? OMColors.crimson : OMColors.muted),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(s.main, style: const TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w500, color: OMColors.text)),
                                                const SizedBox(height: 1),
                                                Text(s.sub, style: const TextStyle(fontFamily: 'Barlow', fontSize: 11, color: OMColors.muted)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Verified location chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: OMColors.teal.withValues(alpha: 0.078),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: OMColors.teal.withValues(alpha: 0.333)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(color: OMColors.teal, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('VERIFIED LOCATION', style: omEyebrow(color: OMColors.teal, size: 9)),
                                const SizedBox(height: 2),
                                const Text('San Diego, CA · 32.901, -117.213', style: TextStyle(fontFamily: 'Barlow', fontSize: 13, fontWeight: FontWeight.w500, color: OMColors.text)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer CTA
            Container(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottomPad),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [OMColors.bg.withValues(alpha: 0), OMColors.bg],
                ),
              ),
              child: PrimaryBtn(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                full: true,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
