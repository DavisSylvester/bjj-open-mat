import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String checkinId;
  const ReviewScreen({super.key, required this.checkinId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.post(Endpoints.checkinReview(widget.checkinId), data: {
        'rating': _rating,
        'review': _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
      });
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Session')),
      body: Padding(
        padding: const EdgeInsets.all(StitchTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How was it?', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: StitchTokens.lg),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starNum = i + 1;
                return IconButton(
                  iconSize: 48,
                  icon: Icon(
                    starNum <= _rating ? Icons.star : Icons.star_border,
                    color: starNum <= _rating ? StitchTokens.warning : StitchTokens.textSecondary,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = starNum);
                  },
                );
              }),
            ),
            const SizedBox(height: StitchTokens.lg),

            // Review text
            Text('Review (optional)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: StitchTokens.sm),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'How was the vibe? Good rolls?'),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _rating == 0 || _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Review'),
              ),
            ),
            const SizedBox(height: StitchTokens.md),
          ],
        ),
      ),
    );
  }
}
