import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../models/question.dart';
import '../support/report_mail.dart';
import '../theme/app_theme.dart';

/// 回答後の解説。練習モードの出題画面と、模試の見直しで使う
///
/// 並び順:
/// 1. 正解／不正解
/// 2. 自分が選んだ選択肢の解説（色付きの枠で一番目立たせる）
/// 3. 正解の選択肢の解説（選んでいなかった場合）
/// 4. そのほかの選択肢の解説
/// 5. まとめの解説
/// 6. 根拠（タップでブラウザが開く）
/// 7. [action]（「類題に挑戦」ボタンなど）
/// 8. 注意書きと、誤りの報告ボタン
class ExplanationView extends StatelessWidget {
  const ExplanationView({
    super.key,
    required this.question,
    required this.selected,
    this.action,
  });

  final Question question;
  final Set<int> selected;

  /// 根拠の下に置く部品（例: 類題に挑戦ボタン）
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    final isCorrect = q.isCorrect(selected);

    final picked = [
      for (var i = 0; i < q.choices.length; i++)
        if (selected.contains(i)) i,
    ];
    final missedAnswers = [
      for (final i in q.answers)
        if (!selected.contains(i)) i,
    ]..sort();
    final others = [
      for (var i = 0; i < q.choices.length; i++)
        if (!selected.contains(i) && !q.answers.contains(i)) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          isCorrect ? '⭕ 正解' : '❌ 不正解',
          style: theme.textTheme.titleLarge?.copyWith(
            color: isCorrect
                ? AppTheme.correctForeground(context)
                : AppTheme.wrongForeground(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (picked.isNotEmpty) ...[
          _SectionLabel('あなたの選択'),
          for (final i in picked)
            _ChoiceExplanation(question: q, index: i, emphasized: true),
        ],
        if (missedAnswers.isNotEmpty) ...[
          _SectionLabel('正解'),
          for (final i in missedAnswers)
            _ChoiceExplanation(question: q, index: i, emphasized: true),
        ],
        if (others.isNotEmpty) ...[
          _SectionLabel('ほかの選択肢'),
          for (final i in others)
            _ChoiceExplanation(question: q, index: i, emphasized: false),
        ],
        const SizedBox(height: 8),
        _SectionLabel('まとめ'),
        Text(q.explanation, style: theme.textTheme.bodyMedium),
        if (q.references.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionLabel('根拠'),
          for (final ref in q.references) _ReferenceLink(reference: ref),
        ],
        ?action,
        const SizedBox(height: 20),
        Text(
          AppInfo.disclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => ReportMail.reportQuestion(
              context,
              questionId: q.id,
              questionText: q.question,
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('この問題の誤りを報告'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 選択肢1つ分の解説。[emphasized] なら正誤の色付きの枠で囲む
class _ChoiceExplanation extends StatelessWidget {
  const _ChoiceExplanation({
    required this.question,
    required this.index,
    required this.emphasized,
  });

  final Question question;
  final int index;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final choice = question.choices[index];
    final isAnswer = question.answers.contains(index);
    final mark = isAnswer ? '○' : '×';
    final markColor = isAnswer
        ? AppTheme.correctForeground(context)
        : AppTheme.wrongForeground(context);
    final letter = String.fromCharCode(65 + index);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$mark $letter  ',
                style: TextStyle(color: markColor, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: choice.text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(choice.explanation, style: theme.textTheme.bodyMedium),
      ],
    );

    if (!emphasized) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: content,
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAnswer
            ? AppTheme.correctBackground(context)
            : AppTheme.wrongBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: markColor.withValues(alpha: 0.4)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: content,
      ),
    );
  }
}

/// 根拠のリンク。タップで外部のブラウザを開く
class _ReferenceLink extends StatelessWidget {
  const _ReferenceLink({required this.reference});

  final Reference reference;

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(reference.url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.open_in_new, size: 16, color: scheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reference.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
