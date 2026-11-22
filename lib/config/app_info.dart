/// アプリの基本情報（Laravelの config/app.php のようなもの）
///
/// リリース前に [supportEmail] と [privacyPolicyUrl] を埋める。
/// 空のままだと、報告ボタンやプライバシーポリシーのリンクは「未設定」と表示する。
class AppInfo {
  AppInfo._();

  static const appName = 'CertStack';

  /// 問題の誤りの報告や問い合わせを受けるメールアドレス
  static const supportEmail = '';

  /// 公開したプライバシーポリシーのURL（下書きは docs/privacy_policy.md）
  static const privacyPolicyUrl = '';

  /// 解説の下と「このアプリについて」に出す注意書き
  static const disclaimer =
      '問題と解説は公式ドキュメントをもとに独自に作成したものです。内容の正確性は保証できません。'
      '最新の情報は根拠のリンク先で確認してください。';

  /// 提携していないことと商標の免責文（ストアの説明文にも同じ文を入れる）。
  /// AWSの商標ガイドラインで、提携や承認を暗示する使い方が禁止されているため
  static const trademarkNotice =
      '本アプリはAmazon Web Services, Inc.とは提携していません。'
      'AWSおよびAWS認定はAmazon.com, Inc.またはその関連会社の商標です。';
}
