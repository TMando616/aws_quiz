import 'package:material_ui/material_ui.dart';

import 'ads/ad_consent.dart';
import 'screens/quiz_screen.dart';

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
      title: 'AWS SAP 一問一答',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const QuizScreen(exam: 'SAP'),
    );
  }
}
