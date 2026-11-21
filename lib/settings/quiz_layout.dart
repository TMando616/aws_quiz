import 'package:shared_preferences/shared_preferences.dart';

/// 問題画面のレイアウト
enum QuizLayout {
  /// 「問題」と「選択肢」をタブで分ける
  tabs('問題と選択肢を分ける'),

  /// 問題文を出したまま、選択肢だけを横にスワイプする
  swipeChoices('選択肢だけスワイプ');

  const QuizLayout(this.label);

  final String label;
}

/// 選んだレイアウトを端末に保存する（Laravelでいう、ユーザー設定を読み書きするリポジトリ）
class QuizLayoutSetting {
  static const _key = 'quiz_layout';

  Future<QuizLayout> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    return QuizLayout.values.firstWhere(
      (l) => l.name == name,
      orElse: () => QuizLayout.tabs,
    );
  }

  Future<void> save(QuizLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, layout.name);
  }
}
