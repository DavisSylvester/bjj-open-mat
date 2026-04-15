import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _weightController;
  String _selectedBelt = 'white';
  bool _isSaving = false;

  static const _beltRanks = ['white', 'blue', 'purple', 'brown', 'black'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _weightController = TextEditingController(text: user?.weight ?? '');
    _selectedBelt = user?.beltRank ?? 'white';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(authStateProvider.notifier).updateProfile({
      'displayName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'weight': _weightController.text.trim(),
      'beltRank': _selectedBelt,
    });
    HapticFeedback.heavyImpact();
    if (mounted) context.pop();
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), actions: [
        TextButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(StitchTokens.lg),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display Name')),
          const SizedBox(height: StitchTokens.md),
          TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
          const SizedBox(height: StitchTokens.md),
          TextField(controller: _weightController, decoration: const InputDecoration(labelText: 'Weight'), keyboardType: TextInputType.number),
          const SizedBox(height: StitchTokens.lg),
          Text('Belt Rank', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          Wrap(
            spacing: StitchTokens.sm,
            children: _beltRanks.map((belt) => ChoiceChip(
              label: Text(belt[0].toUpperCase() + belt.substring(1)),
              selected: belt == _selectedBelt,
              selectedColor: BeltColors.fromRank(belt),
              labelStyle: TextStyle(color: belt == _selectedBelt ? Colors.white : null),
              onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _selectedBelt = belt); },
            )).toList(),
          ),
        ],
      ),
    );
  }
}
