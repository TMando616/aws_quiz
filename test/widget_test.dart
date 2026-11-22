import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
    for (var i = 0; i < 50 && find.text('今日の学習').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    // 全冠ボード（まだ1つも取得していない）。全試験がレベル別に並ぶ
    expect(find.text('0 / 12 取得'), findsOneWidget);
    expect(find.text('Foundational'), findsOneWidget);
    expect(find.text('CLF'), findsOneWidget);
    // 今日の学習と、ホームの主ボタン「続きから解く」
    expect(find.text('今日の学習'), findsOneWidget);
    expect(find.text('目標 10問'), findsOneWidget);
    // ホームの縦のリスト（全冠ボードなどの中にもスクロールできる部品があるので、一番外側を指定する）
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('続きから解く'), 200, scrollable: list);
    expect(find.text('続きから解く'), findsOneWidget);
    // 問題のある試験は「解ける試験」の一覧に、問題数つきで出る
    final sapRow = find.text('本番形式 75問・一問一答 161問');
    await tester.scrollUntilVisible(sapRow, 100, scrollable: list);
    expect(sapRow, findsOneWidget);
  });
}
