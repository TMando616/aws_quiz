import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/question.dart';

/// 問題データの読み込み担当。
/// 今はアプリ内のJSONから読むだけだが、将来サーバー（Supabaseなど）に変えるときもここだけ直せばよい。
class QuestionRepository {
  QuestionRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// [examId] の問題を読み込む。このアプリが対応していない種類の問題は除く
  Future<List<Question>> load(String examId) async {
    final raw = await _bundle.loadString('assets/questions/$examId.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['questions'] as List;
    return list
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .where((q) => Question.supportedTypes.contains(q.type))
        .toList();
  }
}
