import 'package:material_ui/material_ui.dart';

import '../models/exam.dart';
import '../theme/app_tokens.dart';

/// ホームの主役。全試験をレベル別の行に並べ、取得した試験を墨で塗る（DESIGN.md 1章「全冠ボード」）
///
/// 枠をタップすると取得済みの印を付け外しする。印を付けた瞬間だけ、判子を押すように縮んで止まる
class CertificationBoard extends StatelessWidget {
  const CertificationBoard({
    super.key,
    required this.exams,
    required this.certified,
    required this.onToggle,
  });

  final List<Exam> exams;

  /// 取得済みの試験ID
  final Set<String> certified;
  final ValueChanged<Exam> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = exams.length;
    final done = exams.where((e) => certified.contains(e.id)).length;
    final remaining = total - done;
    final levels = [
      for (final level in ExamLevel.values)
        if (exams.any((e) => e.level == level)) level,
    ];
    // 一番多いレベルの試験数に合わせて枠の幅をそろえ、行をまたいで縦の列がそろうようにする
    final maxPerRow = levels
        .map((l) => exams.where((e) => e.level == l).length)
        .fold(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: remaining == 0
                  ? Text('全冠達成', style: t.title)
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '全冠まで あと ', style: t.label),
                          TextSpan(text: '$remaining', style: t.display),
                          TextSpan(
                            text: ' 試験',
                            style: t.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
            ),
            Text(
              '$done / $total 取得',
              style: t.numeric(t.caption.copyWith(color: t.textSecondary)),
            ),
          ],
        ),
        SizedBox(height: t.space4),
        LayoutBuilder(
          builder: (context, constraints) {
            // 「Foundational」が1行に収まる幅＋枠との間
            final labelWidth = t.space7 + t.space6 + t.space2;
            final cellWidth =
                (constraints.maxWidth -
                    labelWidth -
                    t.space1 * (maxPerRow - 1)) /
                maxPerRow;
            return Column(
              children: [
                for (final (i, level) in levels.indexed) ...[
                  if (i > 0) SizedBox(height: t.space2),
                  Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Padding(
                          padding: EdgeInsets.only(right: t.space2),
                          child: Text(level.label, style: t.caption),
                        ),
                      ),
                      for (final (j, exam)
                          in exams.where((e) => e.level == level).indexed) ...[
                        if (j > 0) SizedBox(width: t.space1),
                        SizedBox(
                          width: cellWidth,
                          child: _BoardCell(
                            exam: exam,
                            certified: certified.contains(exam.id),
                            onTap: () => onToggle(exam),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        SizedBox(height: t.space3),
        Text('取得した試験をタップして印を付けます', style: t.caption),
      ],
    );
  }
}

/// ボードの1枠。取得済みは墨の塗り、未取得は線だけ
class _BoardCell extends StatefulWidget {
  const _BoardCell({
    required this.exam,
    required this.certified,
    required this.onTap,
  });

  final Exam exam;
  final bool certified;
  final VoidCallback onTap;

  @override
  State<_BoardCell> createState() => _BoardCellState();
}

class _BoardCellState extends State<_BoardCell>
    with SingleTickerProviderStateMixin {
  // 0 → 1 で、大きめの位置から元の大きさに縮んで止まる（判子を押す動き）
  late final _stamp = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(covariant _BoardCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 印を付けた瞬間だけ動かす（画面を開いたときや、印を外したときは動かさない）
    if (!oldWidget.certified && widget.certified) {
      _stamp
        ..duration = context.tokens.stamp
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final certified = widget.certified;
    return Semantics(
      button: true,
      label:
          '${widget.exam.shortName} ${certified ? '取得済み。タップで印を外す' : '未取得。タップで取得済みにする'}',
      excludeSemantics: true,
      child: ScaleTransition(
        scale: Tween(
          begin: t.stampScale,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _stamp, curve: Curves.easeOutCubic)),
        child: Material(
          color: certified ? t.ink : t.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusSmall),
            side: certified
                ? BorderSide.none
                : BorderSide(color: t.hairline, width: t.borderControl),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(t.radiusSmall),
            child: SizedBox(
              height: t.tapTarget,
              child: Center(
                child: Text(
                  widget.exam.shortName,
                  style: t.label.copyWith(
                    color: certified ? t.onInk : t.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
