/// 試験のレベル。ホームではこの順に並べる
enum ExamLevel {
  foundational('Foundational'),
  associate('Associate'),
  professional('Professional'),
  specialty('Specialty');

  const ExamLevel(this.label);

  final String label;
}

/// 出題分野。問題側は [id] で参照する
class Domain {
  const Domain({required this.id, required this.name, required this.weight});

  final String id;
  final String name;

  /// 本番の試験での比重（%）。模試で分野ごとの問題数を配分するのに使う
  final int weight;

  factory Domain.fromJson(Map<String, dynamic> json) {
    return Domain(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: json['weight'] as int,
    );
  }
}

/// 模試の設定（公式の試験ガイドに合わせる）
class MockSetting {
  const MockSetting({
    required this.questionCount,
    required this.timeLimitMinutes,
  });

  final int questionCount;
  final int timeLimitMinutes;

  factory MockSetting.fromJson(Map<String, dynamic> json) {
    return MockSetting(
      questionCount: json['questionCount'] as int,
      timeLimitMinutes: json['timeLimitMinutes'] as int,
    );
  }
}

/// 1つの試験。assets/exams.json の1要素に対応する
class Exam {
  const Exam({
    required this.id,
    required this.code,
    required this.shortName,
    required this.name,
    required this.nameJa,
    required this.level,
    required this.isRetiring,
    required this.retireDate,
    required this.domains,
    required this.mock,
    required this.guideUrl,
  });

  /// 問題ファイル名にも使う（`assets/questions/<id>.json`）
  final String id;

  /// 版まで含めた試験コード（例: SAP-C03）
  final String code;

  /// 画面に出す短い名前（例: SAP）
  final String shortName;
  final String name;
  final String nameJa;
  final ExamLevel level;

  /// 終了予定の試験か
  final bool isRetiring;
  final DateTime? retireDate;
  final List<Domain> domains;
  final MockSetting mock;
  final String guideUrl;

  Domain? domainById(String id) {
    for (final d in domains) {
      if (d.id == id) return d;
    }
    return null;
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    final retire = json['retireDate'] as String?;
    return Exam(
      id: json['id'] as String,
      code: json['code'] as String,
      shortName: json['shortName'] as String,
      name: json['name'] as String,
      nameJa: json['nameJa'] as String,
      level: ExamLevel.values.byName(json['level'] as String),
      isRetiring: json['status'] == 'retiring',
      retireDate: retire == null ? null : DateTime.parse(retire),
      domains: (json['domains'] as List)
          .map((e) => Domain.fromJson(e as Map<String, dynamic>))
          .toList(),
      mock: MockSetting.fromJson(json['mock'] as Map<String, dynamic>),
      guideUrl: json['guideUrl'] as String,
    );
  }
}
