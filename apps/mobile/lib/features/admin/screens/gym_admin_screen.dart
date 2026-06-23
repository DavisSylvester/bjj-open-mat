import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/data/gym_requests.dart';
import '../../gyms/models/gym.dart';
import 'my_gyms_screen.dart';

final gymDetailProvider = FutureProvider.family<Gym, String>((ref, id) async {
  return ref.read(gymRepositoryProvider).getById(id);
});

class GymAdminScreen extends ConsumerStatefulWidget {
  final String gymId;
  const GymAdminScreen({super.key, required this.gymId});

  @override
  ConsumerState<GymAdminScreen> createState() => _GymAdminScreenState();
}

class _GymAdminScreenState extends ConsumerState<GymAdminScreen> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  String? _hydratedFor;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Gym gym) {
    if (_hydratedFor == gym.id) return;
    _hydratedFor = gym.id;
    _nameCtrl.text = gym.name;
    _addrCtrl.text = gym.address;
  }

  Future<void> _save(Gym gym) async {
    if (_saving) return;
    final changed = <String, dynamic>{};
    final name = _nameCtrl.text.trim();
    final address = _addrCtrl.text.trim();
    if (name.isNotEmpty && name != gym.name) changed['name'] = name;
    if (address.isNotEmpty && address != gym.address) changed['address'] = address;
    if (changed.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(gymRepositoryProvider).update(widget.gymId, UpdateGymRequest(changed));
      ref.invalidate(gymDetailProvider(widget.gymId));
      ref.invalidate(myGymsProvider);
      if (mounted) {
        setState(() {
          _saving = false;
          _hydratedFor = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final gymAsync = ref.watch(gymDetailProvider(widget.gymId));
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/owner/gyms'),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Gym Admin', style: t.h1Style.copyWith(fontSize: 20))),
              GestureDetector(
                onTap: () => context.go('/owner/gyms/add'),
                child: Icon(LucideIcons.pencil, size: 18, color: t.muted),
              ),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: gymAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), textAlign: TextAlign.center, style: t.bodyStyle.copyWith(color: t.red)),
                ),
              ),
              data: (gym) {
                _hydrate(gym);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(t.cardRadius),
                        border: Border.all(color: t.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('NAME', style: t.labelStyle),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          style: t.bodyStyle,
                          decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        ),
                        const SizedBox(height: 12),
                        Text('ADDRESS', style: t.labelStyle),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _addrCtrl,
                          style: t.bodyStyle,
                          decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _saving ? null : () => _save(gym),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _saving ? t.border : t.gi,
                          borderRadius: BorderRadius.circular(t.cardRadius + 2),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (_saving)
                            const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          else
                            const Icon(LucideIcons.check, size: 18, color: Colors.white),
                          const SizedBox(width: 9),
                          Text(_saving ? 'Saving…' : 'Save Changes', style: t.h2Style.copyWith(color: Colors.white, fontSize: 16)),
                        ]),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: t.miniStyle.copyWith(color: t.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => context.go('/owner/sessions/create'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(t.cardRadius),
                          border: Border.all(color: t.border),
                        ),
                        child: Row(children: [
                          Icon(LucideIcons.calendar, size: 20, color: t.muted),
                          const SizedBox(width: 12),
                          Text('Manage Sessions', style: t.bodyStyle),
                          const Spacer(),
                          Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
