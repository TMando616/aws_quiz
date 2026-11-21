import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../ads/ad_consent.dart';
import '../config/app_info.dart';
import '../data/certification_repository.dart';
import '../data/exam_repository.dart';
import '../data/question_repository.dart';
import '../data/study_repository.dart';
import '../logic/mock_builder.dart';
import '../models/exam.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_parts.dart';
import '../widgets/explanation_view.dart';
import '../widgets/related_questions_buttons.dart';
import 'about_screen.dart';
import 'exam_screen.dart';
import 'mock_result_screen.dart';
import 'mock_screen.dart';
import 'quiz_screen.dart';

/// ホーム。全冠への進捗と、全試験をレベル別に並べる
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

class _HomeData {
  const _HomeData(this.summaries, this.certified);

  final List<_ExamSummary> summaries;

  /// 取得済みの試験ID → 印をつけた日
  final Map<String, DateTime> certified;
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;
  final _certRepo = CertificationRepository();
  Map<String, DateTime> _certified = {};
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
  /// `--dart-define=DEBUG_ROUTE=exam` で試験トップ、`quiz` で出題画面、`explanation` で解説、`explanation-end` で解説の末尾、`mock` で模試、`mock-result` で模試の結果、`about` で「このアプリについて」、`drill` で一問一答まで進む（`drill-answered` はさらに1問目に自動で回答する）
  static const _debugRoute = String.fromEnvironment('DEBUG_ROUTE');

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
    if (_debugRoute == 'quiz') {
      final questions = await QuestionRepository().load(target.exam.id);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            exam: target.exam,
            questions: questions.where((q) => !q.isDrill).toList(),
            title: '全分野',
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
    for (final exam in exams) {
      if (!available.contains(exam.id)) {
        summaries.add(_ExamSummary(exam, null, Accuracy.empty));
        continue;
      }
      final questions = await questionRepo.load(exam.id);
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
    _certified = await _certRepo.load();
    return _HomeData(summaries, _certified);
  }

  Future<void> _toggleCertified(Exam exam) async {
    final next = !_certified.containsKey(exam.id);
    final updated = await _certRepo.set(exam.id, next);
    if (mounted) setState(() => _certified = updated);
  }

  Future<void> _openExam(Exam exam) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ExamScreen(exam: exam)));
    // 正答率や取得済みの印が変わっているかもしれないので読み直す
    // アロー関数だと Future を返してしまい setState が例外になるので、ブロックで書く
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
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
          final certifiedCount = summaries
              .where((s) => _certified.containsKey(s.exam.id))
              .length;
          final t = context.tokens;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              t.space5,
              t.space3,
              t.space5,
              t.space7,
            ),
            children: [
              _ProgressCard(certified: certifiedCount, total: summaries.length),
              // 一番大事なのは「問題を解く」ことなので、問題のある試験を先に出す
              const _LevelHeader('解ける試験'),
              for (final s in summaries.where((s) => s.ready))
                _ExamCard(
                  summary: s,
                  certified: _certified.containsKey(s.exam.id),
                  onTap: () => _openExam(s.exam),
                  onToggleCertified: () => _toggleCertified(s.exam),
                ),
              // 準備中の試験はレベル別に並べる（全冠の一覧として、取得済みの印は付けられる）
              for (final level in ExamLevel.values)
                if (summaries.any(
                  (s) => !s.ready && s.exam.level == level,
                )) ...[
                  _LevelHeader('準備中・${level.label}'),
                  for (final s in summaries.where(
                    (s) => !s.ready && s.exam.level == level,
                  ))
                    _ExamCard(
                      summary: s,
                      certified: _certified.containsKey(s.exam.id),
                      onTap: null,
                      onToggleCertified: () => _toggleCertified(s.exam),
                    ),
                ],
              SizedBox(height: t.space6),
              Text(AppInfo.trademarkNotice, style: t.caption),
            ],
          );
        },
      ),
    );
  }
}

/// 全冠への進捗
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.certified, required this.total});

  final int certified;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final done = total > 0 && certified >= total;
    // カードにせず、背景の上に数字とバーを直接置く（カードは問題のカードだけ）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(done ? '全冠達成' : '全冠への進捗', style: t.label),
        SizedBox(height: t.space1),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$certified', style: t.display),
              TextSpan(
                text: ' / $total 試験を取得',
                style: t.numeric(t.body.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space3),
        ThinBar(value: total == 0 ? 0 : certified / total),
        SizedBox(height: t.space2),
        Text('取得した試験は、右の印をタップして記録できます', style: t.caption),
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
  const _ExamCard({
    required this.summary,
    required this.certified,
    required this.onTap,
    required this.onToggleCertified,
  });

  final _ExamSummary summary;
  final bool certified;

  /// null なら準備中でタップできない
  final VoidCallback? onTap;
  final VoidCallback onToggleCertified;

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
            IconButton(
              onPressed: onToggleCertified,
              tooltip: certified ? '取得済みの印を外す' : '取得済みにする',
              icon: Icon(
                certified ? Icons.verified : Icons.check_circle_outline,
                color: certified ? t.ink : t.hairline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
