import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// 問題のカード。アプリで「カード」（白い紙＋影）の見た目を使うのはこれだけ（DESIGN.md 5章）
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(t.space5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusCard),
        boxShadow: t.cardShadow,
      ),
      child: child,
    );
  }
}

/// 選択肢の状態
enum ChoiceState {
  /// 未回答で選んでいない
  idle,

  /// 未回答で選んでいる
  selected,

  /// 回答後：正解の選択肢
  correct,

  /// 回答後：選んだ不正解の選択肢
  wrong,

  /// 回答後：正解でも選んだものでもない選択肢
  inactive,
}

/// 選択肢のタイル。答えた瞬間に正誤の色へ変わる（DESIGN.md 6章のモーション1）
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
    this.multiple = false,
    this.expand = false,
  });

  final String letter;
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  /// 複数選択の問題か（選択中の印を四角にする）
  final bool multiple;

  /// 高さいっぱいに広げ、長い文はタイルの中でスクロールする（スワイプ表示用）
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (
      Color background,
      Color border,
      double borderWidth,
    ) = switch (state) {
      ChoiceState.idle => (t.surface, t.hairline, t.borderControl),
      ChoiceState.selected => (t.surfaceMuted, t.ink, t.borderControlSelected),
      ChoiceState.correct => (
        t.correctSurface,
        t.correct,
        t.borderControlSelected,
      ),
      ChoiceState.wrong => (t.dangerSurface, t.danger, t.borderControlSelected),
      ChoiceState.inactive => (t.surface, t.hairline, t.borderControl),
    };
    final textColor = state == ChoiceState.inactive
        ? t.textSecondary
        : t.textPrimary;

    final mark = switch (state) {
      ChoiceState.correct => Icon(Icons.check_circle, color: t.correct),
      ChoiceState.wrong => Icon(Icons.cancel, color: t.danger),
      ChoiceState.selected => Icon(
        multiple ? Icons.check_box : Icons.radio_button_checked,
        color: t.ink,
      ),
      // ○×の問題（letter が空）では、文頭の記号と重なるので未選択の印は出さない
      _ when letter.isEmpty => null,
      _ => Icon(
        multiple ? Icons.check_box_outline_blank : Icons.radio_button_off,
        color: t.hairline,
      ),
    };

    final textWidget = Text(text, style: t.body.copyWith(color: textColor));

    return AnimatedContainer(
      duration: t.answerFeedback,
      curve: Curves.easeOut,
      constraints: BoxConstraints(minHeight: t.tapTarget),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(t.radiusControl),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusControl),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space4,
              vertical: t.space3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ○×の問題では、選択肢の文に記号が入っているので A・B は出さない
                if (letter.isNotEmpty) ...[
                  SizedBox(
                    width: t.space5,
                    child: Text(
                      letter,
                      style: t.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  SizedBox(width: t.space2),
                ],
                Expanded(
                  child: expand
                      ? SingleChildScrollView(child: textWidget)
                      : textWidget,
                ),
                if (mark != null) ...[SizedBox(width: t.space2), mark],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// セクションの見出し（「出題分野」など）
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space2),
      child: Row(
        children: [
          Expanded(child: Text(text, style: t.label)),
          if (trailing case final s?) Text(s, style: t.caption),
        ],
      ),
    );
  }
}

/// 一覧の1行。カードを並べず、区切り線で区切る（DESIGN.md 5章）
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.titleStyle,
    this.titleMaxLines,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final TextStyle? titleStyle;

  /// タイトルの最大行数（長い問題文を一覧で出すときなど）。超えた分は「…」にする
  final int? titleMaxLines;

  /// タイトルの下に置く部品（正答率のバーなど）
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
            if (leading case final l?) ...[l, SizedBox(width: t.space3)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? t.body,
                    maxLines: titleMaxLines,
                    overflow: titleMaxLines == null
                        ? null
                        : TextOverflow.ellipsis,
                  ),
                  if (subtitle case final s?) Text(s, style: t.caption),
                  if (bottom case final b?) ...[SizedBox(height: t.space2), b],
                ],
              ),
            ),
            if (trailing case final tr?) ...[SizedBox(width: t.space3), tr],
            if (showChevron && onTap != null) ...[
              SizedBox(width: t.space2),
              Icon(Icons.chevron_right, color: t.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// 正答率などの細いバー。中身はマーカーの黄色
class ThinBar extends StatelessWidget {
  const ThinBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radiusSmall),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: t.barHeight,
        color: t.marker,
        backgroundColor: t.surfaceMuted,
      ),
    );
  }
}
