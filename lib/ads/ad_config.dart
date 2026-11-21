import 'dart:io';

/// 広告まわりの設定を1か所にまとめる（Laravelの config/ads.php のようなもの）
///
/// 広告ユニットIDは、ビルド時に `--dart-define` で渡す（Laravelの .env のようなもの）。
/// 渡さなければGoogle公式のテスト用IDを使うので、開発中は何も指定しなくてよい。
///
/// リリースビルドの例:
/// ```
/// flutter build ipa \
///   --dart-define=ADMOB_BANNER_IOS=ca-app-pub-xxxx/yyyy \
///   --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-xxxx/zzzz
/// ```
/// ※ 開発中に本番IDで自分の広告を表示・クリックすると規約違反になるので、
///   本番IDはリリースビルドのときだけ渡す。
/// ※ アプリID（`~` の付くID）は Info.plist と AndroidManifest.xml に直接書く。
class AdConfig {
  AdConfig._();

  /// falseにすると広告も同意画面も出さない。
  /// テスト（広告SDKが動かない）や、開発中の画面確認で使う。
  /// `flutter run --dart-define=ADS=false` でも切り替えられる
  static bool enabled = const bool.fromEnvironment('ADS', defaultValue: true);

  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2435281174',
  );
  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );
  static const _interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// 画面下に常に出すバナー
  static String get bannerUnitId =>
      Platform.isAndroid ? _bannerAndroid : _bannerIos;

  /// 結果画面に進むときに出す全画面広告
  static String get interstitialUnitId =>
      Platform.isAndroid ? _interstitialAndroid : _interstitialIos;
}
