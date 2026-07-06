import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/reference/ibjjf_weight_classes.dart';
import '../../gyms/data/gym_repository.dart';
import '../widgets/home_gym_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  String _selectedBelt = 'white';
  int _selectedStripes = 0;
  DateTime? _birthday;
  String? _homeGymId;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _weightValueController;
  String _gender = 'male';
  String _weightUnit = 'lb';
  String _divisionContext = 'nogi';
  String? _weightDivision;
  bool _isSaving = false;
  bool _social = false;

  static const _beltRanks = ['white', 'blue', 'purple', 'brown', 'black'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    _social = ref.read(authStateProvider).user?.isSocial ?? false;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _selectedBelt = user?.beltRank ?? 'white';
    _selectedStripes = user?.beltStripes ?? 0;
    _birthday = user?.birthday != null ? DateTime.tryParse(user!.birthday!) : null;
    _homeGymId = user?.homeGymId;
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
    _cityController.dispose();
    _stateController.dispose();
    _weightValueController.dispose();
    super.dispose();
  }

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

  String? get _birthdayIso => _birthday == null
      ? null
      : '${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}';

  Future<void> _pickHomeGym() async {
    final gym = await showHomeGymPicker(context);
    if (gym != null) setState(() => _homeGymId = gym.id);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final social = ref.read(authStateProvider).user?.isSocial ?? false;
    final updates = <String, dynamic>{
      'beltRank': _selectedBelt,
      'beltStripes': _selectedStripes,
      if (_birthdayIso != null) 'birthday': _birthdayIso,
      if (_homeGymId != null) 'homeGymId': _homeGymId,
      if (!social) 'displayName': _nameController.text.trim(),
      if (!social) 'bio': _bioController.text.trim(),
      if (!social) 'city': _cityController.text.trim(),
      if (!social) 'state': _stateController.text.trim(),
      if (!social) 'gender': _gender,
      if (!social) 'weightUnit': _weightUnit,
      if (!social) 'weightDivisionContext': _divisionContext,
      if (!social && _weightDivision != null) 'weightDivision': _weightDivision,
      if (!social && double.tryParse(_weightValueController.text.trim()) != null)
        'weightValue': double.tryParse(_weightValueController.text.trim()),
    };
    await ref.read(authStateProvider.notifier).updateProfile(updates);
    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = _social;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), actions: [
        TextButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(StitchTokens.lg),
        children: [
          if (!social) ...[
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display Name')),
            const SizedBox(height: StitchTokens.md),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
            const SizedBox(height: StitchTokens.md),
          ],
          Text('Birthday', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          InkWell(
            onTap: _pickBirthday,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: StitchTokens.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_birthdayIso ?? 'Select birthday'),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: StitchTokens.md),
          Text('Home Gym', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          InkWell(
            onTap: _pickHomeGym,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: StitchTokens.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _HomeGymLabel(homeGymId: _homeGymId)),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
          if (!social) ...[
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
          ],
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
          const SizedBox(height: StitchTokens.md),
          Text('Stripes', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          Wrap(
            spacing: StitchTokens.sm,
            children: List.generate(5, (stripes) => ChoiceChip(
              label: Text('$stripes'),
              selected: stripes == _selectedStripes,
              onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _selectedStripes = stripes); },
            )),
          ),
        ],
      ),
    );
  }
}

class _HomeGymLabel extends ConsumerWidget {
  final String? homeGymId;
  const _HomeGymLabel({required this.homeGymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = homeGymId;
    if (id == null) return const Text('Select home gym');
    final gymAsync = ref.watch(gymByIdProvider(id));
    return gymAsync.when(
      data: (gym) => Text(gym.name),
      loading: () => const Text('Loading...'),
      error: (_, _) => const Text('Select home gym'),
    );
  }
}
