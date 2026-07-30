import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../data/attendance_repository.dart';
import '../data/gym_review_link_repository.dart';
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
      await _maybeOfferGoogleReview();
      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else if (widget.sessionId != null) {
          context.go('/open-mat/${widget.sessionId}');
        } else {
          context.go('/');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    }
  }

  /// Offers the Google hand-off when the gym has a Google link, to every
  /// reviewer regardless of score. Every failure path here is silent — the review is already
  /// saved, and nothing about the hand-off is worth an error message.
  Future<void> _maybeOfferGoogleReview() async {
    final sessionId = widget.sessionId;
    if (sessionId == null) return;
    try {
      final uri = await _lookupGoogleReviewUri(sessionId).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (!shouldOfferGoogleReview(writeAReviewUri: uri)) return;
      await _offerGoogleReview(uri!);
    } catch (_) {
      // No hand-off (including a timed-out lookup). The in-app review is saved either way.
    }
  }

  Future<String?> _lookupGoogleReviewUri(String sessionId) async {
    final session = await ref.read(sessionByIdProvider(sessionId).future);
    if (!mounted) return null;
    return ref.read(gymReviewLinkProvider(session.gymId).future);
  }

  Future<void> _offerGoogleReview(String uri) async {
    final t = Theme.of(context).extension<AppTokens>()!;
    final share = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Thanks for the review', style: t.h2Style),
        content: Text(
          'Want to share it on Google too? It opens Google Maps so you can post it there.',
          style: t.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Share on Google'),
          ),
        ],
      ),
    );
    if (share != true) return;
    await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
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
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(widget.sessionId != null ? '/open-mat/${widget.sessionId}' : '/'),
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
