import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aws_quiz/ads/ad_config.dart';
import 'package:aws_quiz/main.dart';

void main() {
  // テスト環境では広告SDK（ネイティブ側）が動かないので、広告を止める
  setUp(() {
    AdConfig.enabled = false;
    // 端末の保存領域の代わりに、メモリ上の空の設定を使う
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ホームに試験の一覧が出る', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // アセットの読み込みは実際の非同期処理なので、runAsyncで少しずつ待つ。
    // 問題データが増えると読み込みに時間がかかるため、固定の時間ではなく表示されるまで待つ
    for (var i = 0; i < 50 && find.text('全冠への進捗').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    // 全冠への進捗（まだ1つも取得していない）
    expect(find.text('全冠への進捗'), findsOneWidget);
    expect(find.textContaining('取得'), findsWidgets);
    // リストの上のほうにある試験（下のほうは画面外なので描画されない）
    expect(find.text('Foundational'), findsOneWidget);
    expect(find.text('CLF'), findsOneWidget);
    // 問題ファイルが無い試験は「準備中」
    expect(find.textContaining('準備中'), findsWidgets);
  });
}
