import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

class AddGymScreen extends ConsumerStatefulWidget {
  const AddGymScreen({super.key});

  @override
  ConsumerState<AddGymScreen> createState() => _AddGymScreenState();
}

class _AddGymScreenState extends ConsumerState<AddGymScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<String> _amenities = [];
  bool _isSaving = false;

  static const _amenityOptions = ['showers', 'parking', 'water', 'changing_rooms', 'wifi', 'pro_shop'];

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _cityCtrl, _stateCtrl, _countryCtrl, _postalCtrl, _phoneCtrl, _websiteCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(Endpoints.gyms, data: {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'postalCode': _postalCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'amenities': _amenities,
      });
      HapticFeedback.heavyImpact();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gym registered!'))); context.go('/owner/gyms'); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Gym')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(StitchTokens.lg),
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Gym Name *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: StitchTokens.md),
            TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Street Address *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: StitchTokens.md),
            Row(children: [
              Expanded(child: TextFormField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null)),
              const SizedBox(width: StitchTokens.sm),
              Expanded(child: TextFormField(controller: _stateCtrl, decoration: const InputDecoration(labelText: 'State *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null)),
            ]),
            const SizedBox(height: StitchTokens.md),
            Row(children: [
              Expanded(child: TextFormField(controller: _countryCtrl, decoration: const InputDecoration(labelText: 'Country *'), validator: (v) => v?.trim().isEmpty == true ? 'Required' : null)),
              const SizedBox(width: StitchTokens.sm),
              Expanded(child: TextFormField(controller: _postalCtrl, decoration: const InputDecoration(labelText: 'Postal Code'))),
            ]),
            const SizedBox(height: StitchTokens.md),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: StitchTokens.md),
            TextFormField(controller: _websiteCtrl, decoration: const InputDecoration(labelText: 'Website'), keyboardType: TextInputType.url),
            const SizedBox(height: StitchTokens.md),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: StitchTokens.lg),
            Text('Amenities', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: StitchTokens.sm),
            Wrap(spacing: 6, children: _amenityOptions.map((a) => FilterChip(
              label: Text(a.replaceAll('_', ' ')),
              selected: _amenities.contains(a),
              onSelected: (sel) { setState(() { sel ? _amenities.add(a) : _amenities.remove(a); }); HapticFeedback.selectionClick(); },
            )).toList()),
            const SizedBox(height: StitchTokens.xl),
            SizedBox(height: 52, child: ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Gym'))),
          ],
        ),
      ),
    );
  }
}
