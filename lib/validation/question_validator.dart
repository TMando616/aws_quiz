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

    // 問題の種類ごとの id の一覧（一問一答の source の確認に使う）
    final typeById = <String, String>{
      for (final q in questions)
        if (q['id'] is String) q['id'] as String: _typeOf(q),
    };

    // 単一選択の正解の位置の偏り（「迷ったらB」で正解できてしまうのを防ぐ）。
    // 本番形式と一問一答は選択肢の数が違うので、種類ごとに数える
    for (final type in const [_typeChoice, _typeDrill]) {
      final singlePositions = [
        for (final q in questions)
          if (_typeOf(q) == type && (q['answers'] as List?)?.length == 1)
            (q['answers'] as List).first,
      ];
      if (singlePositions.length < 8) continue;
      final counts = <Object?, int>{};
      for (final p in singlePositions) {
        counts.update(p, (v) => v + 1, ifAbsent: () => 1);
      }
      final kind = type == _typeDrill ? '一問一答' : '単一選択';
      for (final e in counts.entries) {
        if (e.value * 2 > singlePositions.length && e.key is int) {
          final label = String.fromCharCode(65 + (e.key as int));
          warn(
            null,
            '$kindの正解が$labelに偏っています（${singlePositions.length}問中${e.value}問）。選択肢の順番を入れ替えてください',
          );
        }
      }
    }

    // 類題のグループ → そのグループの問題の id と、正解の選択肢の文
    final groups = <String, List<(String, Set<String>)>>{};

    for (final q in questions) {
      final id = q['id'] as String?;
      if (id == null || id.isEmpty) {
        error(null, 'id がない問題があります');
        continue;
      }

      // 類題のグループ（任意）
      final group = q['group'];
      if (group != null) {
        if (group is! String || !_groupPattern.hasMatch(group)) {
          error(
            id,
            'group "$group" は英小文字・数字・ハイフンで書いてください（例: s3-storage-class）',
          );
        } else {
          final answerTexts = <String>{
            for (final a in (q['answers'] as List? ?? const []))
              if (a is int &&
                  a >= 0 &&
                  a < ((q['choices'] as List?)?.length ?? 0))
                ((q['choices'] as List)[a] as Map)['text'] as String? ?? '',
          };
          groups.putIfAbsent(group, () => []).add((id, answerTexts));
        }
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

      final type = _typeOf(q);
      if (type == _typeChoice) {
        // 本番の形式とのズレ（警告）
        if (answers.length == 1 && choices.length != 4) {
          warn(id, '単一選択は本番では4択です（今は${choices.length}択）');
        }
        if (answers.length > 1 && choices.length < 5) {
          warn(id, '複数選択は本番では5つ以上の選択肢から選びます（今は${choices.length}択）');
        }
      } else if (type == _typeDrill) {
        // 一問一答：設計判断のポイントを1つだけ、短く問う
        if (choices.length < 2 || choices.length > 4) {
          error(id, '一問一答の選択肢は2〜4つにしてください（今は${choices.length}つ）');
        }
        if (answers.length != 1) error(id, '一問一答の正解は1つにしてください');
        final text = q['question'];
        if (text is String && text.length > _drillMaxLength) {
          warn(
            id,
            '一問一答の問題文が長すぎます（${text.length}字。$_drillMaxLength字以内が目安）。スマホで読みやすいように短くしてください',
          );
        }
        if ((q['point'] as String?)?.trim().isEmpty ?? true) {
          warn(id, '一問一答に point（設計判断のポイントの見出し）がありません');
        }
        final source = q['source'];
        if (source != null) {
          final sourceType = typeById[source];
          if (sourceType == null) {
            error(id, 'source "$source" の問題がこのファイルにありません');
          } else if (sourceType != _typeChoice) {
            error(id, 'source "$source" は本番形式の問題を指定してください');
          }
        }
      } else {
        error(id, 'type "$type" は対応していない種類です（choice か drill）');
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

    // 類題のグループの確認（警告）
    for (final e in groups.entries) {
      final members = e.value;
      if (members.length == 1) {
        warn(
          members.first.$1,
          '類題のグループ "${e.key}" の問題がこの1問だけです（類題に挑戦のボタンが出ません）',
        );
      }
      // 正解の選択肢の文がまったく同じ類題は、言い回しを変えただけの可能性がある
      for (var i = 0; i < members.length; i++) {
        for (var j = i + 1; j < members.length; j++) {
          if (_sameSet(members[i].$2, members[j].$2)) {
            warn(
              members[j].$1,
              '類題の ${members[i].$1} と正解の選択肢が同じです。条件を変えて正解が変わる類題にしてください',
            );
          }
        }
      }
    }
  }
  return issues;
}

final _groupPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

const _typeChoice = 'choice';
const _typeDrill = 'drill';

/// 一問一答の問題文の長さの目安（スマホで2〜3行に収まる程度）
const _drillMaxLength = 120;

String _typeOf(Map<String, dynamic> q) => q['type'] as String? ?? _typeChoice;

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
