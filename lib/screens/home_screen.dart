import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../data/exam_repository.dart';
import '../data/question_repository.dart';
import '../models/exam.dart';
import '../logic/mock_builder.dart';
import 'exam_screen.dart';
import 'mock_result_screen.dart';
import 'mock_screen.dart';
import 'quiz_screen.dart';
import '../widgets/explanation_view.dart';

/// ホーム。全試験をレベル別に並べる
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// ホームに出す1試験分の情報
class _ExamSummary {
  const _ExamSummary(this.exam, this.questionCount);

  final Exam exam;

  /// 収録している問題数。null なら問題ファイルが無い（準備中）
  final int? questionCount;
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<_ExamSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (kDebugMode && _debugRoute.isNotEmpty) _future.then(_openDebugRoute);
  }

  /// 開発用：起動後に自動で画面を進める（シミュレーターの画面確認用。デバッグビルドだけで効く）
  /// `--dart-define=DEBUG_ROUTE=exam` で試験トップ、`quiz` で出題画面、`explanation` で解説、`mock` で模試、`mock-result` で模試の結果まで進む
  static const _debugRoute = String.fromEnvironment('DEBUG_ROUTE');

  Future<void> _openDebugRoute(List<_ExamSummary> summaries) async {
    final target = summaries
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

  Future<List<_ExamSummary>> _load() async {
    final examRepo = ExamRepository();
    final questionRepo = QuestionRepository();
    final exams = await examRepo.loadAll();
    final available = await examRepo.examIdsWithQuestions();
    return [
      for (final exam in exams)
        _ExamSummary(
          exam,
          available.contains(exam.id)
              ? (await questionRepo.load(exam.id)).length
              : null,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('クラウド認定 学習')),
      body: FutureBuilder<List<_ExamSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('試験の一覧を読み込めませんでした\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summaries = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              for (final level in ExamLevel.values) ...[
                _LevelHeader(level.label),
                for (final s in summaries.where((s) => s.exam.level == level))
                  _ExamCard(summary: s),
              ],
            ],
          );
        },
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
  const _ExamCard({required this.summary});

  final _ExamSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exam = summary.exam;
    final count = summary.questionCount;
    final ready = count != null && count > 0;

    final retire = exam.retireDate;
    final status = [
      ready ? '$count問' : '準備中',
      if (exam.isRetiring && retire != null)
        '${retire.year}年${retire.month}月で終了',
    ].join('・');

    return Opacity(
      opacity: ready ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ready
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ExamScreen(exam: exam)),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    exam.shortName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ready ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.nameJa, style: theme.textTheme.titleSmall),
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
                if (ready)
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
