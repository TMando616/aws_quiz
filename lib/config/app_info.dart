/// アプリの基本情報（Laravelの config/app.php のようなもの）
///
/// リリース前に [supportEmail] と [privacyPolicyUrl] を埋める。
/// 空のままだと、報告ボタンやプライバシーポリシーのリンクは「未設定」と表示する。
class AppInfo {
  AppInfo._();

  static const appName = 'クラウド認定 学習';

  /// 問題の誤りの報告や問い合わせを受けるメールアドレス
  static const supportEmail = '';

  /// 公開したプライバシーポリシーのURL（下書きは docs/privacy_policy.md）
  static const privacyPolicyUrl = '';

  /// 解説の下と「このアプリについて」に出す注意書き
  static const disclaimer =
      '問題と解説は公式ドキュメントをもとに独自に作成したものです。内容の正確性は保証できません。'
      '最新の情報は根拠のリンク先で確認してください。';

  /// 商標と、公式のアプリではないことの表記
  static const trademarkNotice =
      'AWS、Amazon Web Services および関連するサービス名は、Amazon.com, Inc. またはその関連会社の商標です。'
      'このアプリは個人が開発したもので、Amazon Web Services とは関係ありません。';
}
