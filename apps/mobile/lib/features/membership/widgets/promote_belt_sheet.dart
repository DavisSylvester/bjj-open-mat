import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../data/membership_repository.dart';

const List<String> _belts = ['white', 'blue', 'purple', 'brown', 'black'];

/// Bottom sheet that lets an owner/coach promote a member's belt rank.
///
/// On Confirm: calls [membershipRepositoryProvider.promote], then invalidates
/// [rosterProvider] for [gymId] and [userPromotionsProvider] for [targetUserId],
/// then closes the sheet.
class PromoteBeltSheet extends ConsumerStatefulWidget {
  final String gymId;
  final String targetUserId;

  const PromoteBeltSheet({
    super.key,
    required this.gymId,
    required this.targetUserId,
  });

  @override
  ConsumerState<PromoteBeltSheet> createState() => _PromoteBeltSheetState();
}

class _PromoteBeltSheetState extends ConsumerState<PromoteBeltSheet> {
  String _belt = 'white';
  int _stripes = 0;
  final TextEditingController _noteController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);

    final repo = ref.read(membershipRepositoryProvider);
    try {
      await repo.promote(
        widget.gymId,
        widget.targetUserId,
        beltRank: _belt,
        beltStripes: _stripes,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      ref.invalidate(rosterProvider(widget.gymId));
      ref.invalidate(userPromotionsProvider(widget.targetUserId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save promotion: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>();
    final bg = t?.surface ?? Theme.of(context).colorScheme.surface;
    final textColor = t?.text ?? Theme.of(context).colorScheme.onSurface;
    final mutedColor = t?.muted ?? Colors.grey;
    final primaryColor = t?.primary ?? Theme.of(context).colorScheme.primary;
    final bodyStyle = t?.bodyStyle ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Promote Belt',
            style: bodyStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),

          // Belt dropdown.
          Text('Belt', style: bodyStyle.copyWith(color: mutedColor, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t?.border ?? Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _belt,
                dropdownColor: bg,
                style: bodyStyle.copyWith(color: textColor),
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: mutedColor),
                items: _belts.map((b) {
                  return DropdownMenuItem<String>(
                    value: b,
                    child: Row(
                      children: [
                        BeltIcon(rank: b, stripes: 0, size: 32),
                        const SizedBox(width: 10),
                        Text(b, style: bodyStyle.copyWith(color: textColor)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _belt = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stripes selector.
          Text('Stripes', style: bodyStyle.copyWith(color: mutedColor, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: _stripes > 0 ? () => setState(() => _stripes--) : null,
                icon: const Icon(Icons.remove),
                color: primaryColor,
                disabledColor: mutedColor.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_stripes',
                    style: bodyStyle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _stripes < 4 ? () => setState(() => _stripes++) : null,
                icon: const Icon(Icons.add),
                color: primaryColor,
                disabledColor: mutedColor.withValues(alpha: 0.3),
              ),
              // Live belt preview.
              const SizedBox(width: 8),
              BeltIcon(rank: _belt, stripes: _stripes, size: 48),
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 16),

          // Optional note.
          TextField(
            controller: _noteController,
            style: bodyStyle.copyWith(color: textColor),
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              labelStyle: bodyStyle.copyWith(color: mutedColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: t?.border ?? Colors.grey.shade300),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Confirm button.
          ElevatedButton(
            onPressed: _busy ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
