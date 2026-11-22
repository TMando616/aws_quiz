import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aws_quiz/theme/app_theme.dart';
import 'package:aws_quiz/widgets/design_parts.dart';

Future<Rect> _rectOf(WidgetTester tester, ChoiceState state) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Column(
          children: [
            ChoiceTile(
              letter: 'A',
              text: '選択肢の文',
              state: state,
              multiple: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getRect(find.byType(ChoiceTile));
}

void main() {
  testWidgets('選択・正誤で枠線が太くなっても、選択肢の大きさは変わらない', (tester) async {
    final idle = await _rectOf(tester, ChoiceState.idle);
    for (final state in [
      ChoiceState.selected,
      ChoiceState.correct,
      ChoiceState.wrong,
    ]) {
      expect(await _rectOf(tester, state), idle, reason: state.name);
    }
  });
}
