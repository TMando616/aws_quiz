import 'dart:math';

import '../data/study_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';

/// 模試の出題セット
class MockSet {
  const MockSet({
    required this.questions,
    required this.requestedCount,
    required this.timeLimit,
  });

  final List<Question> questions;

  /// 本来の問題数（試験の設定値）
  final int requestedCount;

  /// 制限時間。問題数が足りないときは、問題数に比例して短くする
  final Duration timeLimit;

  /// 収録数が足りず、本来の問題数より少ないか
  bool get isShort => questions.length < requestedCount;
}

/// 模試の問題を選ぶ（Laravelでいうサービスクラス）
///
/// 1. 分野ごとに「問題数 × 比重」の数だけ、ランダムに選ぶ
/// 2. 収録数が足りない分野があれば、ほかの分野の残りから補う
/// 3. それでも足りなければ、ある分だけで実施する
/// 最後に全体の順番をシャッフルする
MockSet buildMockSet(Exam exam, List<Question> pool, {Random? random}) {
  final rng = random ?? Random();
  final target = exam.mock.questionCount;

  // 分野ごとの問題（シャッフル済み）
  final byDomain = <String, List<Question>>{
    for (final d in exam.domains)
      d.id: (pool.where((q) => q.domainId == d.id).toList()..shuffle(rng)),
  };

  final picked = <Question>[];
  for (final d in exam.domains) {
    final want = (target * d.weight / 100).round();
    final list = byDomain[d.id]!;
    final take = min(want, list.length);
    picked.addAll(list.take(take));
    list.removeRange(0, take);
  }

  // 比重の丸めや、収録数が足りない分野の分を、残りから補う
  final rest = byDomain.values.expand((l) => l).toList()..shuffle(rng);
  while (picked.length < target && rest.isNotEmpty) {
    picked.add(rest.removeLast());
  }
  // 丸めで多くなった場合は削る
  if (picked.length > target) picked.removeRange(target, picked.length);

  picked.shuffle(rng);

  // 本来の時間 × 実際の問題数 / 本来の問題数（最低1分）
  final fullSeconds = exam.mock.timeLimitMinutes * 60;
  final seconds = target == 0
      ? fullSeconds
      : max(60, (fullSeconds * picked.length / target).round());
  return MockSet(
    questions: picked,
    requestedCount: target,
    timeLimit: Duration(seconds: seconds),
  );
}

/// 模試を採点する。未回答は不正解として数える
MockResult gradeMock({
  required String examId,
  required List<Question> questions,
  required Map<int, Set<int>> selections,
  required DateTime startedAt,
  required Duration duration,
}) {
  final answered = <String, int>{};
  final correct = <String, int>{};
  var correctCount = 0;
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    final ok = q.isCorrect(selections[i] ?? const {});
    answered.update(q.domainId, (v) => v + 1, ifAbsent: () => 1);
    if (ok) {
      correctCount++;
      correct.update(q.domainId, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  return MockResult(
    examId: examId,
    takenAt: startedAt,
    questionCount: questions.length,
    correctCount: correctCount,
    duration: duration,
    byDomain: {
      for (final id in answered.keys)
        id: Accuracy(answered: answered[id]!, correct: correct[id] ?? 0),
    },
  );
}
