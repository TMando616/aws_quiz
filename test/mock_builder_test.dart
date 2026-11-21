import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:aws_quiz/logic/mock_builder.dart';
import 'package:aws_quiz/models/exam.dart';
import 'package:aws_quiz/models/question.dart';

const _exam = Exam(
  id: 'xxx',
  code: 'XXX-C01',
  shortName: 'XXX',
  name: '',
  nameJa: '',
  level: ExamLevel.associate,
  isRetiring: false,
  retireDate: null,
  domains: [
    Domain(id: 'd1', name: '分野1', weight: 60),
    Domain(id: 'd2', name: '分野2', weight: 40),
  ],
  mock: MockSetting(questionCount: 10, timeLimitMinutes: 100),
  guideUrl: '',
);

List<Question> _pool(String domain, int n) => [
  for (var i = 0; i < n; i++)
    Question(
      id: '$domain-$i',
      type: 'choice',
      domainId: domain,
      question: '',
      choices: const [],
      answers: const [0],
      explanation: '',
      references: const [],
    ),
];

void main() {
  test('収録数が十分なら、比重どおりに配分する', () {
    final set = buildMockSet(_exam, [
      ..._pool('d1', 20),
      ..._pool('d2', 20),
    ], random: Random(1));
    expect(set.questions, hasLength(10));
    expect(set.questions.where((q) => q.domainId == 'd1'), hasLength(6));
    expect(set.questions.where((q) => q.domainId == 'd2'), hasLength(4));
    expect(set.isShort, isFalse);
    expect(set.timeLimit, const Duration(minutes: 100));
    expect(set.questions.map((q) => q.id).toSet(), hasLength(10)); // 重複なし
  });

  test('足りない分野の分は、ほかの分野から補う', () {
    final set = buildMockSet(_exam, [
      ..._pool('d1', 20),
      ..._pool('d2', 1),
    ], random: Random(1));
    expect(set.questions, hasLength(10));
    expect(set.questions.where((q) => q.domainId == 'd2'), hasLength(1));
  });

  test('全体が足りなければ、ある分だけで実施し、時間も比例して短くする', () {
    final set = buildMockSet(_exam, _pool('d1', 3), random: Random(1));
    expect(set.questions, hasLength(3));
    expect(set.isShort, isTrue);
    expect(set.timeLimit, const Duration(minutes: 30)); // 100分 × 3/10
  });
}
