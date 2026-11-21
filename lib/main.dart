import 'package:material_ui/material_ui.dart';

import 'screens/quiz_screen.dart';

void main() {
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
