import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/data/class_journal_repository.dart';

// ---------------------------------------------------------------------------
// Fake adapter helpers
// ---------------------------------------------------------------------------

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responseJson;

  _FakeAdapter(this.responseJson);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseJson),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _journalEntryJson = {
  'id': 'je1',
  'classId': 'c1',
  'gymId': 'g1',
  'userId': 'u1',
  'date': '2026-08-04',
  'whatWasTaught': 'Guard passing',
  'techniqueTags': ['knee-slice', 'torreando'],
  'rounds': 5,
  'intensity': 4,
  'partners': 3,
  'note': 'Great session',
  'shared': true,
};

final _instructorRatingSummaryJson = {
  'instructorUserId': 'u-inst',
  'avg': 4.5,
  'count': 10,
};

final _feedbackItemJson = {
  'classId': 'c1',
  'date': '2026-08-04',
  'stars': 5,
  'comment': 'Excellent class',
  'ratedByName': 'Alice',
  'anonymous': false,
  'createdAt': '2026-08-04T10:00:00Z',
};

Dio _dioWith(Map<String, dynamic> responseJson) =>
    Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = _FakeAdapter(responseJson);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ApiClassJournalRepository', () {
    test('upsertJournal() parses a single-item data envelope', () async {
      final dio = _dioWith({'data': _journalEntryJson});
      final repo = ApiClassJournalRepository(dio);

      final entry = await repo.upsertJournal('c1', {'note': 'Great session'});

      expect(entry.id, 'je1');
      expect(entry.classId, 'c1');
      expect(entry.gymId, 'g1');
      expect(entry.userId, 'u1');
      expect(entry.date, '2026-08-04');
      expect(entry.whatWasTaught, 'Guard passing');
      expect(entry.techniqueTags, ['knee-slice', 'torreando']);
      expect(entry.rounds, 5);
      expect(entry.intensity, 4);
      expect(entry.partners, 3);
      expect(entry.note, 'Great session');
      expect(entry.shared, isTrue);
    });

    test('myJournal() parses a list envelope and returns entries', () async {
      final dio = _dioWith({
        'data': [_journalEntryJson],
        'meta': {'page': 1, 'limit': 20, 'total': 1},
      });
      final repo = ApiClassJournalRepository(dio);

      final entries = await repo.myJournal(from: '2026-08-01', to: '2026-08-31');

      expect(entries, hasLength(1));
      expect(entries.single.classId, 'c1');
      expect(entries.single.shared, isTrue);
    });

    test('sharedForOccurrence() parses a list envelope', () async {
      final dio = _dioWith({
        'data': [_journalEntryJson],
        'meta': {'page': 1, 'limit': 20, 'total': 1},
      });
      final repo = ApiClassJournalRepository(dio);

      final entries = await repo.sharedForOccurrence('c1', '2026-08-04');

      expect(entries, hasLength(1));
      expect(entries.single.id, 'je1');
    });

    test('rateInstructor() completes without throwing on 200', () async {
      final dio = _dioWith({'success': true});
      final repo = ApiClassJournalRepository(dio);

      await expectLater(
        repo.rateInstructor('c1', {'stars': 5, 'anonymous': false}),
        completes,
      );
    });

    test('instructorSummary() parses a data envelope', () async {
      final dio = _dioWith({'data': _instructorRatingSummaryJson});
      final repo = ApiClassJournalRepository(dio);

      final summary = await repo.instructorSummary('u-inst');

      expect(summary.instructorUserId, 'u-inst');
      expect(summary.avg, 4.5);
      expect(summary.count, 10);
    });

    test('gymInstructorFeedback() parses a list envelope', () async {
      final dio = _dioWith({
        'data': [_feedbackItemJson],
        'meta': {'page': 1, 'limit': 20, 'total': 1},
      });
      final repo = ApiClassJournalRepository(dio);

      final items = await repo.gymInstructorFeedback('g1', instructorUserId: 'u-inst');

      expect(items, hasLength(1));
      expect(items.single.classId, 'c1');
      expect(items.single.stars, 5);
      expect(items.single.comment, 'Excellent class');
      expect(items.single.anonymous, isFalse);
    });
  });
}
