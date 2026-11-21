import 'dart:io';

/// 広告まわりの設定を1か所にまとめる（Laravelの config/ads.php のようなもの）
///
/// 今はGoogle公式のテスト用広告ユニットIDを使っている。
/// AdMobで本番の広告ユニットを作ったら、ここのIDだけ差し替える。
/// ※ 開発中に本番IDで自分の広告を表示・クリックすると規約違反になるので、
///   本番IDへの切り替えはリリース直前に行う。
class AdConfig {
  AdConfig._();

  /// falseにすると広告も同意画面も出さない。
  /// テスト（広告SDKが動かない）や、開発中の画面確認で使う。
  /// `flutter run --dart-define=ADS=false` でも切り替えられる
  static bool enabled = const bool.fromEnvironment('ADS', defaultValue: true);

  /// 画面下に常に出すバナー
  static String get bannerUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/9214589741'
      : 'ca-app-pub-3940256099942544/2435281174';

  /// 結果画面に進むときに出す全画面広告
  static String get interstitialUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';
}
