import 'forum_question.dart';
import 'forum_answer.dart';

class ForumQuestionDetail {
  final ForumQuestion question;
  final List<ForumAnswer> answers;

  const ForumQuestionDetail({
    required this.question,
    required this.answers,
  });

  factory ForumQuestionDetail.fromJson(Map<String, dynamic> json) =>
      ForumQuestionDetail(
        question: ForumQuestion.fromJson(json['question'] as Map<String, dynamic>),
        answers: (json['answers'] as List<dynamic>)
            .map((e) => ForumAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
