import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aws_quiz/data/study_repository.dart';
import 'package:aws_quiz/models/question.dart';

Question _q(String id, String domain) => Question(
  id: id,
  type: 'choice',
  domainId: domain,
  question: '',
  choices: const [],
  answers: const [0],
  explanation: '',
  references: const [],
);

void main() {
  // Mac上のSQLiteで、実際のSQLを動かしてテストする
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late StudyRepository repo;
  setUp(() async => repo = await StudyRepository.open(inMemoryDatabasePath));
  tearDown(() => repo.close());

  final questions = [_q('q1', 'd1'), _q('q2', 'd1'), _q('q3', 'd2')];

  Future<void> answer(String id, bool correct) => repo.recordAnswer(
    examId: 'sap',
    questionId: id,
    correct: correct,
    mode: StudyMode.practice,
  );

  test('まだ解いていなければ空', () async {
    expect(await repo.accuracyByDomain('sap', questions), isEmpty);
  });

  test('分野ごとに、各問題の最新の回答で正答率を出す', () async {
    await answer('q1', false);
    await answer('q1', true); // 解き直して正解 → 正解として数える
    await answer('q2', false);
    await answer('q3', true);

    final byDomain = await repo.accuracyByDomain('sap', questions);
    expect(byDomain['d1']!.answered, 2);
    expect(byDomain['d1']!.correct, 1);
    expect(byDomain['d1']!.rate, 0.5);
    expect(byDomain['d2']!.rate, 1.0);

    final total = await repo.accuracyOfExam('sap', questions);
    expect(total.answered, 3);
    expect(total.correct, 2);
  });

  test('ほかの試験の記録や、今の問題データにない問題は数えない', () async {
    await repo.recordAnswer(
      examId: 'saa',
      questionId: 'q1',
      correct: true,
      mode: StudyMode.practice,
    );
    await answer('old-question', true);

    expect(await repo.accuracyByDomain('sap', questions), isEmpty);
  });

  test('模試の結果を保存し、新しい順に読み出せる', () async {
    MockResult result(int day, int correct) => MockResult(
      examId: 'sap',
      takenAt: DateTime(2026, 11, day),
      questionCount: 3,
      correctCount: correct,
      duration: const Duration(minutes: 7),
      byDomain: {'d1': Accuracy(answered: 2, correct: correct.clamp(0, 2))},
    );
    await repo.saveMockResult(result(20, 1));
    await repo.saveMockResult(result(21, 2));

    final results = await repo.mockResults('sap');
    expect(results, hasLength(2));
    expect(results.first.takenAt, DateTime(2026, 11, 21));
    expect(results.first.correctCount, 2);
    expect(results.first.duration, const Duration(minutes: 7));
    expect(results.first.byDomain['d1']!.correct, 2);
    expect(await repo.mockResults('saa'), isEmpty);
  });

  group('今日の回答数と連続日数', () {
    final now = DateTime(2026, 11, 22, 9);
    Future<void> answerOn(DateTime at) => repo.recordAnswer(
      examId: 'sap',
      questionId: 'q1',
      correct: true,
      mode: StudyMode.drill,
      at: at,
    );

    test('まだ解いていなければ0', () async {
      final a = await repo.dailyActivity(now: now);
      expect(a.todayCount, 0);
      expect(a.streakDays, 0);
    });

    test('今日の回答数を数え、昨日・一昨日と続いていれば3日連続', () async {
      await answerOn(DateTime(2026, 11, 20, 8));
      await answerOn(DateTime(2026, 11, 21, 23, 59));
      await answerOn(DateTime(2026, 11, 22, 7));
      await answerOn(DateTime(2026, 11, 22, 8));
      final a = await repo.dailyActivity(now: now);
      expect(a.todayCount, 2);
      expect(a.streakDays, 3);
    });

    test('今日まだ解いていなくても、昨日まで続いていれば途切れない', () async {
      await answerOn(DateTime(2026, 11, 20, 8));
      await answerOn(DateTime(2026, 11, 21, 8));
      final a = await repo.dailyActivity(now: now);
      expect(a.todayCount, 0);
      expect(a.streakDays, 2);
    });

    test('1日空いたら、そこで途切れる', () async {
      await answerOn(DateTime(2026, 11, 19, 8));
      await answerOn(DateTime(2026, 11, 21, 8));
      await answerOn(DateTime(2026, 11, 22, 8));
      final a = await repo.dailyActivity(now: now);
      expect(a.streakDays, 2);
    });
  });
}
