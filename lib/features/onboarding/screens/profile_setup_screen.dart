import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String _selectedBelt = 'white';
  bool _isSaving = false;

  static const _beltRanks = ['white', 'blue', 'purple', 'brown', 'black'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    await ref.read(authStateProvider.notifier).updateProfile({
      'displayName': _nameController.text.trim(),
      'beltRank': _selectedBelt,
    });

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final user = ref.read(authStateProvider).user;
    context.go(user?.isGymOwner == true ? '/owner/dashboard' : '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StitchTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Display Name', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StitchTokens.sm),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Your name on the mat'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: StitchTokens.lg),

              Text('Belt Rank', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StitchTokens.sm),
              Wrap(
                spacing: StitchTokens.sm,
                children: _beltRanks.map((belt) {
                  final isSelected = belt == _selectedBelt;
                  return ChoiceChip(
                    label: Text(belt[0].toUpperCase() + belt.substring(1)),
                    selected: isSelected,
                    selectedColor: BeltColors.fromRank(belt),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBelt = belt);
                    },
                  );
                }).toList(),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Get Started'),
                ),
              ),
              const SizedBox(height: StitchTokens.md),
            ],
          ),
        ),
      ),
    );
  }
}
