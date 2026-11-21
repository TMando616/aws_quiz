import 'package:material_ui/material_ui.dart';

import '../ads/banner_ad_view.dart';
import '../data/study_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_parts.dart';
import '../widgets/domain_accuracy_bar.dart';
import '../widgets/explanation_view.dart';
import '../widgets/related_questions_buttons.dart';

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
    final t = context.tokens;
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
        padding: EdgeInsets.fromLTRB(t.space5, t.space5, t.space5, t.space6),
        children: [
          if (timeUp)
            Padding(
              padding: EdgeInsets.only(bottom: t.space3),
              child: Text(
                '制限時間になったため、採点しました',
                style: t.body.copyWith(color: t.danger),
              ),
            ),
          Text('${(result.rate * 100).round()}%', style: t.display),
          SizedBox(height: t.space1),
          Text(
            '${result.questionCount}問中 ${result.correctCount}問正解・${_formatDuration(result.duration)}',
            style: t.caption,
          ),
          SizedBox(height: t.space6),
          const SectionLabel('分野ごとの正答率'),
          for (final d in exam.domains)
            if (result.byDomain[d.id] case final acc?)
              DomainAccuracyBar(name: d.name, accuracy: acc),
          SizedBox(height: t.space5),
          SectionLabel(wrong.isEmpty ? '全問正解' : '間違えた問題（${wrong.length}問）'),
          for (final i in wrong)
            ListRow(
              title: questions[i].question,
              titleMaxLines: 2,
              subtitle: (selections[i]?.isEmpty ?? true)
                  ? '未回答・${exam.domainById(questions[i].domainId)?.name ?? ''}'
                  : exam.domainById(questions[i].domainId)?.name ?? '',
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
          SizedBox(height: t.space6),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('試験トップに戻る'),
          ),
        ],
      ),
    );
  }
}

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
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('見直し')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(t.space5, t.space3, t.space5, t.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    exam.domainById(question.domainId)?.name ?? '',
                    style: t.label,
                  ),
                  SizedBox(height: t.space3),
                  Text(question.question, style: t.question),
                ],
              ),
            ),
            if (selected.isEmpty) ...[
              SizedBox(height: t.space3),
              Text('未回答でした', style: t.body.copyWith(color: t.danger)),
            ],
            ExplanationView(
              question: question,
              selected: selected,
              action: RelatedQuestionsButtons(exam: exam, question: question),
            ),
          ],
        ),
      ),
    );
  }
}
