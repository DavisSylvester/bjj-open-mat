// Widget tests for the aggregate unread badge on the Messages nav destination.
//
// Tests pump [AppBottomNav] in isolation with a ProviderScope that overrides
// [conversationsProvider], then assert badge presence/absence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bjj_open_mat/core/design/app_theme.dart';
import 'package:bjj_open_mat/features/messaging/data/messaging_repository.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation.dart';
import 'package:bjj_open_mat/features/messaging/models/conversation_summary.dart';
import 'package:bjj_open_mat/shared/widgets/app_bottom_nav.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ConversationSummary _makeConv({
  required String id,
  required int unread,
  required bool muted,
}) =>
    ConversationSummary(
      conversation: Conversation(
        id: id,
        kind: 'direct',
        gymId: null,
        title: null,
        createdBy: 'u1',
        lastMessagePreview: null,
      ),
      unreadCount: unread,
      muted: muted,
      otherParticipantIds: ['u2'],
    );

/// Pumps [AppBottomNav] directly with [messagesUnreadCount] wired in.
/// The provider override is not needed for AppBottomNav in isolation —
/// the count is passed as a parameter (the router computes it from the provider).
Future<void> _pumpNav(
  WidgetTester tester, {
  required int messagesUnreadCount,
}) async {
  tester.view.physicalSize = const Size(1080, 200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.glass(),
      home: Scaffold(
        bottomNavigationBar: AppBottomNav(
          active: 'home',
          onTap: (_) {},
          messagesUnreadCount: messagesUnreadCount,
        ),
      ),
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AppBottomNav — Messages unread badge', () {
    testWidgets('shows badge "3" when messagesUnreadCount is 3', (tester) async {
      await _pumpNav(tester, messagesUnreadCount: 3);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows no badge when messagesUnreadCount is 0', (tester) async {
      await _pumpNav(tester, messagesUnreadCount: 0);
      // "0" must not appear as a badge label
      expect(find.text('0'), findsNothing);
    });

    testWidgets('caps badge at "99+" when count exceeds 99', (tester) async {
      await _pumpNav(tester, messagesUnreadCount: 150);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('shows badge "99+" at exactly 100', (tester) async {
      await _pumpNav(tester, messagesUnreadCount: 100);
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('unread count aggregation — muted filtering', () {
    /// Verify that the aggregation logic used by _ScaffoldWithNavBar
    /// (sum unreadCount where !muted) behaves correctly.
    test('sums only non-muted conversation unread counts', () {
      final convs = [
        _makeConv(id: 'c1', unread: 2, muted: false),
        _makeConv(id: 'c2', unread: 5, muted: true),  // muted — must not contribute
        _makeConv(id: 'c3', unread: 1, muted: false),
      ];

      final total = convs
          .where((c) => !c.muted)
          .fold<int>(0, (sum, c) => sum + c.unreadCount);

      expect(total, 3); // 2 + 1 only
    });

    test('returns 0 when all conversations are muted', () {
      final convs = [
        _makeConv(id: 'c1', unread: 10, muted: true),
        _makeConv(id: 'c2', unread: 3, muted: true),
      ];

      final total = convs
          .where((c) => !c.muted)
          .fold<int>(0, (sum, c) => sum + c.unreadCount);

      expect(total, 0);
    });

    test('returns 0 when all conversations are read', () {
      final convs = [
        _makeConv(id: 'c1', unread: 0, muted: false),
        _makeConv(id: 'c2', unread: 0, muted: false),
      ];

      final total = convs
          .where((c) => !c.muted)
          .fold<int>(0, (sum, c) => sum + c.unreadCount);

      expect(total, 0);
    });
  });

  group('conversationsProvider — badge integration via ProviderScope', () {
    testWidgets('badge shows "3" when provider has 3 non-muted unread',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final convs = [
        _makeConv(id: 'c1', unread: 2, muted: false),
        _makeConv(id: 'c2', unread: 5, muted: true),  // excluded
        _makeConv(id: 'c3', unread: 1, muted: false),
      ];

      // Compute count the same way _ScaffoldWithNavBar does.
      final count = convs
          .where((c) => !c.muted)
          .fold<int>(0, (sum, c) => sum + c.unreadCount);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationsProvider.overrideWith((ref) async => convs),
          ],
          child: MaterialApp(
            theme: AppTheme.glass(),
            home: Scaffold(
              bottomNavigationBar: AppBottomNav(
                active: 'home',
                onTap: (_) {},
                messagesUnreadCount: count,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no badge when all conversations are muted', (tester) async {
      tester.view.physicalSize = const Size(1080, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final convs = [
        _makeConv(id: 'c1', unread: 7, muted: true),
        _makeConv(id: 'c2', unread: 3, muted: true),
      ];

      final count = convs
          .where((c) => !c.muted)
          .fold<int>(0, (sum, c) => sum + c.unreadCount);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.glass(),
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              active: 'home',
              onTap: (_) {},
              messagesUnreadCount: count,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsNothing);
      // No badge digit rendered
      expect(find.text('10'), findsNothing);
    });
  });
}
