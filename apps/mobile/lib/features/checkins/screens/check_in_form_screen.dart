import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_service.dart';
import '../data/attendance_repository.dart';
import '../data/check_in_request.dart';

class CheckInFormScreen extends ConsumerStatefulWidget {
  final String openMatId;
  const CheckInFormScreen({super.key, required this.openMatId});

  @override
  ConsumerState<CheckInFormScreen> createState() => _CheckInFormScreenState();
}

class _CheckInFormScreenState extends ConsumerState<CheckInFormScreen> {
  static const List<String> _beltValues = ['white', 'blue', 'purple', 'brown', 'black'];

  CapturedLocation? _loc;
  bool _locResolved = false;
  bool _saving = false;
  String? _error;
  int _intensity = 3;
  String? _belt;
  final _noteCtrl = TextEditingController();
  final _roundsCtrl = TextEditingController();
  final _partnersCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profileBelt = ref.read(authStateProvider).user?.beltRank;
    if (profileBelt != null && _beltValues.contains(profileBelt)) {
      _belt = profileBelt;
    }
    Future.microtask(() async {
      final loc = await ref.read(locationServiceProvider).current();
      if (mounted) {
        setState(() {
          _loc = loc;
          _locResolved = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _roundsCtrl.dispose();
    _partnersCtrl.dispose();
    super.dispose();
  }

  String _todayIso() => DateTime.now().toIso8601String().split('T').first;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await ref.read(attendanceRepositoryProvider).checkIn(
            widget.openMatId,
            CreateCheckInRequest(
              sessionDate: _todayIso(),
              latitude: _loc?.latitude,
              longitude: _loc?.longitude,
              gpsAccuracyM: _loc?.accuracyM,
              note: _noteCtrl.text.trim(),
              beltRank: _belt,
              rounds: int.tryParse(_roundsCtrl.text.trim()),
              intensity: _intensity,
              partners: int.tryParse(_partnersCtrl.text.trim()),
            ),
          );
      if (mounted) {
        context.go('/open-mat/${widget.openMatId}/checkin-success?loc=${res.locationStatus}');
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
    final matAsync = ref.watch(sessionByIdProvider(widget.openMatId));
    final gymName = matAsync.asData?.value.gymName ?? matAsync.asData?.value.title ?? 'Open Mat';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Check In'),
        backgroundColor: t.bg,
        foregroundColor: t.text,
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Text(gymName, style: t.h1Style.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
              _loc != null ? Icons.location_on : Icons.location_off,
              size: 16,
              color: _loc != null ? t.green : t.muted,
            ),
            const SizedBox(width: 6),
            Text(
              !_locResolved
                  ? 'Getting your location…'
                  : _loc != null
                      ? 'Location captured'
                      : 'Location off — checking in without it',
              style: t.miniStyle,
            ),
          ]),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('NOTES', style: t.labelStyle),
          ),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: _dec(t, 'How did it go?'),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('ROUNDS', style: t.labelStyle),
                  ),
                  TextField(
                    controller: _roundsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec(t, 'e.g. 5'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('PARTNERS', style: t.labelStyle),
                  ),
                  TextField(
                    controller: _partnersCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec(t, 'e.g. 3'),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('INTENSITY', style: t.labelStyle),
          ),
          Row(
            children: List.generate(5, (i) {
              final v = i + 1;
              final on = _intensity == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _intensity = v),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: on ? t.primary.withValues(alpha: 0.14) : t.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: on ? t.primary : t.border),
                    ),
                    child: Text(
                      '$v',
                      textAlign: TextAlign.center,
                      style: t.bodyStyle.copyWith(
                        color: on ? t.primary : t.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('BELT', style: t.labelStyle),
          ),
          DropdownButton<String>(
            value: _belt,
            hint: Text('Select belt', style: t.bodyStyle.copyWith(color: t.muted)),
            isExpanded: true,
            dropdownColor: t.surface,
            style: t.bodyStyle.copyWith(color: t.text),
            underline: Container(height: 1, color: t.border),
            onChanged: (v) => setState(() => _belt = v),
            items: _beltValues.map((b) {
              return DropdownMenuItem<String>(
                value: b,
                child: Text(
                  '${b[0].toUpperCase()}${b.substring(1)}',
                  style: t.bodyStyle.copyWith(color: t.text),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: t.miniStyle.copyWith(color: t.red)),
          ],
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _saving ? null : _submit,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Check In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _dec(AppTokens t, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: t.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.border),
        ),
      );
}
