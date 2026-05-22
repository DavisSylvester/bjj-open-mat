import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/open_mat.dart';
import '../../../shared/widgets/om_widgets.dart';

const _reviews = [
  _Review(name: 'Marcus T.', belt: 'purple', stripes: 2, rating: 5, when: '2 days ago', text: 'Awesome rolls, mat space was spotless. Beginners felt welcome.'),
  _Review(name: 'Jenna K.',  belt: 'blue',   stripes: 4, rating: 4, when: '1 wk ago',   text: 'Good mix of belts. Wish it ran a bit longer.'),
];

class _Review {
  final String name;
  final String belt;
  final int stripes;
  final int rating;
  final String when;
  final String text;
  const _Review({required this.name, required this.belt, required this.stripes, required this.rating, required this.when, required this.text});
}

class OpenMatDetailScreen extends StatelessWidget {
  final String openMatId;
  const OpenMatDetailScreen({super.key, required this.openMatId});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: OMColors.bg,
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPad + 8)),

            // Back + heart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    _SquareIconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const Spacer(),
                    _SquareIconBtn(icon: Icons.favorite_border_rounded),
                  ],
                ),
              ),
            ),

            // Hero card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [OMColors.both.withValues(alpha: 0.2), OMColors.surface],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: OMColors.borderHi),
                  ),
                  child: Stack(
                    children: [
                      // Decorative glow
                      Positioned(
                        top: -20, right: -20,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              OMColors.both.withValues(alpha: 0.267),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('OPEN MAT', style: omEyebrow(color: OMColors.both)),
                          const SizedBox(height: 4),
                          Text('10th Planet Rosemead', style: omH1(size: 26)),
                          const SizedBox(height: 14),
                          Row(
                            children: const [
                              Icon(Icons.calendar_today_rounded, size: 16, color: OMColors.muted),
                              SizedBox(width: 8),
                              Text('Sun, Jun 8 · 12:00 – 2:00 PM', style: TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w500, color: OMColors.body)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const GiBadge(type: GiType.both),
                              const ExpBadge(level: ExpLevel.all),
                              _MatFeeBadge(fee: 10),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Address row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: OMColors.crimson.withValues(alpha: 0.133),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 18, color: OMColors.crimson),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('3851 Rosemead Blvd', style: TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w600, color: OMColors.text)),
                            SizedBox(height: 2),
                            Text('Rosemead, CA · 4.1 mi away', style: TextStyle(fontFamily: 'Barlow', fontSize: 12, color: OMColors.muted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: OMColors.crimson,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Go', style: omEyebrow(color: Colors.white, size: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Check In CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: PrimaryBtn(
                  label: 'Check In to This Open Mat',
                  icon: Icons.check_circle_outline_rounded,
                  full: true,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.go('/open-mat/$openMatId/checkin-success');
                  },
                ),
              ),
            ),

            // Ratings section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Mat Ratings', style: omH2(size: 18)),
                        const Spacer(),
                        const Icon(Icons.star_rounded, size: 16, color: OMColors.star),
                        const SizedBox(width: 4),
                        Text('4.7', style: omNum(size: 16)),
                        const SizedBox(width: 4),
                        const Text('· 84 reviews', style: TextStyle(fontFamily: 'Barlow', fontSize: 12, color: OMColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      borderRadius: 18,
                      child: Column(
                        children: [
                          const StarRow(label: 'Gym Quality',            value: 4.8, count: 84),
                          const Divider(height: 1, color: OMColors.borderDark),
                          const StarRow(label: 'Experience Level Match', value: 4.5, count: 84),
                          const Divider(height: 1, color: OMColors.borderDark),
                          const StarRow(label: 'Cleanliness',            value: 4.9, count: 84),
                          const Divider(height: 1, color: OMColors.borderDark),
                          const StarRow(label: 'Friendliness',           value: 4.7, count: 84),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Reviews
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text('Recent Reviews', style: omH2(size: 18)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: _ReviewCard(review: _reviews[i]),
                ),
                childCount: _reviews.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [OMColors.crimson, OMColors.both],
                  ),
                ),
                child: Center(
                  child: Text(
                    review.name[0],
                    style: const TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white, height: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.name, style: const TextStyle(fontFamily: 'Barlow', fontSize: 13, fontWeight: FontWeight.w600, color: OMColors.text)),
                    const SizedBox(height: 3),
                    BeltBadge(belt: review.belt, stripes: review.stripes, small: true),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (j) => Icon(
                      Icons.star_rounded,
                      size: 11,
                      color: j < review.rating ? OMColors.star : OMColors.faint,
                    )),
                  ),
                  const SizedBox(height: 2),
                  Text(review.when, style: const TextStyle(fontFamily: 'Barlow', fontSize: 11, color: OMColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${review.text}"',
            style: omBody(color: OMColors.body, size: 13),
          ),
        ],
      ),
    );
  }
}

class _SquareIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SquareIconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(9),
        borderRadius: 12,
        child: Icon(icon, size: 18, color: OMColors.text),
      ),
    );
  }
}

class _MatFeeBadge extends StatelessWidget {
  final int fee;
  const _MatFeeBadge({required this.fee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OMColors.teal.withValues(alpha: 0.133),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OMColors.teal.withValues(alpha: 0.267)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_money_rounded, size: 11, color: OMColors.teal),
          Text(
            '\$$fee Mat Fee',
            style: const TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.08, color: OMColors.teal, height: 1),
          ),
        ],
      ),
    );
  }
}

// Provider stub consumed by SessionAdminScreen
final openMatDetailProvider = FutureProvider.family<OpenMat, String>((ref, id) async {
  throw UnimplementedError('openMatDetailProvider not connected to API yet');
});
