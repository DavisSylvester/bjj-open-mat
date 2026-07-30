import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';
import 'package:bjj_open_mat/features/messaging/screens/conversations_screen.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _groupConversation = Conversation(
  id: 'conv1',
  kind: 'group',
  gymId: 'g1',
  title: 'Team Alpha',
  createdBy: 'u1',
  lastMessagePreview: 'See you on the mat!',
);

final _directConversation = Conversation(
  id: 'conv2',
  kind: 'direct',
  gymId: null,
  title: null,
  createdBy: 'u2',
  lastMessagePreview: 'Good roll today',
);

final _groupSummary = ConversationSummary(
  conversation: _groupConversation,
  unreadCount: 2,
  muted: false,
  otherParticipantIds: ['u2', 'u3'],
);

final _directSummary = ConversationSummary(
  conversation: _directConversation,
  unreadCount: 0,
  muted: true,
  otherParticipantIds: ['u5'],
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationsProvider.overrideWith(
          (ref) async => [_groupSummary, _directSummary],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.glass(),
        home: const ConversationsScreen(),
      ),
    ),
  );
  // Allow FutureProvider to resolve.
  await tester.pump();
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders group title', (tester) async {
    await _pump(tester);
    expect(find.text('Team Alpha'), findsOneWidget);
  });

  testWidgets('renders direct conversation with other participant id', (tester) async {
    await _pump(tester);
    expect(find.text('u5'), findsOneWidget);
  });

  testWidgets('shows unread badge "2" for group conversation', (tester) async {
    await _pump(tester);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows mute icon for muted direct conversation', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets('shows FAB to start a new conversation', (tester) async {
    await _pump(tester);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('shows last message preview', (tester) async {
    await _pump(tester);
    expect(find.text('See you on the mat!'), findsOneWidget);
    expect(find.text('Good roll today'), findsOneWidget);
  });
}
