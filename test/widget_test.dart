import 'package:flutter_test/flutter_test.dart';

import 'package:aws_quiz/main.dart';

void main() {
  testWidgets('アプリが起動する', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
