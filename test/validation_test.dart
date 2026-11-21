import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aws_quiz/validation/question_validator.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// チェックに通る最小の問題
Map<String, dynamic> _validQuestion(String id) => {
  'id': id,
  'domain': 'd1',
  'question': '問題文',
  'choices': [
    for (final t in ['A', 'B', 'C', 'D']) {'text': t, 'explanation': '$tの解説'},
  ],
  'answers': [0],
  'explanation': 'まとめ',
  'references': [
    {'title': '公式', 'url': 'https://docs.aws.amazon.com/ja_jp/example.html'},
  ],
};

final _exams = {
  'exams': [
    {
      'id': 'xxx',
      'code': 'XXX-C01',
      'domains': [
        {'id': 'd1', 'name': '分野1', 'weight': 100},
      ],
    },
  ],
};

List<ValidationIssue> _errorsOf(List<Map<String, dynamic>> questions) {
  return validateQuestions(
    examsJson: _exams,
    questionFiles: {
      'assets/questions/xxx.json': {
        'examId': 'xxx',
        'examCode': 'XXX-C01',
        'questions': questions,
      },
    },
  ).where((i) => i.isError).toList();
}

void main() {
  test('収録している全試験の問題にエラーがない', () {
    final files = Directory('assets/questions')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    final issues = validateQuestions(
      examsJson: _readJson('assets/exams.json'),
      questionFiles: {for (final f in files) f.path: _readJson(f.path)},
    );
    expect(issues.where((i) => i.isError), isEmpty, reason: issues.join('\n'));
  });

  test('正しい問題はエラーにならない', () {
    expect(_errorsOf([_validQuestion('xxx-001')]), isEmpty);
  });

  test('根拠リンクがない問題を見つける', () {
    final q = _validQuestion('xxx-001')..['references'] = [];
    expect(_errorsOf([q]).single.message, contains('根拠リンクがありません'));
  });

  test('一次情報以外のリンクを見つける', () {
    final q = _validQuestion('xxx-001')
      ..['references'] = [
        {'title': 'まとめ記事', 'url': 'https://example.com/aws'},
      ];
    expect(_errorsOf([q]).single.message, contains('一次情報'));
  });

  test('解説のない選択肢を見つける', () {
    final q = _validQuestion('xxx-001');
    (q['choices'] as List)[2] = {'text': 'C', 'explanation': ''};
    expect(_errorsOf([q]).single.message, contains('選択肢C の解説'));
  });

  test('範囲外の answers を見つける', () {
    final q = _validQuestion('xxx-001')..['answers'] = [4];
    expect(_errorsOf([q]).single.message, contains('範囲'));
  });

  test('id の重複を見つける', () {
    final errors = _errorsOf([
      _validQuestion('xxx-001'),
      _validQuestion('xxx-001'),
    ]);
    expect(errors.single.message, contains('重複'));
  });

  test('exams.json にない分野を見つける', () {
    final q = _validQuestion('xxx-001')..['domain'] = 'd9';
    expect(_errorsOf([q]).single.message, contains('d9'));
  });

  test('単一選択の正解の位置が偏っていたら警告する', () {
    final issues = validateQuestions(
      examsJson: _exams,
      questionFiles: {
        'assets/questions/xxx.json': {
          'examId': 'xxx',
          'examCode': 'XXX-C01',
          'questions': [for (var i = 0; i < 8; i++) _validQuestion('xxx-$i')],
        },
      },
    );
    expect(issues.where((i) => i.isError), isEmpty);
    expect(issues.single.message, contains('Aに偏って'));
  });

  List<ValidationIssue> issuesOf(List<Map<String, dynamic>> questions) =>
      validateQuestions(
        examsJson: _exams,
        questionFiles: {
          'assets/questions/xxx.json': {
            'examId': 'xxx',
            'examCode': 'XXX-C01',
            'questions': questions,
          },
        },
      );

  test('類題のグループの書き方が違えばエラーにする', () {
    final q = _validQuestion('xxx-001')..['group'] = 'S3 Storage';
    expect(_errorsOf([q]).single.message, contains('group'));
  });

  test('類題のグループが1問だけなら警告する', () {
    final q = _validQuestion('xxx-001')..['group'] = 's3-class';
    final issues = issuesOf([q]);
    expect(issues.where((i) => i.isError), isEmpty);
    expect(issues.single.message, contains('この1問だけ'));
  });

  test('類題どうしで正解の選択肢が同じなら警告する', () {
    final a = _validQuestion('xxx-001')..['group'] = 's3-class';
    final b = _validQuestion('xxx-002')..['group'] = 's3-class';
    expect(issuesOf([a, b]).single.message, contains('正解の選択肢が同じ'));
    // 正解が違えば警告しない
    final c = _validQuestion('xxx-003')
      ..['group'] = 's3-class'
      ..['answers'] = [1];
    expect(issuesOf([a, c]), isEmpty);
  });
}
