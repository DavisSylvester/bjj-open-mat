import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/review_repository.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  final String? checkInId;
  const ReviewScreen({super.key, this.sessionId, this.checkInId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  static const Map<String, String> _categoryKeys = {
    'Instruction Quality': 'instruction',
    'Mat Cleanliness': 'cleanliness',
    'Skill Variety': 'variety',
    'Worth Returning': 'worth_returning',
    'Overall': 'overall',
  };

  final Map<String, double> _ratings = {
    'Instruction Quality': 4.0,
    'Mat Cleanliness': 3.0,
    'Skill Variety': 5.0,
    'Worth Returning': 4.0,
    'Overall': 4.0,
  };
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  // checkInId is threaded through check-in -> checkin-success -> review as a
  // `checkInId` query param (see checkin_success_screen.dart), or supplied
  // directly via the widget constructor. If neither is present (e.g. a deep
  // link without the param) submission is blocked with an error instead of
  // guessing an id.
  String? get _resolvedCheckInId {
    if (widget.checkInId != null && widget.checkInId!.isNotEmpty) return widget.checkInId;
    try {
      final fromRoute = GoRouterState.of(context).uri.queryParameters['checkInId'];
      if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    } catch (_) {
      // No GoRouterState available in this context (e.g. shown outside routing).
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final checkInId = _resolvedCheckInId;
    if (checkInId == null) {
      setState(() => _error = "Missing check-in reference — can't submit this review.");
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final categoryRatings = <String, int>{
      for (final entry in _ratings.entries) _categoryKeys[entry.key]!: entry.value.round(),
    };
    try {
      await ref.read(reviewRepositoryProvider).submitReview(
            checkInId,
            rating: _ratings['Overall']!.round(),
            review: _reviewCtrl.text.trim(),
            categoryRatings: categoryRatings,
          );
      if (widget.sessionId != null) {
        ref.invalidate(openMatReviewsProvider(widget.sessionId!));
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Expanded(child: Text('Rate Session', style: t.h1Style.copyWith(fontSize: 20))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(LucideIcons.x, size: 20, color: t.muted),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Glass star ratings
                ..._ratings.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.cardRadius),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(e.key, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600))),
                      Row(children: List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _ratings[e.key] = i + 1.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            LucideIcons.star,
                            size: 22,
                            color: i < e.value ? t.amber : t.muted,
                          ),
                        ),
                      ))),
                    ]),
                  ),
                )),
                const SizedBox(height: 12),
                // Written review
                Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _reviewCtrl,
                    style: t.bodyStyle,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a review (optional)…',
                      hintStyle: t.miniStyle.copyWith(fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: t.miniStyle.copyWith(color: t.red)),
                ],
              ]),
            ),
          ),
          // Submit
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.red,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text('Submit Review', style: t.h2Style.copyWith(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
