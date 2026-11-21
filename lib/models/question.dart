/// 1問分のデータ。assets/questions/*.json の1要素に対応する。
class Question {
  const Question({
    required this.id,
    required this.domain,
    required this.question,
    required this.choices,
    required this.answers,
    required this.explanation,
  });

  final String id;
  final String domain;
  final String question;
  final List<String> choices;

  /// 正解の選択肢のインデックス（複数選択問題なら2つ以上）
  final List<int> answers;
  final String explanation;

  bool get isMultiple => answers.length > 1;

  /// 選んだ選択肢が正解と完全に一致しているか
  bool isCorrect(Set<int> selected) =>
      selected.length == answers.length && selected.containsAll(answers);

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      domain: json['domain'] as String,
      question: json['question'] as String,
      choices: List<String>.from(json['choices'] as List),
      answers: List<int>.from(json['answers'] as List),
      explanation: json['explanation'] as String,
    );
  }
}
