import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';

/// メールアプリを開いて、問題の誤りの報告や問い合わせを送ってもらう。
/// サーバーを持たずに済み、利用者が送るかどうかを自分で決められる
class ReportMail {
  ReportMail._();

  /// 問題の誤りの報告。どの問題かが分かるように、IDと問題文の冒頭を本文に入れておく
  static Future<void> reportQuestion(
    BuildContext context, {
    required String questionId,
    required String questionText,
  }) {
    final head = questionText.length > 60
        ? '${questionText.substring(0, 60)}…'
        : questionText;
    return _open(
      context,
      subject: '問題の誤りの報告（$questionId）',
      body:
          '問題ID: $questionId\n問題文: $head\n\n'
          '誤りだと思う箇所と、その理由（根拠のURLがあれば）を書いてください。\n\n',
    );
  }

  static Future<void> contact(BuildContext context) =>
      _open(context, subject: '${AppInfo.appName} へのお問い合わせ', body: '');

  static Future<void> _open(
    BuildContext context, {
    required String subject,
    required String body,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (AppInfo.supportEmail.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('報告先のメールアドレスが未設定です')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: AppInfo.supportEmail,
      // queryParameters だと空白が + になるため、自分でエンコードする
      query:
          'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
    final ok = await launchUrl(uri);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('メールアプリを開けませんでした')));
    }
  }
}
