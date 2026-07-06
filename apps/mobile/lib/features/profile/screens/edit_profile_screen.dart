import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../core/reference/ibjjf_weight_classes.dart';
import '../../../shared/widgets/glass_form.dart';
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
    final t = Theme.of(context).extension<AppTokens>()!;
    final social = _social;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header — big bold in-body title, back affordance, indigo Save action.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                  child: Icon(LucideIcons.arrowLeft, size: 18, color: t.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Edit Profile', style: t.h1Style)),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
                        )
                      : Text('Save', style: t.h2Style.copyWith(color: t.primary, fontSize: 16)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (!social)
                  _sectionCard(t, 'Identity', [
                    _fieldLabel(t, 'Display Name'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: t.bodyStyle,
                      decoration: glassInput(t, 'Your name'),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel(t, 'Bio'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bioController,
                      style: t.bodyStyle,
                      maxLines: 3,
                      decoration: glassInput(t, 'Tell other grapplers about yourself'),
                    ),
                  ]),
                _sectionCard(t, 'Details', [
                  _fieldLabel(t, 'Birthday'),
                  const SizedBox(height: 6),
                  _pickerRow(
                    t,
                    icon: LucideIcons.cake,
                    label: _birthdayIso ?? 'Select birthday',
                    onTap: _pickBirthday,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel(t, 'Home Gym'),
                  const SizedBox(height: 6),
                  _pickerRow(
                    t,
                    icon: LucideIcons.mapPin,
                    onTap: _pickHomeGym,
                    child: _HomeGymLabel(homeGymId: _homeGymId, style: t.bodyStyle),
                  ),
                  if (!social) ...[
                    const SizedBox(height: 16),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 3,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _fieldLabel(t, 'City'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _cityController,
                            style: t.bodyStyle,
                            decoration: glassInput(t, 'City'),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _fieldLabel(t, 'State'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _stateController,
                            maxLength: 2,
                            textCapitalization: TextCapitalization.characters,
                            style: t.bodyStyle,
                            decoration: glassInput(t, 'CA').copyWith(counterText: ''),
                          ),
                        ]),
                      ),
                    ]),
                  ],
                ]),
                if (!social)
                  _sectionCard(t, 'Training', [
                    _fieldLabel(t, 'Gender'),
                    const SizedBox(height: 8),
                    GlassSegmented(
                      t: t,
                      value: _gender,
                      options: const [
                        (value: 'male', label: 'Male', icon: null),
                        (value: 'female', label: 'Female', icon: null),
                      ],
                      onChanged: (v) => setState(() {
                        _gender = v;
                        _weightDivision = null; // division set differs by gender
                      }),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel(t, 'Weight'),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _weightValueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: t.bodyStyle,
                          decoration: glassInput(t, 'Weight'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: GlassSegmented(
                          t: t,
                          value: _weightUnit,
                          options: const [
                            (value: 'lb', label: 'lb', icon: null),
                            (value: 'kg', label: 'kg', icon: null),
                          ],
                          onChanged: (v) => setState(() => _weightUnit = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _fieldLabel(t, 'Division'),
                    const SizedBox(height: 8),
                    GlassSegmented(
                      t: t,
                      value: _divisionContext,
                      options: const [
                        (value: 'gi', label: 'Gi', icon: LucideIcons.shirt),
                        (value: 'nogi', label: 'No-Gi', icon: LucideIcons.swords),
                      ],
                      onChanged: (v) => setState(() {
                        _divisionContext = v;
                        _weightDivision = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel(t, 'Weight Division'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _weightDivision,
                      decoration: glassInput(t, 'Select division'),
                      icon: Icon(LucideIcons.chevronDown, size: 18, color: t.muted),
                      style: t.bodyStyle.copyWith(color: t.text),
                      items: divisionsFor(_gender, _divisionContext)
                          .map((r) => DropdownMenuItem(value: r.division, child: Text(r.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _weightDivision = v),
                    ),
                  ]),
                _sectionCard(t, 'Belt', [
                  _fieldLabel(t, 'Belt Rank'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _beltRanks.map((belt) => ChoiceChip(
                      label: Text(belt[0].toUpperCase() + belt.substring(1)),
                      selected: belt == _selectedBelt,
                      selectedColor: BeltColors.fromRank(belt),
                      labelStyle: TextStyle(color: belt == _selectedBelt ? Colors.white : null),
                      onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _selectedBelt = belt); },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel(t, 'Stripes'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(5, (stripes) => ChoiceChip(
                      label: Text('$stripes'),
                      selected: stripes == _selectedStripes,
                      selectedColor: t.primary,
                      labelStyle: TextStyle(color: stripes == _selectedStripes ? Colors.white : t.body),
                      onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _selectedStripes = stripes); },
                    )),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fieldLabel(AppTokens t, String text) => glassSectionLabel(t, text);

  Widget _sectionCard(AppTokens t, String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: glassSectionLabel(t, label),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(t.cardRadius),
              border: Border.all(color: t.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _pickerRow(
    AppTokens t, {
    required IconData icon,
    required VoidCallback onTap,
    String? label,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: t.surfaceHi, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, size: 18, color: t.muted),
          const SizedBox(width: 10),
          Expanded(child: child ?? Text(label ?? '', style: t.bodyStyle)),
          Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
        ]),
      ),
    );
  }
}

class _HomeGymLabel extends ConsumerWidget {
  final String? homeGymId;
  final TextStyle style;
  const _HomeGymLabel({required this.homeGymId, required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = homeGymId;
    if (id == null) return Text('Select home gym', style: style);
    final gymAsync = ref.watch(gymByIdProvider(id));
    return gymAsync.when(
      data: (gym) => Text(gym.name, style: style),
      loading: () => Text('Loading...', style: style),
      error: (_, _) => Text('Select home gym', style: style),
    );
  }
}
