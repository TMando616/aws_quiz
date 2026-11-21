// 問題データの品質チェック。
// Flutterに依存しない純粋なDartなので、`dart run tool/validate_questions.dart` と
// `flutter test` の両方から使える。

/// 根拠リンクとして認める一次情報のドメイン
const allowedReferenceHosts = {
  'docs.aws.amazon.com',
  'aws.amazon.com',
  'd1.awsstatic.com',
};

/// チェック結果1件
class ValidationIssue {
  const ValidationIssue(
    this.file,
    this.questionId,
    this.message, {
    this.isError = true,
  });

  final String file;
  final String? questionId;
  final String message;

  /// false なら警告（本番の形式とのズレなど。チェック自体は通す）
  final bool isError;

  @override
  String toString() {
    final level = isError ? 'エラー' : '警告';
    final where = questionId == null ? file : '$file [$questionId]';
    return '$level: $where: $message';
  }
}

/// [examsJson] は exams.json の中身、[questionFiles] は「ファイル名 → 中身」
List<ValidationIssue> validateQuestions({
  required Map<String, dynamic> examsJson,
  required Map<String, Map<String, dynamic>> questionFiles,
}) {
  final issues = <ValidationIssue>[];

  // 試験ID → { code, 分野IDの集合 }
  final exams = <String, ({String code, Set<String> domains})>{};
  for (final e in (examsJson['exams'] as List).cast<Map<String, dynamic>>()) {
    final domains = (e['domains'] as List)
        .cast<Map<String, dynamic>>()
        .map((d) => d['id'] as String)
        .toSet();
    exams[e['id'] as String] = (code: e['code'] as String, domains: domains);
  }

  final seenIds = <String, String>{}; // 問題ID → ファイル名（全試験を通して重複を見る）

  for (final entry in questionFiles.entries) {
    final file = entry.key;
    final data = entry.value;
    void error(String? id, String msg) =>
        issues.add(ValidationIssue(file, id, msg));
    void warn(String? id, String msg) =>
        issues.add(ValidationIssue(file, id, msg, isError: false));

    final examId = data['examId'] as String?;
    final exam = exams[examId];
    if (exam == null) {
      error(null, 'examId "$examId" が exams.json にありません');
      continue;
    }
    final expectedFile = '$examId.json';
    if (!file.endsWith(expectedFile)) {
      error(null, 'ファイル名は $expectedFile にしてください');
    }
    if (data['examCode'] != exam.code) {
      error(
        null,
        'examCode "${data['examCode']}" が exams.json の版 "${exam.code}" と一致しません（古い版の問題が混ざっていないか確認）',
      );
    }

    final questions = ((data['questions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    // 単一選択の正解の位置の偏り（「迷ったらB」で正解できてしまうのを防ぐ）
    final singlePositions = [
      for (final q in questions)
        if ((q['answers'] as List?)?.length == 1) (q['answers'] as List).first,
    ];
    if (singlePositions.length >= 8) {
      final counts = <Object?, int>{};
      for (final p in singlePositions) {
        counts.update(p, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final e in counts.entries) {
        if (e.value * 2 > singlePositions.length && e.key is int) {
          final label = String.fromCharCode(65 + (e.key as int));
          warn(
            null,
            '単一選択の正解が$labelに偏っています（${singlePositions.length}問中${e.value}問）。選択肢の順番を入れ替えてください',
          );
        }
      }
    }
    for (final q in questions) {
      final id = q['id'] as String?;
      if (id == null || id.isEmpty) {
        error(null, 'id がない問題があります');
        continue;
      }

      // id の重複
      final dup = seenIds[id];
      if (dup != null) {
        error(id, 'id が重複しています（$dup にも同じ id があります）');
      }
      seenIds[id] = file;

      // 分野
      final domain = q['domain'];
      if (!exam.domains.contains(domain)) {
        error(
          id,
          'domain "$domain" が exams.json の分野（${exam.domains.join(', ')}）にありません',
        );
      }

      // 必須のテキスト
      for (final key in ['question', 'explanation']) {
        final v = q[key];
        if (v is! String || v.trim().isEmpty) error(id, '$key が空です');
      }

      // 選択肢と選択肢ごとの解説
      final choices = ((q['choices'] as List?) ?? const []);
      if (choices.length < 2) error(id, '選択肢が2つ未満です');
      for (var i = 0; i < choices.length; i++) {
        final c = choices[i];
        final label = String.fromCharCode(65 + i);
        if (c is! Map<String, dynamic>) {
          error(id, '選択肢$label が {text, explanation} の形式ではありません');
          continue;
        }
        if ((c['text'] as String?)?.trim().isEmpty ?? true) {
          error(id, '選択肢$label の text が空です');
        }
        if ((c['explanation'] as String?)?.trim().isEmpty ?? true) {
          error(id, '選択肢$label の解説がありません');
        }
      }

      // 正解のインデックス
      final answers = ((q['answers'] as List?) ?? const []);
      if (answers.isEmpty) error(id, 'answers が空です');
      for (final a in answers) {
        if (a is! int || a < 0 || a >= choices.length) {
          error(id, 'answers の $a が選択肢の範囲（0〜${choices.length - 1}）外です');
        }
      }
      if (answers.toSet().length != answers.length) {
        error(id, 'answers に同じ番号が重複しています');
      }

      // 本番の形式とのズレ（警告）
      if (answers.length == 1 && choices.length != 4) {
        warn(id, '単一選択は本番では4択です（今は${choices.length}択）');
      }
      if (answers.length > 1 && choices.length < 5) {
        warn(id, '複数選択は本番では5つ以上の選択肢から選びます（今は${choices.length}択）');
      }

      // 根拠リンク
      final refs = ((q['references'] as List?) ?? const []);
      if (refs.isEmpty) error(id, '根拠リンクがありません');
      for (final r in refs) {
        if (r is! Map<String, dynamic>) {
          error(id, '根拠リンクが {title, url} の形式ではありません');
          continue;
        }
        if ((r['title'] as String?)?.trim().isEmpty ?? true) {
          error(id, '根拠リンクの title が空です');
        }
        final uri = Uri.tryParse(r['url'] as String? ?? '');
        if (uri == null || uri.scheme != 'https') {
          error(id, '根拠リンクの url が https ではありません: ${r['url']}');
        } else if (!allowedReferenceHosts.contains(uri.host)) {
          error(
            id,
            '根拠リンクが一次情報のドメイン（${allowedReferenceHosts.join(', ')}）ではありません: ${uri.host}',
          );
        }
      }
    }
  }
  return issues;
}
