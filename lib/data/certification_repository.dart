import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 「取得済み」の試験の保存担当。試験ID → 印をつけた日
///
/// 小さな設定なので、学習記録のSQLiteではなく shared_preferences に置く
class CertificationRepository {
  static const _key = 'certified_exams';

  Future<Map<String, DateTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in map.entries) e.key: DateTime.parse(e.value as String),
    };
  }

  /// [certified] が true なら今日の日付で印をつけ、false なら外す
  Future<Map<String, DateTime>> set(String examId, bool certified) async {
    final current = await load();
    if (certified) {
      current[examId] = DateTime.now();
    } else {
      current.remove(examId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final e in current.entries) e.key: e.value.toIso8601String(),
      }),
    );
    return current;
  }
}
