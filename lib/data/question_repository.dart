import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/question.dart';

/// 問題データの読み込み担当。
/// 今はアプリ内のJSONから読むだけだが、将来APIに変えるときもここだけ直せばよい。
class QuestionRepository {
  Future<List<Question>> load(String exam) async {
    final raw =
        await rootBundle.loadString('assets/questions/${exam.toLowerCase()}.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['questions'] as List;
    return list
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
