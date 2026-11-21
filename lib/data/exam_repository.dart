import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exam.dart';

/// 試験の一覧（assets/exams.json）の読み込み担当
class ExamRepository {
  ExamRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// 受験できる試験の一覧。終了日を過ぎた試験は外す
  /// （アプリを更新しなくても、終了した試験が一覧から消えるようにするため）
  Future<List<Exam>> loadAll({DateTime? now}) async {
    final raw = await _bundle.loadString('assets/exams.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final today = now ?? DateTime.now();
    return (data['exams'] as List)
        .map((e) => Exam.fromJson(e as Map<String, dynamic>))
        .where((e) => e.isOpenOn(today))
        .toList();
  }

  /// 問題ファイル（`assets/questions/<id>.json`）がある試験のIDの一覧。
  /// ファイルが無い試験はホームで「準備中」と表示する
  Future<Set<String>> examIdsWithQuestions() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final pattern = RegExp(r'^assets/questions/([a-z0-9_-]+)\.json$');
    return {
      for (final path in manifest.listAssets())
        if (pattern.firstMatch(path) case final m?) m.group(1)!,
    };
  }
}
