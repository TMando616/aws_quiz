import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../ads/ad_consent.dart';
import '../data/certification_repository.dart';
import '../data/exam_repository.dart';
import '../data/question_repository.dart';
import '../data/study_repository.dart';
import '../logic/mock_builder.dart';
import '../models/exam.dart';
import '../widgets/explanation_view.dart';
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
  const _ExamSummary(this.exam, this.questionCount, this.accuracy);

  final Exam exam;

  /// 収録している問題数。null なら問題ファイルが無い（準備中）
  final int? questionCount;

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
  /// `--dart-define=DEBUG_ROUTE=exam` で試験トップ、`quiz` で出題画面、`explanation` で解説、`mock` で模試、`mock-result` で模試の結果まで進む
  static const _debugRoute = String.fromEnvironment('DEBUG_ROUTE');

  Future<void> _openDebugRoute(_HomeData data) async {
    final target = data.summaries
        .where((s) => (s.questionCount ?? 0) > 0)
        .firstOrNull;
    if (target == null || !mounted) return;
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(builder: (_) => ExamScreen(exam: target.exam)),
    );
    if (_debugRoute == 'explanation') {
      // 1問目で不正解（A）を選んだときの解説
      final q = (await QuestionRepository().load(target.exam.id)).first;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('解説の確認（開発用）')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: ExplanationView(question: q, selected: const {0}),
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
          builder: (_) =>
              QuizScreen(exam: target.exam, questions: questions, title: '全分野'),
        ),
      );
    }
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
      summaries.add(_ExamSummary(exam, questions.length, accuracy));
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
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('クラウド認定 学習'),
        actions: [
          if (_privacyOptionsRequired)
            PopupMenuButton<void>(
              itemBuilder: (context) => [
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ProgressCard(certified: certifiedCount, total: summaries.length),
              for (final level in ExamLevel.values) ...[
                _LevelHeader(level.label),
                for (final s in summaries.where((s) => s.exam.level == level))
                  _ExamCard(
                    summary: s,
                    certified: _certified.containsKey(s.exam.id),
                    onTap: s.ready ? () => _openExam(s.exam) : null,
                    onToggleCertified: () => _toggleCertified(s.exam),
                  ),
              ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = total > 0 && certified >= total;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            done ? '全冠達成！' : '全冠への進捗',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$certified',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                TextSpan(
                  text: ' / $total 取得',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : certified / total,
              minHeight: 8,
              backgroundColor: scheme.surface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '取得済みの試験は、右の ✓ をタップして印をつけられます',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exam = summary.exam;
    final ready = summary.ready;
    final rate = summary.accuracy.rate;

    final retire = exam.retireDate;
    final status = [
      ready ? '${summary.questionCount}問' : '準備中',
      if (rate != null) '正答率 ${(rate * 100).round()}%',
      if (exam.isRetiring && retire != null)
        '${retire.year}年${retire.month}月で終了',
    ].join('・');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              // 準備中の試験は薄く表示する（取得済みの印だけは付けられる）
              Expanded(
                child: Opacity(
                  opacity: ready ? 1 : 0.55,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          exam.shortName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ready
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.nameJa,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleCertified,
                tooltip: certified ? '取得済みの印を外す' : '取得済みにする',
                icon: Icon(
                  certified ? Icons.verified : Icons.check_circle_outline,
                  color: certified ? scheme.primary : scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
