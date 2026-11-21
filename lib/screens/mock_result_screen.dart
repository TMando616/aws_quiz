import 'package:material_ui/material_ui.dart';

import '../ads/banner_ad_view.dart';
import '../data/study_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../widgets/domain_accuracy_bar.dart';
import '../widgets/explanation_view.dart';
import '../widgets/similar_questions_button.dart';

/// 模試の結果。総合の正答率・分野別の正答率・間違えた問題の見直し
///
/// 本番のスケールスコア（750点など）は計算方法が公開されていないので、正答率で表示する
class MockResultScreen extends StatelessWidget {
  const MockResultScreen({
    super.key,
    required this.exam,
    required this.result,
    required this.questions,
    required this.selections,
    this.timeUp = false,
  });

  final Exam exam;
  final MockResult result;
  final List<Question> questions;

  /// 問題の番号 → 選んだ選択肢
  final Map<int, Set<int>> selections;

  /// 時間切れで採点したか
  final bool timeUp;

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h時間$m分';
    if (m > 0) return '$m分$s秒';
    return '$s秒';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wrong = [
      for (var i = 0; i < questions.length; i++)
        if (!questions[i].isCorrect(selections[i] ?? const {})) i,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${exam.shortName} 模試の結果'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const SafeArea(child: BannerAdView()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (timeUp)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '制限時間になったため、採点しました',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          Center(
            child: Text(
              '${(result.rate * 100).round()}%',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          Center(
            child: Text(
              '${result.questionCount}問中 ${result.correctCount}問正解・${_formatDuration(result.duration)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('分野別の正答率', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final d in exam.domains)
            if (result.byDomain[d.id] case final acc?)
              DomainAccuracyBar(name: d.name, accuracy: acc),
          const SizedBox(height: 24),
          Text(
            wrong.isEmpty ? '全問正解です' : '間違えた問題（${wrong.length}問）',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final i in wrong)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  questions[i].question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  (selections[i]?.isEmpty ?? true)
                      ? '未回答'
                      : exam.domainById(questions[i].domainId)?.name ?? '',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ReviewScreen(
                      exam: exam,
                      question: questions[i],
                      selected: selections[i] ?? const {},
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('試験トップに戻る'),
          ),
        ],
      ),
    );
  }
}

/// 間違えた問題の見直し。問題文・自分の選択・解説を出す
class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen({
    required this.exam,
    required this.question,
    required this.selected,
  });

  final Exam exam;
  final Question question;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('見直し')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              exam.domainById(question.domainId)?.name ?? '',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(question.question, style: theme.textTheme.bodyLarge),
            if (selected.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '未回答でした',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            ExplanationView(
              question: question,
              selected: selected,
              action: SimilarQuestionsButton(exam: exam, question: question),
            ),
          ],
        ),
      ),
    );
  }
}
