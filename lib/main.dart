import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/quiz_screen.dart';

void main() {
  // runApp前にプラグイン（ネイティブ側）を使うときに必要
  WidgetsFlutterBinding.ensureInitialized();
  // 広告SDKの初期化。完了を待たずに画面を出す（広告は読み込めた時点で表示される）
  MobileAds.instance.initialize();
  runApp(const MyApp());
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
