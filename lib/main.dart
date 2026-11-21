import 'package:material_ui/material_ui.dart';

import 'ads/ad_consent.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // runApp前にプラグイン（ネイティブ側）を使うときに必要
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  // 最初の画面が出てから、同意の確認と広告SDKの初期化を行う
  // （同意画面やATTのダイアログは、画面が表示されていないと出せないため）
  WidgetsBinding.instance.addPostFrameCallback((_) => AdConsent.gather());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // アプリ名に「AWS」を前面に出さない（商標の都合）
      title: 'クラウド認定 学習',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode, // 端末の設定に合わせてダークモードに切り替える
      home: const HomeScreen(),
    );
  }
}

/// 通常は端末の設定に合わせる。開発中の画面確認では
/// `--dart-define=THEME=dark`（または light）でテーマを固定できる
ThemeMode get _themeMode => switch (const String.fromEnvironment('THEME')) {
  'dark' => ThemeMode.dark,
  'light' => ThemeMode.light,
  _ => ThemeMode.system,
};
