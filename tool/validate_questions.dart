// 全試験の問題データをチェックする。
// 使い方: dart run tool/validate_questions.dart
// エラーが1件でもあれば終了コード1で終わる（警告だけなら0）

import 'dart:convert';
import 'dart:io';

import 'package:aws_quiz/validation/question_validator.dart';

void main() {
  final examsJson = jsonDecode(
    File('assets/exams.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final files =
      Directory('assets/questions')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final questionFiles = {
    for (final f in files)
      f.path: jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
  };

  final issues = validateQuestions(
    examsJson: examsJson,
    questionFiles: questionFiles,
  );

  final total = questionFiles.values
      .map((d) => (d['questions'] as List?)?.length ?? 0)
      .fold(0, (a, b) => a + b);
  final errors = issues.where((i) => i.isError).length;
  final warnings = issues.length - errors;

  for (final issue in issues) {
    stdout.writeln(issue);
  }
  stdout.writeln(
    '${questionFiles.length}ファイル・$total問をチェック: エラー $errors件、警告 $warnings件',
  );
  if (errors > 0) exit(1);
}
