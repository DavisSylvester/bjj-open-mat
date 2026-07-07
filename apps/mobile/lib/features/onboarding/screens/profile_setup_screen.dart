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
  DateTime? _birthday;
  bool _social = false;
  bool _isSaving = false;

  static const _beltRanks = ['white', 'blue', 'purple', 'brown', 'black'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    // Social logins get their display name from the provider — pre-fill it and
    // disable editing. Only the belt/birthday are collected here for them.
    _social = user?.isSocial ?? false;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? get _birthdayIso => _birthday == null
      ? null
      : '${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    // Social users can't edit the display name (it's provider-owned), so don't
    // block them on it; email/password users must supply one.
    if (!_social && _nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    await ref.read(authStateProvider.notifier).updateProfile({
      if (!_social) 'displayName': _nameController.text.trim(),
      'beltRank': _selectedBelt,
      if (_birthdayIso != null) 'birthday': _birthdayIso,
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
                enabled: !_social,
                decoration: InputDecoration(
                  hintText: 'Your name on the mat',
                  helperText: _social ? 'From your sign-in account' : null,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: StitchTokens.lg),

              Text('Birthday', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StitchTokens.sm),
              InkWell(
                onTap: _pickBirthday,
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _birthdayIso ?? 'Select your birthday',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
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
