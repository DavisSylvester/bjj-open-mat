import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/models/roster_member.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/messaging_repository.dart';
import '../models/conversation.dart';

/// Segmented new-message flow: Direct / Group / (manager-only) Channel.
/// Always receives a [gymId] so roster and channel context are available.
class NewMessageScreen extends ConsumerStatefulWidget {
  final String gymId;

  const NewMessageScreen({super.key, required this.gymId});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen>
    with TickerProviderStateMixin {

  // Tab count is determined after first build when canManage is known.
  // We start with 2 tabs (Direct + Group) and rebuild with 3 if manager.
  TabController? _tabController;
  int _tabCount = 2;
  bool _saving = false;

  // ── Direct state ───────────────────────────────────────────────────────────
  String? _selectedDirectMemberId;

  // ── Group state ────────────────────────────────────────────────────────────
  final TextEditingController _groupTitleCtrl = TextEditingController();
  final Set<String> _selectedGroupMemberIds = {};

  // ── Channel state ──────────────────────────────────────────────────────────
  final TextEditingController _channelTitleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this)
      ..addListener(_onTabChange);
  }

  @override
  void dispose() {
    _tabController
      ?..removeListener(_onTabChange)
      ..dispose();
    _groupTitleCtrl.dispose();
    _channelTitleCtrl.dispose();
    super.dispose();
  }

  void _onTabChange() {
    setState(() {});
  }

  TabController _resolveTabController(int needed) {
    if (_tabController != null && _tabCount == needed) {
      return _tabController!;
    }
    _tabController
      ?..removeListener(_onTabChange)
      ..dispose();
    _tabCount = needed;
    _tabController = TabController(length: needed, vsync: this)
      ..addListener(_onTabChange);
    return _tabController!;
  }

  bool _deriveCanManage() {
    final myId = ref.read(currentUserIdProvider);
    final isAdmin = ref.read(authStateProvider).user?.role == 'admin';
    final rosterAsync = ref.read(rosterProvider(widget.gymId));
    final myGymRole = rosterAsync.maybeWhen(
      data: (members) => myId != null
          ? members.where((m) => m.userId == myId).firstOrNull?.gymRole
          : null,
      orElse: () => null,
    );
    return isAdmin || myGymRole == 'owner' || myGymRole == 'coach';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _startDirect() async {
    final memberId = _selectedDirectMemberId;
    if (memberId == null || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(messagingRepositoryProvider);
      final conv = await repo.startDirect(memberId);
      ref.invalidate(conversationsProvider);
      if (mounted) _openThread(conv);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createGroup() async {
    final title = _groupTitleCtrl.text.trim();
    if (title.isEmpty || _selectedGroupMemberIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(messagingRepositoryProvider);
      final conv = await repo.createGroup(
        widget.gymId,
        title,
        _selectedGroupMemberIds.toList(),
      );
      ref.invalidate(conversationsProvider);
      if (mounted) _openThread(conv);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createChannel() async {
    final title = _channelTitleCtrl.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(messagingRepositoryProvider);
      final conv = await repo.createChannel(widget.gymId, title);
      ref.invalidate(conversationsProvider);
      ref.invalidate(gymChannelsProvider(widget.gymId));
      if (mounted) _openThread(conv);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create channel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openThread(Conversation conv) {
    // Pop back to conversations list first, then push thread.
    Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final canManage = _deriveCanManage();
    final tabCount = canManage ? 3 : 2;
    final controller = _resolveTabController(tabCount);

    final tabs = <Tab>[
      const Tab(text: 'Direct'),
      const Tab(text: 'Group'),
      if (canManage) const Tab(text: 'Channel'),
    ];

    final rosterAsync = ref.watch(rosterProvider(widget.gymId));
    final members = rosterAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <RosterMember>[],
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        title: Text('New Message', style: t.h2Style),
        bottom: TabBar(
          controller: controller,
          labelColor: t.primary,
          unselectedLabelColor: t.muted,
          indicatorColor: t.primary,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          _DirectTab(
            t: t,
            members: members,
            selectedId: _selectedDirectMemberId,
            saving: _saving,
            onSelect: (id) => setState(() => _selectedDirectMemberId = id),
            onStart: _startDirect,
          ),
          _GroupTab(
            t: t,
            members: members,
            titleCtrl: _groupTitleCtrl,
            selectedIds: _selectedGroupMemberIds,
            saving: _saving,
            onToggle: (id) => setState(() {
              if (_selectedGroupMemberIds.contains(id)) {
                _selectedGroupMemberIds.remove(id);
              } else {
                _selectedGroupMemberIds.add(id);
              }
            }),
            onCreate: _createGroup,
            onChanged: () => setState(() {}),
          ),
          if (canManage)
            _ChannelTab(
              t: t,
              titleCtrl: _channelTitleCtrl,
              saving: _saving,
              onCreate: _createChannel,
              onChanged: () => setState(() {}),
            ),
        ],
      ),
    );
  }
}

// ── Direct tab ─────────────────────────────────────────────────────────────────

class _DirectTab extends StatelessWidget {
  final AppTokens t;
  final List<RosterMember> members;
  final String? selectedId;
  final bool saving;
  final ValueChanged<String> onSelect;
  final VoidCallback onStart;

  const _DirectTab({
    required this.t,
    required this.members,
    required this.selectedId,
    required this.saving,
    required this.onSelect,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = !saving && selectedId != null;
    return Column(
      children: [
        Expanded(
          child: members.isEmpty
              ? Center(
                  child: Text(
                    'No members found.',
                    style: t.bodyStyle.copyWith(color: t.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isSelected = member.userId == selectedId;
                    return _MemberTile(
                      t: t,
                      member: member,
                      isSelected: isSelected,
                      multiSelect: false,
                      onTap: () => onSelect(member.userId),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            key: const Key('nm_start'),
            onPressed: canStart ? onStart : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: t.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
              ),
            ),
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Start', style: t.bodyStyle.copyWith(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ── Group tab ──────────────────────────────────────────────────────────────────

class _GroupTab extends StatelessWidget {
  final AppTokens t;
  final List<RosterMember> members;
  final TextEditingController titleCtrl;
  final Set<String> selectedIds;
  final bool saving;
  final ValueChanged<String> onToggle;
  final VoidCallback onCreate;
  final VoidCallback onChanged;

  const _GroupTab({
    required this.t,
    required this.members,
    required this.titleCtrl,
    required this.selectedIds,
    required this.saving,
    required this.onToggle,
    required this.onCreate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = !saving && titleCtrl.text.trim().isNotEmpty && selectedIds.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const Key('nm_group_title'),
            controller: titleCtrl,
            style: t.bodyStyle.copyWith(color: t.text),
            decoration: InputDecoration(
              hintText: 'Group name',
              hintStyle: t.bodyStyle.copyWith(color: t.muted),
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? Center(
                  child: Text(
                    'No members found.',
                    style: t.bodyStyle.copyWith(color: t.muted),
                  ),
                )
              : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isSelected = selectedIds.contains(member.userId);
                    return _MemberTile(
                      t: t,
                      member: member,
                      isSelected: isSelected,
                      multiSelect: true,
                      onTap: () => onToggle(member.userId),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            key: const Key('nm_create'),
            onPressed: canCreate ? onCreate : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: t.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
              ),
            ),
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Create', style: t.bodyStyle.copyWith(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ── Channel tab ────────────────────────────────────────────────────────────────

class _ChannelTab extends StatelessWidget {
  final AppTokens t;
  final TextEditingController titleCtrl;
  final bool saving;
  final VoidCallback onCreate;
  final VoidCallback onChanged;

  const _ChannelTab({
    required this.t,
    required this.titleCtrl,
    required this.saving,
    required this.onCreate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canCreate = !saving && titleCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Channel name', style: t.labelStyle.copyWith(color: t.muted)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('nm_channel_title'),
            controller: titleCtrl,
            style: t.bodyStyle.copyWith(color: t.text),
            decoration: InputDecoration(
              hintText: 'e.g. Announcements',
              hintStyle: t.bodyStyle.copyWith(color: t.muted),
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
                borderSide: BorderSide(color: t.border),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            key: const Key('nm_channel_create'),
            onPressed: canCreate ? onCreate : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: t.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.cardRadius),
              ),
            ),
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Create Channel', style: t.bodyStyle.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Shared member tile ─────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final AppTokens t;
  final RosterMember member;
  final bool isSelected;
  final bool multiSelect;
  final VoidCallback onTap;

  const _MemberTile({
    required this.t,
    required this.member,
    required this.isSelected,
    required this.multiSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? t.primary.withValues(alpha: 0.1) : t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(
              color: isSelected ? t.primary : t.border,
            ),
          ),
          child: Row(
            children: [
              multiSelect
                  ? Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isSelected ? t.primary : t.muted,
                    )
                  : Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? t.primary : t.muted,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: t.bodyStyle.copyWith(
                        color: t.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (member.beltRank != null)
                      Text(
                        member.beltRank!,
                        style: t.miniStyle.copyWith(color: t.muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
