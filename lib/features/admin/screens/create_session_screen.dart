import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/om_widgets.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  GiType _selectedGi = GiType.both;
  ExpLevel _selectedExp = ExpLevel.all;
  bool _freeMat = true;

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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
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
                  Text('POST SESSION', style: omEyebrow()),
                  const Spacer(),
                  const SizedBox(width: 38),
                ],
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Text('New Open Mat', style: omH1(size: 28)),
            ),

            // Scrollable form body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gym selector
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 18,
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [OMColors.crimson, OMColors.both],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('A', style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white, height: 1)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('POSTING AS', style: omEyebrow(size: 9)),
                                const SizedBox(height: 1),
                                const Text('Atos HQ — San Diego', style: TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w600, color: OMColors.text)),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: OMColors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Warning banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: OMColors.noGi.withValues(alpha: 0.078),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OMColors.noGi.withValues(alpha: 0.333)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_rounded, size: 16, color: OMColors.noGi),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(text: '1 of 2 sessions', style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w700, fontSize: 12, color: OMColors.noGi)),
                                  TextSpan(text: ' already posted for this date.', style: TextStyle(fontFamily: 'Barlow', fontSize: 12, color: OMColors.body)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date + time
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DATE', style: omEyebrow(size: 9)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 13, color: OMColors.crimson),
                                    const SizedBox(width: 6),
                                    Text('Sat, Jun 7', style: omNum(size: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TIME', style: omEyebrow(size: 9)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 13, color: OMColors.crimson),
                                    const SizedBox(width: 6),
                                    Text('10–12 PM', style: omNum(size: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Gi type segmented
                    Text('GI TYPE', style: omEyebrow(size: 10)),
                    const SizedBox(height: 8),
                    Row(
                      children: GiType.values.map((gi) {
                        final active = gi == _selectedGi;
                        final color = GiBadge.colorFor(gi);
                        final label = GiBadge.labelFor(gi);
                        final icon = GiBadge.iconFor(gi);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedGi = gi),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: EdgeInsets.only(right: gi != GiType.both ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: active ? color.withValues(alpha: 0.133) : OMColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: active ? color : OMColors.borderDark,
                                  width: active ? 1.5 : 1,
                                ),
                                boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.082), blurRadius: 0, spreadRadius: 4)] : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 22, color: active ? color : OMColors.muted),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'BarlowCondensed',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.1,
                                      color: active ? color : OMColors.body,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Experience level
                    Text('EXPERIENCE LEVEL', style: omEyebrow(size: 10)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ExpLevel.values.map((exp) {
                        final active = exp == _selectedExp;
                        final label = ExpBadge.labelFor(exp);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedExp = exp),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? OMColors.crimson.withValues(alpha: 0.133) : OMColors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: active ? OMColors.crimson : OMColors.borderDark),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.1,
                                color: active ? OMColors.crimson : OMColors.body,
                                height: 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Mat fee toggle
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 18,
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: OMColors.teal.withValues(alpha: 0.133),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, size: 18, color: OMColors.teal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Free Mat', style: TextStyle(fontFamily: 'Barlow', fontSize: 14, fontWeight: FontWeight.w600, color: OMColors.text)),
                                SizedBox(height: 1),
                                Text('Drop-in welcome, no charge', style: TextStyle(fontFamily: 'Barlow', fontSize: 11, color: OMColors.muted)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _freeMat = !_freeMat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 50, height: 28,
                              decoration: BoxDecoration(
                                color: _freeMat ? OMColors.teal : OMColors.faint,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 150),
                                alignment: _freeMat ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  width: 24, height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    Text('NOTES (OPTIONAL)', style: omEyebrow(size: 10)),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 14,
                      child: const Text(
                        'Visitors welcome. Bring both gi and rashguard.',
                        style: TextStyle(fontFamily: 'Barlow', fontSize: 13, color: OMColors.body),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // CTA
            Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 18 + bottomPad),
              child: PrimaryBtn(
                label: 'Post Session',
                icon: Icons.add_circle_outline_rounded,
                full: true,
                onTap: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
