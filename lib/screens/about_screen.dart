import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../support/report_mail.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_parts.dart';

/// 「このアプリについて」。注意書き・商標・プライバシーポリシー・問い合わせ・ライセンス
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (AppInfo.privacyPolicyUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('プライバシーポリシーのURLが未設定です')),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(AppInfo.privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.space5, t.space3, t.space5, t.space6),
        children: [
          Text(
            AppInfo.disclaimer,
            style: t.body.copyWith(color: t.textSecondary),
          ),
          SizedBox(height: t.space3),
          Text(
            AppInfo.trademarkNotice,
            style: t.body.copyWith(color: t.textSecondary),
          ),
          SizedBox(height: t.space6),
          ListRow(
            leading: Icon(Icons.privacy_tip_outlined, color: t.textSecondary),
            title: 'プライバシーポリシー',
            onTap: () => _openPrivacyPolicy(context),
          ),
          ListRow(
            leading: Icon(Icons.mail_outline, color: t.textSecondary),
            title: 'お問い合わせ・誤りの報告',
            onTap: () => ReportMail.contact(context),
          ),
          ListRow(
            leading: Icon(Icons.description_outlined, color: t.textSecondary),
            title: 'ライセンス',
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.appName,
            ),
          ),
        ],
      ),
    );
  }
}
