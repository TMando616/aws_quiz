import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aws_quiz/models/question.dart';
import 'package:aws_quiz/widgets/explanation_view.dart';

const _q = Question(
  id: 't-001',
  type: 'choice',
  domainId: 'd1',
  question: '問題文',
  choices: [
    Choice(text: '選択肢A', explanation: 'Aの解説'),
    Choice(text: '選択肢B', explanation: 'Bの解説'),
    Choice(text: '選択肢C', explanation: 'Cの解説'),
  ],
  answers: [1],
  explanation: 'まとめの解説',
  references: [
    Reference(title: '公式ドキュメント', url: 'https://docs.aws.amazon.com/'),
  ],
);

Future<void> _pump(WidgetTester tester, Set<int> selected) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExplanationView(question: _q, selected: selected),
        ),
      ),
    ),
  );
}

double _y(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('不正解のときは、選んだ選択肢→正解→ほかの選択肢の順に並ぶ', (tester) async {
    await _pump(tester, {0});
    expect(find.text('❌ 不正解'), findsOneWidget);
    expect(_y(tester, 'Aの解説'), lessThan(_y(tester, 'Bの解説')));
    expect(_y(tester, 'Bの解説'), lessThan(_y(tester, 'Cの解説')));
    expect(find.text('まとめの解説'), findsOneWidget);
    expect(find.text('公式ドキュメント'), findsOneWidget);
    expect(find.text('この問題の誤りを報告'), findsOneWidget);
  });

  testWidgets('正解のときは「正解」の見出しを出さない（選んだ選択肢と重なるため）', (tester) async {
    await _pump(tester, {1});
    expect(find.text('⭕ 正解'), findsOneWidget);
    expect(find.text('あなたの選択'), findsOneWidget);
    expect(find.text('正解'), findsNothing);
  });
}
