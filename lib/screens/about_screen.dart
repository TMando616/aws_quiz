import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../support/report_mail.dart';

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
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(AppInfo.disclaimer, style: muted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(AppInfo.trademarkNotice, style: muted),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('お問い合わせ・誤りの報告'),
            onTap: () => ReportMail.contact(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('ライセンス'),
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
