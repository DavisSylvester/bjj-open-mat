import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../gyms/data/gym_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/forum_repository.dart';
import '../models/forum_answer.dart';
import '../models/forum_question.dart';
import '../widgets/forum_category_chip.dart';

/// Detail screen for a single forum question.
///
/// Displays the question header (title, body, category, author info),
/// the list of answers (accepted-first as returned by API), and an
/// answer composer when the question is not locked.
///
/// The "Accept" control on each non-accepted answer is visible when the
/// current user is the question author OR a manager (owner/coach/admin).
///
/// Managers (owner/coach/admin) additionally see Pin/Unpin, Lock/Unlock, and
/// Delete in an AppBar overflow menu.  Answer authors see Edit/Delete on their
/// own answers; managers can delete any answer.
class ForumQuestionScreen extends ConsumerStatefulWidget {
  final String questionId;
  final String gymId;

  const ForumQuestionScreen({
    super.key,
    required this.questionId,
    required this.gymId,
  });

  @override
  ConsumerState<ForumQuestionScreen> createState() => _ForumQuestionScreenState();
}

class _ForumQuestionScreenState extends ConsumerState<ForumQuestionScreen> {
  final TextEditingController _bodyCtrl = TextEditingController();
  bool _posting = false;
  bool _moderating = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ── Manager gate (same pattern as ClassOccurrenceScreen) ──────────────────

  bool _deriveCanManage(WidgetRef ref) {
    final myId = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(authStateProvider).user?.role == 'admin';
    final gymOwnerId = ref
        .watch(gymByIdProvider(widget.gymId))
        .maybeWhen(data: (g) => g.ownerId, orElse: () => null);
    final isOwner = gymOwnerId != null && gymOwnerId == myId;
    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final myGymRole = rosterAsync.maybeWhen(
      data: (members) => myId != null
          ? members.where((m) => m.userId == myId).firstOrNull?.gymRole
          : null,
      orElse: () => null,
    );
    return isAdmin || isOwner || myGymRole == 'owner' || myGymRole == 'coach';
  }

  // ── Post answer ───────────────────────────────────────────────────────────

  Future<void> _postAnswer() async {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) return;
    if (_posting) return;
    setState(() => _posting = true);
    try {
      await ref.read(forumRepositoryProvider).createAnswer(widget.questionId, text);
      _bodyCtrl.clear();
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't post answer: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // ── Accept answer ─────────────────────────────────────────────────────────

  Future<void> _acceptAnswer(String answerId) async {
    try {
      await ref.read(forumRepositoryProvider).accept(widget.questionId, answerId);
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't accept answer: $e")),
        );
      }
    }
  }

  // ── Moderation: pin/lock/delete question ──────────────────────────────────

  Future<void> _togglePin(ForumQuestion question) async {
    if (_moderating) return;
    setState(() => _moderating = true);
    try {
      await ref
          .read(forumRepositoryProvider)
          .updateQuestion(widget.questionId, {'pinned': !question.pinned});
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
      ref.invalidate(
        forumQuestionsProvider((gymId: widget.gymId, category: null)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't update pin: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _moderating = false);
    }
  }

  Future<void> _toggleLock(ForumQuestion question) async {
    if (_moderating) return;
    setState(() => _moderating = true);
    try {
      await ref
          .read(forumRepositoryProvider)
          .updateQuestion(widget.questionId, {'locked': !question.locked});
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
      ref.invalidate(
        forumQuestionsProvider((gymId: widget.gymId, category: null)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't update lock: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _moderating = false);
    }
  }

  Future<void> _deleteQuestion() async {
    if (_moderating) return;
    setState(() => _moderating = true);
    try {
      await ref.read(forumRepositoryProvider).deleteQuestion(widget.questionId);
      ref.invalidate(
        forumQuestionsProvider((gymId: widget.gymId, category: null)),
      );
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't delete question: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _moderating = false);
    }
  }

  // ── Answer actions: delete / edit ─────────────────────────────────────────

  Future<void> _deleteAnswer(String answerId) async {
    try {
      await ref.read(forumRepositoryProvider).deleteAnswer(answerId);
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't delete answer: $e")),
        );
      }
    }
  }

  Future<void> _editAnswer(String answerId, String currentBody) async {
    final ctrl = TextEditingController(text: currentBody);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Answer'),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Update your answer…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await ref.read(forumRepositoryProvider).updateAnswer(answerId, result);
      ref.invalidate(forumQuestionDetailProvider(widget.questionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't update answer: $e")),
        );
      }
    }
  }

  // ── Confirm delete dialog ─────────────────────────────────────────────────

  Future<bool> _confirmDelete(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final detailAsync = ref.watch(forumQuestionDetailProvider(widget.questionId));
    final myId = ref.watch(currentUserIdProvider);
    final canManage = _deriveCanManage(ref);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/'),
          child: Icon(Icons.arrow_back, color: t.text),
        ),
        title: Text('Question', style: t.h2Style),
        actions: detailAsync.maybeWhen(
          data: (detail) {
            final question = detail.question;
            final isAuthor =
                myId != null && myId == question.authorId;
            // Show menu if manager OR if author (author can delete their own)
            if (!canManage && !isAuthor) return null;
            return [
              PopupMenuButton<_QuestionAction>(
                icon: const Icon(Icons.more_vert),
                enabled: !_moderating,
                onSelected: (action) async {
                  switch (action) {
                    case _QuestionAction.pin:
                      await _togglePin(question);
                    case _QuestionAction.lock:
                      await _toggleLock(question);
                    case _QuestionAction.delete:
                      final ok = await _confirmDelete(
                        'Delete this question and all its answers?',
                      );
                      if (ok) await _deleteQuestion();
                  }
                },
                itemBuilder: (_) => [
                  if (canManage) ...[
                    PopupMenuItem(
                      value: _QuestionAction.pin,
                      child: Text(question.pinned ? 'Unpin' : 'Pin'),
                    ),
                    PopupMenuItem(
                      value: _QuestionAction.lock,
                      child: Text(question.locked ? 'Unlock' : 'Lock'),
                    ),
                  ],
                  const PopupMenuItem(
                    value: _QuestionAction.delete,
                    child: Text('Delete Question'),
                  ),
                ],
              ),
            ];
          },
          orElse: () => null,
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            "Couldn't load question",
            style: t.bodyStyle.copyWith(color: t.muted),
          ),
        ),
        data: (detail) {
          final question = detail.question;
          final answers = detail.answers;
          final isAuthor = myId != null && myId == question.authorId;
          final canAccept = isAuthor || canManage;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Question header ───────────────────────────────────────
                    _QuestionHeader(question: question, t: t),
                    const SizedBox(height: 20),

                    // ── Answers section ───────────────────────────────────────
                    if (answers.isNotEmpty) ...[
                      Text(
                        '${answers.length} ${answers.length == 1 ? "Answer" : "Answers"}',
                        style: t.labelStyle.copyWith(color: t.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      for (final answer in answers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AnswerCard(
                            answer: answer,
                            canAccept: canAccept && !answer.accepted,
                            canEdit: myId != null && myId == answer.authorId,
                            canDelete: canManage ||
                                (myId != null && myId == answer.authorId),
                            onAccept: () => _acceptAnswer(answer.id),
                            onEdit: () => _editAnswer(answer.id, answer.body),
                            onDelete: () async {
                              final ok = await _confirmDelete(
                                'Delete this answer?',
                              );
                              if (ok) await _deleteAnswer(answer.id);
                            },
                            t: t,
                          ),
                        ),
                    ] else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No answers yet. Be the first to answer!',
                            style: t.bodyStyle.copyWith(color: t.muted),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Answer composer (hidden when locked) ──────────────────────
              if (!question.locked)
                _AnswerComposer(
                  controller: _bodyCtrl,
                  posting: _posting,
                  onPost: _postAnswer,
                  t: t,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Question action enum ──────────────────────────────────────────────────────

enum _QuestionAction { pin, lock, delete }

// ── Question header ───────────────────────────────────────────────────────────

class _QuestionHeader extends StatelessWidget {
  final ForumQuestion question;
  final AppTokens t;

  const _QuestionHeader({required this.question, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + locked/pinned indicators.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.pinned) ...[
                Icon(Icons.push_pin, size: 14, color: t.amber),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  question.title,
                  style: t.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.text,
                    fontSize: 16,
                  ),
                ),
              ),
              if (question.locked) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock, size: 14, color: t.muted),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Category chip.
          ForumCategoryChip(category: question.category),
          const SizedBox(height: 10),

          // Body.
          Text(
            question.body,
            style: t.bodyStyle.copyWith(color: t.text.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ── Answer card ───────────────────────────────────────────────────────────────

class _AnswerCard extends StatelessWidget {
  final ForumAnswer answer;
  final bool canAccept;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppTokens t;

  const _AnswerCard({
    required this.answer,
    required this.canAccept,
    required this.canEdit,
    required this.canDelete,
    required this.onAccept,
    required this.onEdit,
    required this.onDelete,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: answer.accepted
            ? t.green.withValues(alpha: 0.06)
            : t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(
          color: answer.accepted
              ? t.green.withValues(alpha: 0.35)
              : t.border,
          width: answer.accepted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accepted badge.
          if (answer.accepted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: t.green),
                  const SizedBox(width: 4),
                  Text(
                    'Accepted',
                    style: t.miniStyle.copyWith(
                      color: t.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Answer body.
          Text(
            answer.body,
            style: t.bodyStyle.copyWith(color: t.text),
          ),

          // Action row: accept + edit/delete buttons.
          if (canAccept || canEdit || canDelete) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canEdit)
                  Tooltip(
                    message: 'Edit answer',
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (canDelete) ...[
                  if (canEdit) const SizedBox(width: 4),
                  Tooltip(
                    message: 'Delete answer',
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: t.muted,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                if (canAccept) ...[
                  if (canEdit || canDelete) const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onAccept,
                    icon: Icon(Icons.check, size: 14, color: t.green),
                    label: Text(
                      'Accept',
                      style: t.miniStyle.copyWith(
                        color: t.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Answer composer ───────────────────────────────────────────────────────────

class _AnswerComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool posting;
  final VoidCallback onPost;
  final AppTokens t;

  const _AnswerComposer({
    required this.controller,
    required this.posting,
    required this.onPost,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: t.bodyStyle.copyWith(color: t.text),
              decoration: InputDecoration(
                hintText: 'Write an answer…',
                hintStyle: t.bodyStyle.copyWith(color: t.muted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: t.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: posting ? null : onPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}
