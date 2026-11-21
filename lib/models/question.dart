/// 選択肢1つ分。解説は「なぜ正解か／なぜ不正解か」
class Choice {
  const Choice({required this.text, required this.explanation});

  final String text;
  final String explanation;

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      text: json['text'] as String,
      explanation: json['explanation'] as String,
    );
  }
}

/// 解説の根拠となる公式ドキュメントなどへのリンク
class Reference {
  const Reference({required this.title, required this.url});

  final String title;
  final String url;

  factory Reference.fromJson(Map<String, dynamic> json) {
    return Reference(
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }
}

/// 1問分のデータ。assets/questions/*.json の1要素に対応する。
class Question {
  const Question({
    required this.id,
    required this.type,
    required this.domainId,
    required this.question,
    required this.choices,
    required this.answers,
    required this.explanation,
    required this.references,
    this.group,
    this.source,
    this.point,
  });

  /// このバージョンのアプリが表示できる問題の種類。
  /// 並べ替えなど新しい種類を足したとき、古いアプリはそれ以外を読み飛ばす
  static const supportedTypes = {typeChoice, typeDrill};

  /// 本番形式（シナリオ＋4択／複数選択）
  static const typeChoice = 'choice';

  /// 一問一答（設計判断のポイントを1つだけ問う短い問題。4択か○×）
  static const typeDrill = 'drill';

  final String id;

  /// 問題の種類。省略時は 'choice'（単一選択・複数選択）
  final String type;

  /// exams.json の分野ID（例: d1）
  final String domainId;
  final String question;
  final List<Choice> choices;

  /// 正解の選択肢のインデックス（複数選択問題なら2つ以上）
  final List<int> answers;
  final String explanation;
  final List<Reference> references;

  /// 類題のグループ（例: s3-storage-class）。条件を変えて同じ論点を問う問題どうしに同じ値を付ける。
  /// 解説の「類題に挑戦」と、模試で似た問題が重ならないようにするために使う
  final String? group;

  /// 一問一答の分解元になった本番形式の問題のID（一問一答だけ）
  final String? source;

  /// 一問一答で問う設計判断のポイント（見出し。一問一答だけ）
  final String? point;

  bool get isDrill => type == typeDrill;

  bool get isMultiple => answers.length > 1;

  /// 選んだ選択肢が正解と完全に一致しているか
  bool isCorrect(Set<int> selected) =>
      selected.length == answers.length && selected.containsAll(answers);

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      type: json['type'] as String? ?? typeChoice,
      domainId: json['domain'] as String,
      question: json['question'] as String,
      choices: (json['choices'] as List)
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
      answers: List<int>.from(json['answers'] as List),
      explanation: json['explanation'] as String,
      references: ((json['references'] as List?) ?? const [])
          .map((e) => Reference.fromJson(e as Map<String, dynamic>))
          .toList(),
      group: json['group'] as String?,
      source: json['source'] as String?,
      point: json['point'] as String?,
    );
  }
}
