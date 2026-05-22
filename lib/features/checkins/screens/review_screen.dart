import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/om_widgets.dart';

const _categories = [
  _Category('Gym Quality',            5),
  _Category('Experience Level Match', 4),
  _Category('Cleanliness',            5),
  _Category('Friendliness',           0),
];

class _Category {
  final String label;
  final int value;
  const _Category(this.label, this.value);
}

class ReviewScreen extends StatefulWidget {
  final String checkinId;
  const ReviewScreen({super.key, required this.checkinId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final List<int> _ratings = [5, 4, 5, 0];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: OMColors.bg,
      body: Stack(
        children: [
          // Dimmed overlay
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [Color(0xFF2A3160), Color(0xFF0E1326)],
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.55)),

          // Bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xEEF4F1EC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: OMColors.borderHi),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, -20)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Center(
                          child: Container(
                            width: 44, height: 5,
                            decoration: BoxDecoration(
                              color: OMColors.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('YOU JUST ROLLED AT', style: omEyebrow(color: OMColors.crimson)),
                            const SizedBox(height: 4),
                            Text('Atos HQ', style: omH1(size: 26)),
                            const SizedBox(height: 2),
                            const Text('Tonight · 7:00 – 9:00 PM', style: TextStyle(fontFamily: 'Barlow', fontSize: 13, color: OMColors.muted)),
                          ],
                        ),
                      ),

                      // Category star rows
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                        child: Column(
                          children: List.generate(_categories.length, (i) {
                            final cat = _categories[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: OMColors.surfaceHi,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: OMColors.borderDark),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(cat.label, style: const TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w600, color: OMColors.text)),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(5, (j) => GestureDetector(
                                        onTap: () => setState(() => _ratings[i] = j + 1),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          child: Icon(
                                            j < _ratings[i] ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 22,
                                            color: j < _ratings[i] ? OMColors.star : OMColors.muted,
                                          ),
                                        ),
                                      )),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Comment field
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: OMColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: OMColors.borderDark),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Solid rolls tonight, good energy.', style: omBody(size: 13)),
                              const SizedBox(height: 6),
                              Text('Share more about your experience (optional)…', style: omBody(color: OMColors.faint, size: 13)),
                            ],
                          ),
                        ),
                      ),

                      // Submit
                      Padding(
                        padding: EdgeInsets.fromLTRB(22, 0, 22, 18 + bottomPad),
                        child: PrimaryBtn(
                          label: 'Post Review',
                          icon: Icons.check_circle_outline_rounded,
                          full: true,
                          onTap: () => context.pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
