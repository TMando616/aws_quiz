import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aws_quiz/ads/ad_config.dart';
import 'package:aws_quiz/ads/ad_consent.dart';
import 'package:aws_quiz/models/exam.dart';
import 'package:aws_quiz/models/question.dart';
import 'package:aws_quiz/screens/quiz_screen.dart';
import 'package:aws_quiz/theme/app_theme.dart';

const _exam = Exam(
  id: 'saa', // 類題ボタンが問題ファイルを読むので、実在する試験にする
  code: 'XXX-C01',
  shortName: 'XXX',
  name: 'Test',
  nameJa: 'テスト',
  level: ExamLevel.associate,
  isRetiring: false,
  retireDate: null,
  domains: [Domain(id: 'd1', name: '分野1', weight: 100)],
  mock: MockSetting(questionCount: 1, timeLimitMinutes: 1),
  guideUrl: 'https://aws.amazon.com/',
);

const _drill = Question(
  id: 'xxx-d1',
  type: Question.typeDrill,
  domainId: 'd1',
  question: '一問一答の問題文',
  choices: [
    Choice(text: '○ 正しい', explanation: '正しいの解説'),
    Choice(text: '× 誤り', explanation: '誤りの解説'),
  ],
  answers: [0],
  explanation: 'まとめの解説',
  references: [
    Reference(title: '公式ドキュメント', url: 'https://docs.aws.amazon.com/'),
  ],
);

Future<void> _pump(WidgetTester tester, List<Question> questions) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: QuizScreen(exam: _exam, questions: questions, title: '一問一答'),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    AdConfig.enabled = false;
    SharedPreferences.setMockInitialValues({});
    AdConsent.gather();
  });

  testWidgets('一問一答では表示の切り替えメニューを出さない', (tester) async {
    await _pump(tester, [_drill]);
    expect(find.byTooltip('表示の切り替え'), findsNothing);
  });

  testWidgets('一問一答で回答すると、正解・不正解の見出しまでスクロールする', (tester) async {
    await _pump(tester, [_drill, _drill]);

    await tester.tap(find.text('○ 正しい'));
    await tester.pumpAndSettle();

    // 見出しが画面の上のほう（AppBar と進捗の少し下）に来ている
    final heading = find.text('正解').hitTestable();
    expect(heading, findsOneWidget);
    expect(tester.getTopLeft(heading).dy, lessThan(200));
  });

  testWidgets('解説に続きがあるときは「続きを見る」を出し、一番下まで送ったら隠す', (tester) async {
    const long = Question(
      id: 'xxx-d2',
      type: Question.typeDrill,
      domainId: 'd1',
      question: '一問一答の問題文',
      choices: [
        Choice(text: '○ 正しい', explanation: '正しいの解説'),
        Choice(text: '× 誤り', explanation: '誤りの解説'),
      ],
      answers: [0],
      // 画面に収まらない長さのまとめ
      explanation:
          '長いまとめの解説。長いまとめの解説。長いまとめの解説。長いまとめの解説。'
          '長いまとめの解説。長いまとめの解説。長いまとめの解説。長いまとめの解説。'
          '長いまとめの解説。長いまとめの解説。長いまとめの解説。長いまとめの解説。'
          '長いまとめの解説。長いまとめの解説。長いまとめの解説。長いまとめの解説。'
          '長いまとめの解説。長いまとめの解説。長いまとめの解説。長いまとめの解説。'
          '長いまとめの解説。長いまとめの解説。長いまとめの解説。長いまとめの解説。',
      references: [
        Reference(title: '公式ドキュメント', url: 'https://docs.aws.amazon.com/'),
      ],
    );
    await _pump(tester, [long, long]);
    // 回答前は出さない
    expect(find.text('続きを見る').hitTestable(), findsNothing);

    await tester.tap(find.text('○ 正しい'));
    await tester.pumpAndSettle();
    expect(find.text('続きを見る').hitTestable(), findsOneWidget);

    await tester.tap(find.text('続きを見る'));
    await tester.pumpAndSettle();
    expect(find.text('続きを見る').hitTestable(), findsNothing);
    expect(find.text('次へ'), findsOneWidget);
  });
}
