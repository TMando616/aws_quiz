import '../models/question.dart';

/// 「続きから解く」の出題順（Laravelでいうサービスクラス）
///
/// まだ解いていない問題 → 最新の回答が不正解の問題 → 正解した問題 の順に並べる。
/// それぞれの中では、問題データの順番を保つ（論点の流れを崩さないため）
List<Question> orderForContinue(
  List<Question> questions,
  Map<String, bool> latestResults,
) {
  final unanswered = <Question>[];
  final wrong = <Question>[];
  final correct = <Question>[];
  for (final q in questions) {
    switch (latestResults[q.id]) {
      case null:
        unanswered.add(q);
      case false:
        wrong.add(q);
      case true:
        correct.add(q);
    }
  }
  return [...unanswered, ...wrong, ...correct];
}

/// 「間違えた問題だけ解き直す」の対象：最新の回答が不正解の問題だけ
///
/// 一度間違えても、あとで正解していれば外す（もう解けるようになったので）。
/// 順番は問題データの順を保つ
List<Question> wrongOnly(
  List<Question> questions,
  Map<String, bool> latestResults,
) => [
  for (final q in questions)
    if (latestResults[q.id] == false) q,
];
