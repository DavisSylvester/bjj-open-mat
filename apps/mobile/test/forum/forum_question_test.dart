import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/forum/models/forum_question.dart';

void main() {
  test('ForumQuestion.fromJson maps fields + defaults', () {
    final q = ForumQuestion.fromJson(const {
      'id': 'q1',
      'gymId': 'g1',
      'authorId': 'u1',
      'category': 'technique',
      'title': 'Guard pass?',
      'body': 'How?',
      'pinned': true,
      'locked': false,
      'acceptedAnswerId': 'a1',
      'answerCount': 3,
    });
    expect(q.id, 'q1');
    expect(q.category, 'technique');
    expect(q.pinned, true);
    expect(q.acceptedAnswerId, 'a1');
    expect(q.answerCount, 3);
  });
}
