import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../ads/ad_consent.dart';
import '../config/app_info.dart';
import '../data/certification_repository.dart';
import '../data/exam_repository.dart';
import '../data/question_repository.dart';
import '../data/study_repository.dart';
import '../logic/continue_order.dart';
import '../logic/mock_builder.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../settings/daily_goal.dart';
import '../theme/app_tokens.dart';
import '../widgets/certification_board.dart';
import '../widgets/design_parts.dart';
import '../widgets/explanation_view.dart';
import '../widgets/related_questions_buttons.dart';
import 'about_screen.dart';
import 'exam_screen.dart';
import 'mock_result_screen.dart';
import 'mock_screen.dart';
import 'quiz_screen.dart';

/// ホーム。全冠ボード（全試験と取得済みの印）、今日の学習、解ける試験の順に並べる
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// ホームに出す1試験分の情報
class _ExamSummary {
  const _ExamSummary(
    this.exam,
    this.questionCount,
    this.accuracy, {
    this.drillCount = 0,
  });

  final Exam exam;

  /// 収録している問題数。null なら問題ファイルが無い（準備中）
  /// 本番形式の問題数（問題ファイルが無ければ null）
  final int? questionCount;

  /// 一問一答の問題数
  final int drillCount;

  /// この試験の正答率
  final Accuracy accuracy;

  bool get ready => (questionCount ?? 0) > 0;
}

/// 「続きから解く」で始める一問一答
class _ContinueTarget {
  const _ContinueTarget(
    this.exam,
    this.questions, {
    required this.unansweredCount,
    required this.wrongCount,
  });

  final Exam exam;

  /// 未回答 → 不正解 → 正解 の順に並べた一問一答
  final List<Question> questions;
  final int unansweredCount;

  /// 最新の回答が不正解の問題の数
  final int wrongCount;

  /// ボタンの下に出す補足（どこから始まるか）
  String get caption {
    final from = unansweredCount > 0
        ? '未回答 $unansweredCount問から'
        : wrongCount > 0
        ? '間違えた $wrongCount問から'
        : '全問正解済み・最初から';
    return '${exam.shortName} の一問一答・$from';
  }
}

class _HomeData {
  const _HomeData(
    this.summaries,
    this.certified,
    this.activity, {
    this.continueTarget,
    this.goal,
  });

  /// 続きから解く一問一答。一問一答のある試験が無ければ null
  final _ContinueTarget? continueTarget;

  /// 1日の目標の問題数。まだ選んでいなければ null（DESIGN.md の `dailyGoal` を使う）
  final int? goal;

  final List<_ExamSummary> summaries;

  /// 今日の回答数と連続日数
  final DailyActivity activity;

  /// 取得済みの試験ID → 印をつけた日
  final Map<String, DateTime> certified;
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;
  final _certRepo = CertificationRepository();
  final _goalSetting = DailyGoalSetting();
  Map<String, DateTime> _certified = {};

  /// 取得済みの印を付け外しした回数。読み込み中に印を変えたら、読み込んだ古い値で上書きしないために使う
  int _certVersion = 0;
  bool _privacyOptionsRequired = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (kDebugMode && _debugRoute.isNotEmpty) _future.then(_openDebugRoute);
    _checkPrivacyOptions();
  }

  Future<void> _checkPrivacyOptions() async {
    await AdConsent.ready;
    final required = await AdConsent.isPrivacyOptionsRequired();
    if (mounted) setState(() => _privacyOptionsRequired = required);
  }

  /// 開発用：起動後に自動で画面を進める（シミュレーターの画面確認用。デバッグビルドだけで効く）
  /// `--dart-define=DEBUG_ROUTE=exam` で試験トップ、`quiz` で出題画面、`explanation` で解説、`explanation-end` で解説の末尾、`mock` で模試、`mock-result` で模試の結果、`about` で「このアプリについて」、`exam-studied` で回答の記録を入れてから試験トップ（レーダーチャートの確認用）、`drill` で一問一答まで進む（`drill-answered` はさらに1問目に自動で回答する。`quiz-selected` は出題画面で1問目の A を選んだ状態にする）
  static const _debugRoute = String.fromEnvironment('DEBUG_ROUTE');
  static const _debugCertified = String.fromEnvironment('DEBUG_CERTIFIED');

  /// 開発用（`DEBUG_ROUTE=exam-studied`）：分野ごとに正答率が違う回答の記録を入れる。
  /// レーダーチャートと「間違えた問題だけ解き直す」の見た目の確認に使う。記録はシミュレーターに残る
  Future<void> _seedDebugAnswers(Exam exam) async {
    final repo = await StudyRepository.instance();
    final questions = await QuestionRepository().load(exam.id);
    for (final (i, domain) in exam.domains.indexed) {
      final inDomain = questions.where((q) => q.domainId == domain.id).take(10);
      // 分野1は9割、分野2は3割…と、分野ごとに正答率を変える
      final correctCount = [9, 3, 7, 5, 8, 6][i % 6];
      for (final (j, q) in inDomain.indexed) {
        await repo.recordAnswer(
          examId: exam.id,
          questionId: q.id,
          correct: j < correctCount,
          mode: StudyMode.practice,
        );
      }
    }
  }

  Future<void> _openDebugRoute(_HomeData data) async {
    if (_debugRoute == 'drill' || _debugRoute == 'drill-answered') {
      return _openDebugDrill(data);
    }
    final target = data.summaries
        .where((s) => (s.questionCount ?? 0) > 0)
        .firstOrNull;
    if (target == null || !mounted) return;
    final navigator = Navigator.of(context);
    if (_debugRoute == 'about') {
      navigator.push(MaterialPageRoute(builder: (_) => const AboutScreen()));
      return;
    }
    if (_debugRoute == 'exam-studied') await _seedDebugAnswers(target.exam);
    navigator.push(
      MaterialPageRoute(builder: (_) => ExamScreen(exam: target.exam)),
    );
    if (_debugRoute == 'explanation' || _debugRoute == 'explanation-end') {
      // 類題のある最初の問題（無ければ1問目）で、不正解の選択肢のうち最初のものを選んだときの解説
      final all = await QuestionRepository().load(target.exam.id);
      final q = all.firstWhere((q) => q.group != null, orElse: () => all.first);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('解説の確認（開発用）')),
            body: SingleChildScrollView(
              // reverse にすると、並び順はそのままで末尾までスクロールした状態で開く
              reverse: _debugRoute == 'explanation-end',
              padding: EdgeInsets.fromLTRB(
                context.tokens.space5,
                0,
                context.tokens.space5,
                context.tokens.space6,
              ),
              child: ExplanationView(
                action: RelatedQuestionsButtons(exam: target.exam, question: q),
                question: q,
                selected: {
                  [for (var i = 0; i < q.choices.length; i++) i]
                      .firstWhere((i) => !q.answers.contains(i)),
                },
              ),
            ),
          ),
        ),
      );
    }
    if (_debugRoute == 'mock' || _debugRoute == 'mock-result') {
      final questions = await QuestionRepository().load(target.exam.id);
      final set = buildMockSet(target.exam, questions);
      if (_debugRoute == 'mock') {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => MockScreen(exam: target.exam, mockSet: set),
          ),
        );
      } else {
        // 1問目だけAを選び、残りは未回答にした結果
        final selections = {
          0: {0},
        };
        navigator.push(
          MaterialPageRoute(
            builder: (_) => MockResultScreen(
              exam: target.exam,
              result: gradeMock(
                examId: target.exam.id,
                questions: set.questions,
                selections: selections,
                startedAt: DateTime.now(),
                duration: const Duration(minutes: 4, seconds: 12),
              ),
              questions: set.questions,
              selections: selections,
            ),
          ),
        );
      }
    }
    if (_debugRoute == 'quiz' || _debugRoute == 'quiz-selected') {
      final questions = await QuestionRepository().load(target.exam.id);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            exam: target.exam,
            questions: questions.where((q) => !q.isDrill).toList(),
            title: '全分野',
            debugAutoAnswer: _debugRoute == 'quiz-selected',
          ),
        ),
      );
    }
  }

  /// 開発用：一問一答のある最初の試験で、一問一答を始める
  Future<void> _openDebugDrill(_HomeData data) async {
    final target = data.summaries.where((s) => s.drillCount > 0).firstOrNull;
    if (target == null || !mounted) return;
    final navigator = Navigator.of(context);
    final questions = await QuestionRepository().load(target.exam.id);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          exam: target.exam,
          questions: questions.where((q) => q.isDrill).toList(),
          title: '一問一答',
          debugAutoAnswer: _debugRoute == 'drill-answered',
        ),
      ),
    );
  }

  Future<_HomeData> _load() async {
    final examRepo = ExamRepository();
    final questionRepo = QuestionRepository();
    final exams = await examRepo.loadAll();
    final available = await examRepo.examIdsWithQuestions();

    StudyRepository? study;
    try {
      study = await StudyRepository.instance();
    } catch (e) {
      debugPrint('学習記録を開けませんでした: $e');
    }

    final summaries = <_ExamSummary>[];
    final questionsByExam = <String, List<Question>>{};
    for (final exam in exams) {
      if (!available.contains(exam.id)) {
        summaries.add(_ExamSummary(exam, null, Accuracy.empty));
        continue;
      }
      final questions = await questionRepo.load(exam.id);
      questionsByExam[exam.id] = questions;
      final accuracy =
          await study?.accuracyOfExam(exam.id, questions) ?? Accuracy.empty;
      final drillCount = questions.where((q) => q.isDrill).length;
      summaries.add(
        _ExamSummary(
          exam,
          questions.length - drillCount,
          accuracy,
          drillCount: drillCount,
        ),
      );
    }
    final versionAtStart = _certVersion;
    var certified = await _certRepo.load();
    // 開発用：`--dart-define=DEBUG_CERTIFIED=clf,saa` で取得済みの見た目を確かめる（保存はしない）
    if (kDebugMode && _debugCertified.isNotEmpty) {
      certified = {
        ...certified,
        for (final id in _debugCertified.split(',')) id: DateTime.now(),
      };
    }
    if (versionAtStart == _certVersion) _certified = certified;
    var activity = DailyActivity.empty;
    try {
      activity = await study?.dailyActivity() ?? DailyActivity.empty;
    } catch (e) {
      debugPrint('今日の学習を集計できませんでした: $e');
    }

    // 続きから解く：最後に解いた試験（まだ無ければ、一問一答のある最初の試験）
    _ContinueTarget? continueTarget;
    try {
      final lastId = await study?.lastExamId();
      final withDrills = summaries.where((s) => s.drillCount > 0);
      final target =
          withDrills.where((s) => s.exam.id == lastId).firstOrNull ??
          withDrills.firstOrNull;
      if (target != null) {
        final drills = questionsByExam[target.exam.id]!
            .where((q) => q.isDrill)
            .toList();
        final latest = await study?.latestResults(target.exam.id) ?? {};
        continueTarget = _ContinueTarget(
          target.exam,
          orderForContinue(drills, latest),
          unansweredCount: drills
              .where((q) => !latest.containsKey(q.id))
              .length,
          wrongCount: drills.where((q) => latest[q.id] == false).length,
        );
      }
    } catch (e) {
      debugPrint('続きから解く問題を用意できませんでした: $e');
    }

    // 保存した目標が読めなくても、ホームは出す（初期値の目標を使う）
    int? goal;
    try {
      goal = await _goalSetting.load();
    } catch (e) {
      debugPrint('1日の目標を読み込めませんでした: $e');
    }
    return _HomeData(
      summaries,
      _certified,
      activity,
      continueTarget: continueTarget,
      goal: goal,
    );
  }

  Future<void> _toggleCertified(Exam exam) async {
    _certVersion++;
    final next = !_certified.containsKey(exam.id);
    final updated = await _certRepo.set(exam.id, next);
    if (mounted) setState(() => _certified = updated);
  }

  Future<void> _openExam(Exam exam) =>
      _pushAndReload(MaterialPageRoute(builder: (_) => ExamScreen(exam: exam)));

  Future<void> _continue(_ContinueTarget target) => _pushAndReload(
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        exam: target.exam,
        questions: target.questions,
        title: '一問一答',
        backLabel: 'ホームに戻る',
      ),
    ),
  );

  /// 画面を開き、戻ってきたら読み直す（正答率・今日の問題数・取得済みの印が変わっているかもしれないため）
  Future<void> _pushAndReload(Route<void> route) async {
    await Navigator.of(context).push(route);
    _reload();
  }

  void _reload() {
    // アロー関数だと Future を返してしまい setState が例外になるので、ブロックで書く
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  /// 1日の目標の問題数を選ぶシート
  Future<void> _pickGoal(int current) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final t = context.tokens;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(t.space5, 0, t.space5, t.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('1日の目標'),
                for (final goal in DailyGoalSetting.choices)
                  ListRow(
                    title: '$goal問',
                    titleStyle: t.numeric(t.body),
                    showChevron: false,
                    trailing: goal == current
                        ? Icon(Icons.check, color: t.ink)
                        : null,
                    onTap: () => Navigator.of(context).pop(goal),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || picked == current) return;
    await _goalSetting.save(picked);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppInfo.appName),
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                child: const Text('このアプリについて'),
              ),
              if (_privacyOptionsRequired)
                const PopupMenuItem(
                  onTap: AdConsent.showPrivacyOptions,
                  child: Text('広告のプライバシー設定'),
                ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('試験の一覧を読み込めませんでした\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summaries = snapshot.data!.summaries;
          final t = context.tokens;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              t.space5,
              t.space3,
              t.space5,
              t.space7,
            ),
            children: [
              // 全冠を目指すアプリなので、全試験と取得済みの印を一番上に置く
              CertificationBoard(
                exams: [for (final s in summaries) s.exam],
                certified: _certified.keys.toSet(),
                onToggle: _toggleCertified,
              ),
              SizedBox(height: t.space6),
              _TodayActivity(
                activity: snapshot.data!.activity,
                goal: snapshot.data!.goal ?? t.dailyGoal,
                continueTarget: snapshot.data!.continueTarget,
                onPickGoal: _pickGoal,
                onContinue: _continue,
              ),
              // 問題を解く入口。問題を収録している試験だけ並べる（ほかの試験はボードに出ている）
              const _LevelHeader('解ける試験'),
              for (final s in summaries.where((s) => s.ready))
                _ExamCard(summary: s, onTap: () => _openExam(s.exam)),
              SizedBox(height: t.space6),
              Text(AppInfo.trademarkNotice, style: t.caption),
            ],
          );
        },
      ),
    );
  }
}

/// 今日の学習。回答数と連続日数、1日の目標に対する進み具合
class _TodayActivity extends StatelessWidget {
  const _TodayActivity({
    required this.activity,
    required this.goal,
    required this.continueTarget,
    required this.onPickGoal,
    required this.onContinue,
  });

  final DailyActivity activity;
  final int goal;
  final _ContinueTarget? continueTarget;
  final ValueChanged<int> onPickGoal;
  final ValueChanged<_ContinueTarget> onContinue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final target = continueTarget;
    final count = activity.todayCount;
    final numberStyle = t.numeric(t.title);
    final unitStyle = t.body.copyWith(fontWeight: FontWeight.w700);
    // カードにせず、背景の上に数字とバーを直接置く（カードは問題のカードだけ）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('今日の学習', style: t.label)),
            // タップで目標の問題数を変える
            TextButton.icon(
              onPressed: () => onPickGoal(goal),
              // 右端を下の数字の右端に揃える（高さはタップの的として残す）
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(0, t.tapTarget),
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.expand_more),
              label: Text('目標 $goal問', style: t.numeric(t.label)),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$count', style: numberStyle),
                    TextSpan(text: ' 問', style: unitStyle),
                  ],
                ),
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${activity.streakDays}', style: numberStyle),
                  TextSpan(text: ' 日連続', style: unitStyle),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: t.space2),
        ThinBar(value: count / goal),
        SizedBox(height: t.space2),
        Text(
          count >= goal ? '今日の目標に到達' : '目標まで あと ${goal - count}問',
          style: t.numeric(t.caption),
        ),
        // ホームの主ボタン。通勤で開いて、すぐ解き始められるように
        if (target != null) ...[
          SizedBox(height: t.space4),
          FilledButton(
            onPressed: () => onContinue(target),
            child: const Text('続きから解く'),
          ),
          SizedBox(height: t.space2),
          Text(
            target.caption,
            style: t.numeric(t.caption),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space6),
      child: SectionLabel(label),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.summary, required this.onTap});

  final _ExamSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final exam = summary.exam;
    final ready = summary.ready;
    final rate = summary.accuracy.rate;

    final retire = exam.retireDate;
    // 補足は意味の切れ目で最初から2行に分ける（成り行きの折り返しで「問」だけ次の行に落ちないように）
    // 1行目：レベル・正答率・終了予定、2行目：問題数
    final statusLines = [
      [
        if (ready) exam.level.label,
        if (rate != null) '正答率 ${(rate * 100).round()}%',
        if (exam.isRetiring && retire != null)
          '${retire.year}年${retire.month}月で終了',
      ].join('・'),
      [
        if (ready) '本番形式 ${summary.questionCount}問',
        if (summary.drillCount > 0) '一問一答 ${summary.drillCount}問',
      ].join('・'),
    ].where((line) => line.isNotEmpty).toList();

    // 準備中の試験は、透明にせず文字色を控えめにする（取得済みの印だけは付けられる）
    final nameColor = ready ? t.textPrimary : t.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: t.tapTarget),
        padding: EdgeInsets.symmetric(vertical: t.space3),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.hairline, width: t.borderThin),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: t.space7,
              child: Text(
                exam.shortName,
                style: t.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: nameColor,
                ),
              ),
            ),
            SizedBox(width: t.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // レベル（アソシエイトなど）は見出しや試験コードで分かるので、名前の前半だけにして折り返しを防ぐ
                  Text(
                    exam.nameJa.split(' - ').first,
                    style: t.body.copyWith(color: nameColor),
                  ),
                  for (final line in statusLines) Text(line, style: t.caption),
                ],
              ),
            ),
            SizedBox(width: t.space2),
            Icon(Icons.chevron_right, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}
