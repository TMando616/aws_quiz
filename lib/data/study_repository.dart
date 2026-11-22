import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';

/// 出題のモード。回答の記録に残す
/// 回答したときのモード。practice=本番形式の練習、drill=一問一答、mock=模試
enum StudyMode { practice, drill, mock }

/// 正答率の集計結果
class Accuracy {
  const Accuracy({required this.answered, required this.correct});

  /// 1回以上解いた問題の数
  final int answered;

  /// そのうち、最新の回答が正解だった問題の数
  final int correct;

  /// 正答率（0.0〜1.0）。まだ解いていなければ null
  double? get rate => answered == 0 ? null : correct / answered;

  static const empty = Accuracy(answered: 0, correct: 0);
}

/// 日ごとの学習の様子（ホームの「今日の学習」に使う）
class DailyActivity {
  const DailyActivity({required this.todayCount, required this.streakDays});

  /// 今日回答した数（同じ問題を解き直した分も数える）
  final int todayCount;

  /// 何日続けて解いているか。今日まだ解いていなくても、昨日まで続いていれば途切れていない扱いにする
  /// （朝の時点で「0日」に戻ると、続ける気がなくなるため）
  final int streakDays;

  static const empty = DailyActivity(todayCount: 0, streakDays: 0);
}

/// 模試1回分の結果
class MockResult {
  const MockResult({
    required this.examId,
    required this.takenAt,
    required this.questionCount,
    required this.correctCount,
    required this.duration,
    required this.byDomain,
  });

  final String examId;
  final DateTime takenAt;
  final int questionCount;
  final int correctCount;
  final Duration duration;

  /// 分野ID → その分野の出題数と正解数（未回答は不正解として数える）
  final Map<String, Accuracy> byDomain;

  double get rate => questionCount == 0 ? 0 : correctCount / questionCount;
}

/// 学習記録の保存担当（端末内のSQLite）。Laravelでいうリポジトリ層
///
/// テーブル
/// - answers: 1回答ごとの記録（問題ID・正誤・モード・日時）
/// - mock_results: 模試1回ごとの結果
///
/// 正答率は「各問題の最新の回答」で計算する。
/// 一度間違えた問題も、解き直して正解すれば正答率に反映される。
class StudyRepository {
  StudyRepository._(this._db);

  final Database _db;

  static StudyRepository? _instance;

  /// アプリ全体で1つのDB接続を使い回す
  static Future<StudyRepository> instance() async {
    final existing = _instance;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final repo = await open(p.join(dir, 'study.db'));
    return _instance = repo;
  }

  /// [path] のDBを開く（テストでは inMemoryDatabasePath を渡す）
  static Future<StudyRepository> open(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Laravelのマイグレーションにあたる部分。
        // 列を足すときは version を上げて onUpgrade に ALTER TABLE を書く
        await db.execute('''
          CREATE TABLE answers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id TEXT NOT NULL,
            question_id TEXT NOT NULL,
            correct INTEGER NOT NULL,
            mode TEXT NOT NULL,
            answered_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_answers_exam_question ON answers (exam_id, question_id)',
        );
        await db.execute('''
          CREATE TABLE mock_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id TEXT NOT NULL,
            taken_at INTEGER NOT NULL,
            question_count INTEGER NOT NULL,
            correct_count INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL,
            domain_json TEXT NOT NULL
          )
        ''');
      },
    );
    return StudyRepository._(db);
  }

  /// テスト用：使い回しているDB接続を差し替える
  static void debugSetInstance(StudyRepository? repo) => _instance = repo;

  Future<void> close() => _db.close();

  /// 1問の回答を記録する
  Future<void> recordAnswer({
    required String examId,
    required String questionId,
    required bool correct,
    required StudyMode mode,
    DateTime? at,
  }) async {
    await _db.insert('answers', {
      'exam_id': examId,
      'question_id': questionId,
      'correct': correct ? 1 : 0,
      'mode': mode.name,
      'answered_at': (at ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  /// 問題ID → 最新の回答が正解だったか
  Future<Map<String, bool>> latestResults(String examId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT question_id, correct FROM answers
      WHERE id IN (
        SELECT MAX(id) FROM answers WHERE exam_id = ? GROUP BY question_id
      )
      ''',
      [examId],
    );
    return {
      for (final r in rows) r['question_id'] as String: r['correct'] == 1,
    };
  }

  /// 分野ID → 正答率。分野は「今の問題データの分野」で集計する
  /// （あとから問題の分野を付け替えても、集計がズレないようにするため）
  Future<Map<String, Accuracy>> accuracyByDomain(
    String examId,
    List<Question> questions,
  ) async {
    final latest = await latestResults(examId);
    final answered = <String, int>{};
    final correct = <String, int>{};
    for (final q in questions) {
      final result = latest[q.id];
      if (result == null) continue;
      answered.update(q.domainId, (v) => v + 1, ifAbsent: () => 1);
      if (result) correct.update(q.domainId, (v) => v + 1, ifAbsent: () => 1);
    }
    return {
      for (final id in answered.keys)
        id: Accuracy(answered: answered[id]!, correct: correct[id] ?? 0),
    };
  }

  /// 試験全体の正答率（今の問題データに含まれる問題だけで集計）
  Future<Accuracy> accuracyOfExam(
    String examId,
    List<Question> questions,
  ) async {
    final byDomain = await accuracyByDomain(examId, questions);
    var answered = 0;
    var correct = 0;
    for (final a in byDomain.values) {
      answered += a.answered;
      correct += a.correct;
    }
    return Accuracy(answered: answered, correct: correct);
  }

  /// 最後に回答した試験のID（まだ1問も解いていなければ null）
  Future<String?> lastExamId() async {
    final rows = await _db.query(
      'answers',
      columns: ['exam_id'],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['exam_id'] as String;
  }

  /// 今日の回答数と、連続して解いた日数
  Future<DailyActivity> dailyActivity({DateTime? now}) async {
    // 日付は端末のタイムゾーンで区切る（SQLite の localtime と Dart の DateTime は同じ設定を使う）
    final rows = await _db.rawQuery('''
      SELECT date(answered_at / 1000, 'unixepoch', 'localtime') AS day,
             COUNT(*) AS count
      FROM answers GROUP BY day
    ''');
    final counts = {
      for (final r in rows) r['day'] as String: r['count'] as int,
    };

    final today = now ?? DateTime.now();
    String keyOf(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    DateTime dayBefore(DateTime d) => DateTime(d.year, d.month, d.day - 1);

    final todayCount = counts[keyOf(today)] ?? 0;
    // 今日解いていれば今日から、まだなら昨日からさかのぼって数える
    var day = todayCount > 0 ? today : dayBefore(today);
    var streak = 0;
    while (counts.containsKey(keyOf(day))) {
      streak++;
      day = dayBefore(day);
    }
    return DailyActivity(todayCount: todayCount, streakDays: streak);
  }

  /// 模試の結果を保存する
  Future<void> saveMockResult(MockResult result) async {
    await _db.insert('mock_results', {
      'exam_id': result.examId,
      'taken_at': result.takenAt.millisecondsSinceEpoch,
      'question_count': result.questionCount,
      'correct_count': result.correctCount,
      'duration_seconds': result.duration.inSeconds,
      'domain_json': jsonEncode({
        for (final e in result.byDomain.entries)
          e.key: {'answered': e.value.answered, 'correct': e.value.correct},
      }),
    });
  }

  /// 模試の結果を新しい順に取得する
  Future<List<MockResult>> mockResults(String examId, {int limit = 20}) async {
    final rows = await _db.query(
      'mock_results',
      where: 'exam_id = ?',
      whereArgs: [examId],
      orderBy: 'taken_at DESC, id DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        MockResult(
          examId: r['exam_id'] as String,
          takenAt: DateTime.fromMillisecondsSinceEpoch(r['taken_at'] as int),
          questionCount: r['question_count'] as int,
          correctCount: r['correct_count'] as int,
          duration: Duration(seconds: r['duration_seconds'] as int),
          byDomain: {
            for (final e in (jsonDecode(
              r['domain_json'] as String,
            ) as Map<String, dynamic>).entries)
              e.key: Accuracy(
                answered: (e.value as Map<String, dynamic>)['answered'] as int,
                correct: (e.value as Map<String, dynamic>)['correct'] as int,
              ),
          },
        ),
    ];
  }
}
