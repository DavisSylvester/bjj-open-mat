import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/data/api_exception.dart';
import '../../../core/design/tokens.dart';
import '../../open_mats/data/session_repository.dart';
import '../../open_mats/data/session_requests.dart';
import '../../open_mats/models/open_mat.dart';
import 'session_mgmt_screen.dart';

final sessionDetailProvider = FutureProvider.family<OpenMat, String>((ref, id) async {
  return ref.read(sessionRepositoryProvider).getById(id);
});

class SessionAdminScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionAdminScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionAdminScreen> createState() => _SessionAdminScreenState();
}

class _SessionAdminScreenState extends ConsumerState<SessionAdminScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _cancelSession() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sessionRepositoryProvider).update(
            widget.sessionId,
            const UpdateSessionRequest({'isCancelled': true}),
          );
      ref.invalidate(sessionDetailProvider(widget.sessionId));
      ref.invalidate(mySessionsProvider);
      if (mounted) setState(() => _saving = false);
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
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/owner/sessions'),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Session Admin', style: t.h1Style.copyWith(fontSize: 20))),
              GestureDetector(
                onTap: () => context.go('/owner/sessions/${widget.sessionId}/attendance'),
                child: Icon(LucideIcons.users, size: 18, color: t.muted),
              ),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: sessionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), textAlign: TextAlign.center, style: t.bodyStyle.copyWith(color: t.red)),
                ),
              ),
              data: (session) => ListView(
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
                      Text(session.title, style: t.h2Style.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${session.dayName} ${session.startTime}–${session.endTime} • ${session.skillBadge}',
                          style: t.miniStyle.copyWith(color: t.muted)),
                      if (session.isCancelled) ...[
                        const SizedBox(height: 8),
                        Text('Cancelled', style: t.miniStyle.copyWith(color: t.red, fontWeight: FontWeight.w800)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go('/owner/sessions/${widget.sessionId}/attendance'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(t.cardRadius),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(children: [
                        Icon(LucideIcons.users, size: 20, color: t.muted),
                        const SizedBox(width: 12),
                        Text('Attendance', style: t.bodyStyle),
                        const Spacer(),
                        Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                      ]),
                    ),
                  ),
                  if (!session.isCancelled) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _saving ? null : _cancelSession,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(t.cardRadius),
                          border: Border.all(color: t.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          if (_saving)
                            SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(t.red)),
                            )
                          else
                            Icon(LucideIcons.ban, size: 20, color: t.red),
                          const SizedBox(width: 12),
                          Text(_saving ? 'Cancelling…' : 'Cancel Session',
                              style: t.bodyStyle.copyWith(color: t.red, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: t.miniStyle.copyWith(color: t.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
