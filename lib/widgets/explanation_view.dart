import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../models/question.dart';
import '../support/report_mail.dart';
import '../theme/app_tokens.dart';
import 'design_parts.dart';

/// 回答後の解説。練習モードの出題画面と、模試の見直しで使う
///
/// 並び順:
/// 1. 正解／不正解
/// 2. 自分が選んだ選択肢の解説（色付きの枠で一番目立たせる）
/// 3. 正解の選択肢の解説（選んでいなかった場合。見出しは「正解の選択肢」）
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
    final t = context.tokens;
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

    // 外側の余白（セクションの間）> 内側の余白（セクションの中）
    final sectionGap = SizedBox(height: t.space5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: t.space5),
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? t.correct : t.danger,
            ),
            SizedBox(width: t.space2),
            Text(
              isCorrect ? '正解' : '不正解',
              style: t.title.copyWith(color: isCorrect ? t.correct : t.danger),
            ),
          ],
        ),
        sectionGap,
        if (picked.isNotEmpty) ...[
          const SectionLabel('あなたの選択'),
          for (final i in picked)
            _ChoiceExplanation(question: q, index: i, emphasized: true),
          sectionGap,
        ],
        if (missedAnswers.isNotEmpty) ...[
          const SectionLabel('正解の選択肢'),
          for (final i in missedAnswers)
            _ChoiceExplanation(question: q, index: i, emphasized: true),
          sectionGap,
        ],
        if (others.isNotEmpty) ...[
          const SectionLabel('ほかの選択肢'),
          for (final i in others)
            _ChoiceExplanation(question: q, index: i, emphasized: false),
          sectionGap,
        ],
        const SectionLabel('まとめ'),
        Text(q.explanation, style: t.body),
        if (q.references.isNotEmpty) ...[
          sectionGap,
          const SectionLabel('根拠'),
          for (final ref in q.references) _ReferenceLink(reference: ref),
        ],
        ?action,
        SizedBox(height: t.space6),
        Text(AppInfo.disclaimer, style: t.caption),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => ReportMail.reportQuestion(
              context,
              questionId: q.id,
              questionText: q.question,
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: t.textSecondary,
            ),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('この問題の誤りを報告'),
          ),
        ),
      ],
    );
  }
}

/// 選択肢1つ分の解説。[emphasized] なら正誤の色の面で囲む
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
    final t = context.tokens;
    final choice = question.choices[index];
    final isAnswer = question.answers.contains(index);
    // 色を付けるのは強調する選択肢（自分の選択・正解）だけ。ほかの選択肢の印は控えめにする
    final markColor = !emphasized
        ? t.textSecondary
        : (isAnswer ? t.correct : t.danger);
    final trueFalse =
        question.choices.length == 2 &&
        question.choices.first.text.startsWith('○');
    final letter = trueFalse ? '' : '${String.fromCharCode(65 + index)}  ';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(right: t.space1),
                  child: Icon(
                    isAnswer ? Icons.check : Icons.close,
                    color: markColor,
                  ),
                ),
              ),
              TextSpan(text: '$letter${choice.text}'),
            ],
          ),
          style: t.body.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: t.space1),
        Text(choice.explanation, style: t.body),
      ],
    );

    if (!emphasized) {
      return Padding(
        padding: EdgeInsets.only(bottom: t.space4),
        child: content,
      );
    }
    return Container(
      margin: EdgeInsets.only(bottom: t.space2),
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        color: isAnswer ? t.correctSurface : t.dangerSurface,
        borderRadius: BorderRadius.circular(t.radiusControl),
      ),
      child: content,
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
    final t = context.tokens;
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: t.space1),
              child: Icon(Icons.open_in_new, color: t.textSecondary),
            ),
            SizedBox(width: t.space2),
            Expanded(
              child: Text(
                reference.title,
                style: t.body.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: t.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
