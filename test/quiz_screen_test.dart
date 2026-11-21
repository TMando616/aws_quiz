import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aws_quiz/ads/ad_config.dart';
import 'package:aws_quiz/ads/ad_consent.dart';
import 'package:aws_quiz/models/exam.dart';
import 'package:aws_quiz/models/question.dart';
import 'package:aws_quiz/screens/quiz_screen.dart';
import 'package:aws_quiz/theme/app_theme.dart';
import 'package:aws_quiz/widgets/design_parts.dart';

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

  testWidgets('一問一答で回答して「次へ」が出ても、選択肢の位置は変わらない', (tester) async {
    await _pump(tester, [_drill, _drill]);
    // 正解の色に変わると枠線が太くなり文字が0.5pxずれるので、選択肢の枠の位置で比べる
    final tile = find.byType(ChoiceTile).first;
    final before = tester.getRect(tile);

    await tester.tap(find.text('○ 正しい'));
    await tester.pumpAndSettle();

    expect(find.text('次へ'), findsOneWidget);
    expect(tester.getRect(tile), before);
  });
}
