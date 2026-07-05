import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/reference/ibjjf_weight_classes.dart';

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
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _weightValueController;
  String _gender = 'male';
  String _weightUnit = 'lb';
  String _divisionContext = 'nogi';
  String? _weightDivision;
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
    _cityController = TextEditingController(text: user?.city ?? '');
    _stateController = TextEditingController(text: user?.state ?? '');
    _weightValueController =
        TextEditingController(text: user?.weightValue?.toString() ?? '');
    _gender = user?.gender ?? 'male';
    _weightUnit = user?.weightUnit ?? 'lb';
    _divisionContext = user?.weightDivisionContext ?? 'nogi';
    _weightDivision = user?.weightDivision;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _weightController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _weightValueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(authStateProvider.notifier).updateProfile({
      'displayName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'beltRank': _selectedBelt,
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'gender': _gender,
      if (double.tryParse(_weightValueController.text.trim()) != null)
        'weightValue': double.parse(_weightValueController.text.trim()),
      'weightUnit': _weightUnit,
      'weightDivisionContext': _divisionContext,
      if (_weightDivision != null) 'weightDivision': _weightDivision,
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
          const SizedBox(height: StitchTokens.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
            ),
            const SizedBox(width: StitchTokens.md),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _stateController,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'State', counterText: ''),
              ),
            ),
          ]),
          const SizedBox(height: StitchTokens.md),
          Text('Gender', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Male')),
              ButtonSegment(value: 'female', label: Text('Female')),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() {
              _gender = s.first;
              _weightDivision = null; // division set differs by gender
            }),
          ),
          const SizedBox(height: StitchTokens.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _weightValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight'),
              ),
            ),
            const SizedBox(width: StitchTokens.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lb', label: Text('lb')),
                ButtonSegment(value: 'kg', label: Text('kg')),
              ],
              selected: {_weightUnit},
              onSelectionChanged: (s) => setState(() => _weightUnit = s.first),
            ),
          ]),
          const SizedBox(height: StitchTokens.md),
          Text('Division', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gi', label: Text('Gi')),
              ButtonSegment(value: 'nogi', label: Text('No-Gi')),
            ],
            selected: {_divisionContext},
            onSelectionChanged: (s) => setState(() {
              _divisionContext = s.first;
              _weightDivision = null;
            }),
          ),
          const SizedBox(height: StitchTokens.sm),
          DropdownButton<String>(
            isExpanded: true,
            value: _weightDivision,
            hint: const Text('Select division'),
            items: divisionsFor(_gender, _divisionContext)
                .map((r) => DropdownMenuItem(value: r.division, child: Text(r.label)))
                .toList(),
            onChanged: (v) => setState(() => _weightDivision = v),
          ),
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
