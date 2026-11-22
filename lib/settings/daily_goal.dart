import 'package:shared_preferences/shared_preferences.dart';

/// 1日の目標の問題数を端末に保存する（Laravelでいう、ユーザー設定を読み書きするリポジトリ）
class DailyGoalSetting {
  static const _key = 'daily_goal';

  /// 選べる目標の問題数
  static const choices = [5, 10, 20, 30, 50];

  /// まだ選んでいなければ null（画面側で DESIGN.md の `dailyGoal` を使う）
  Future<int?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key);
  }

  Future<void> save(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, goal);
  }
}
