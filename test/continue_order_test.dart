import 'package:flutter_test/flutter_test.dart';

import 'package:aws_quiz/logic/continue_order.dart';
import 'package:aws_quiz/models/question.dart';

Question _q(String id) => Question(
  id: id,
  type: Question.typeDrill,
  domainId: 'd1',
  question: '',
  choices: const [],
  answers: const [0],
  explanation: '',
  references: const [],
);

void main() {
  final questions = [
    for (final id in ['a', 'b', 'c', 'd', 'e']) _q(id),
  ];
  List<String> ids(List<Question> qs) => [for (final q in qs) q.id];

  test('未回答 → 不正解 → 正解 の順。それぞれの中では元の順番を保つ', () {
    final ordered = orderForContinue(questions, {
      'a': true,
      'b': false,
      'd': false,
    });
    expect(ids(ordered), ['c', 'e', 'b', 'd', 'a']);
  });

  test('まだ1問も解いていなければ元の順番のまま', () {
    expect(ids(orderForContinue(questions, {})), ['a', 'b', 'c', 'd', 'e']);
  });
}
