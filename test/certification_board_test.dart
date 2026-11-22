import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aws_quiz/models/exam.dart';
import 'package:aws_quiz/theme/app_theme.dart';
import 'package:aws_quiz/widgets/certification_board.dart';

Exam _exam(String id, ExamLevel level) => Exam(
  id: id,
  code: '${id.toUpperCase()}-C01',
  shortName: id.toUpperCase(),
  name: id,
  nameJa: id,
  level: level,
  isRetiring: false,
  retireDate: null,
  domains: const [],
  mock: const MockSetting(questionCount: 1, timeLimitMinutes: 1),
  guideUrl: 'https://aws.amazon.com/',
);

final _exams = [
  _exam('clf', ExamLevel.foundational),
  _exam('saa', ExamLevel.associate),
  _exam('sap', ExamLevel.professional),
];

/// 取得済みを親で持ち、タップで切り替える（ホームと同じ使い方）
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final certified = <String>{'clf'};

  @override
  Widget build(BuildContext context) => CertificationBoard(
    exams: _exams,
    certified: certified,
    onToggle: (e) => setState(
      () => certified.contains(e.id)
          ? certified.remove(e.id)
          : certified.add(e.id),
    ),
  );
}

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: _Host()),
    ),
  );

  double scaleOf(WidgetTester tester, String label) => tester
      .widget<ScaleTransition>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;

  testWidgets('全冠までの残りと取得数を出す', (tester) async {
    await pump(tester);
    expect(find.text('1 / 3 取得'), findsOneWidget);
    expect(find.text('全冠まで あと 2 試験', findRichText: true), findsOneWidget);
  });

  testWidgets('タップで印を付けると判子の動きが出て、元の大きさで止まる', (tester) async {
    await pump(tester);
    // 開いたときは動かない
    expect(scaleOf(tester, 'SAA'), 1.0);

    await tester.tap(find.text('SAA'));
    await tester.pump();
    expect(scaleOf(tester, 'SAA'), greaterThan(1.0));
    expect(find.text('2 / 3 取得'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(scaleOf(tester, 'SAA'), 1.0);
  });

  testWidgets('印を外すときは動かさない', (tester) async {
    await pump(tester);
    await tester.tap(find.text('CLF'));
    await tester.pump();
    expect(scaleOf(tester, 'CLF'), 1.0);
    expect(find.text('0 / 3 取得'), findsOneWidget);
  });

  testWidgets('全部取得したら「全冠達成」', (tester) async {
    await pump(tester);
    await tester.tap(find.text('SAA'));
    await tester.tap(find.text('SAP'));
    await tester.pumpAndSettle();
    expect(find.text('全冠達成'), findsOneWidget);
  });
}
