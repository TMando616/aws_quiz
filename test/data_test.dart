import 'package:flutter_test/flutter_test.dart';

import 'package:aws_quiz/data/exam_repository.dart';
import 'package:aws_quiz/data/question_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exams.json を読み込める', () async {
    final exams = await ExamRepository().loadAll();
    expect(exams, isNotEmpty);
    final sap = exams.firstWhere((e) => e.id == 'sap');
    expect(sap.code, 'SAP-C03');
    expect(sap.domains, hasLength(5));
  });

  test('終了日を過ぎた試験は一覧から外す', () async {
    final repo = ExamRepository();
    final lastDay = await repo.loadAll(now: DateTime(2026, 12, 31, 23, 59));
    expect(lastDay.map((e) => e.id), contains('ans'));
    final after = await repo.loadAll(now: DateTime(2027, 1, 1));
    expect(after.map((e) => e.id), isNot(contains('ans')));
  });

  test('問題ファイルがある試験だけを「収録あり」と判定する', () async {
    final ids = await ExamRepository().examIdsWithQuestions();
    expect(ids, contains('sap'));
    expect(ids, contains('saa'));
    expect(ids, isNot(contains('clf')));
  });

  test('SAPの問題を新しい形式で読み込める', () async {
    final questions = await QuestionRepository().load('sap');
    expect(questions, isNotEmpty);
    for (final q in questions) {
      expect(q.choices.every((c) => c.explanation.isNotEmpty), isTrue);
      expect(q.references, isNotEmpty);
    }
  });
}
