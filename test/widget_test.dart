import 'package:flutter_test/flutter_test.dart';

import 'package:aws_quiz/ads/ad_config.dart';
import 'package:aws_quiz/main.dart';

void main() {
  // テスト環境では広告SDK（ネイティブ側）が動かないので、広告を止める
  setUp(() => AdConfig.enabled = false);

  testWidgets('アプリが起動する', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
