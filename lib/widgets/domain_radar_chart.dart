import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// 分野ごとの正答率のレーダーチャート。苦手な分野がへこんで見える
///
/// 軸の先には分野の番号（1, 2, …）を出す。分野名は長いので、下の一覧の番号と対応させる。
/// まだ解いていない分野は null で渡し、0% として描いて番号を薄くする
class DomainRadarChart extends StatelessWidget {
  const DomainRadarChart({super.key, required this.rates});

  /// 分野の順の正答率（0〜1）。未回答は null
  final List<double?> rates;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 2軸以下では多角形にならないので描かない
    if (rates.length < 3) return const SizedBox.shrink();
    return Semantics(
      label: [
        for (var i = 0; i < rates.length; i++)
          '分野${i + 1} ${rates[i] == null ? '未回答' : '${(rates[i]!.clamp(0.0, 1.0) * 100).round()}%'}',
      ].join('、'),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _RadarPainter(
            rates: rates,
            grid: t.hairline,
            gridWidth: t.borderThin,
            fill: t.surfaceMuted,
            line: t.ink,
            lineWidth: t.borderControl,
            dotRadius: t.space1,
            labelStyle: t.numeric(t.label),
            labelColor: t.textPrimary,
            mutedLabelColor: t.textSecondary,
            labelGap: t.space3,
          ),
        ),
      ),
    );
  }
}

/// 軸 i の角度。真上から時計回りに等間隔
double radarAngle(int i, int count) => -math.pi / 2 + 2 * math.pi * i / count;

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.rates,
    required this.grid,
    required this.gridWidth,
    required this.fill,
    required this.line,
    required this.lineWidth,
    required this.dotRadius,
    required this.labelStyle,
    required this.labelColor,
    required this.mutedLabelColor,
    required this.labelGap,
  });

  final List<double?> rates;
  final Color grid;
  final double gridWidth;
  final Color fill;
  final Color line;
  final double lineWidth;
  final double dotRadius;
  final TextStyle labelStyle;
  final Color labelColor;
  final Color mutedLabelColor;
  final double labelGap;

  @override
  void paint(Canvas canvas, Size size) {
    final n = rates.length;
    final center = size.center(Offset.zero);
    // 番号のぶんの余白を残す
    final labelSize = (labelStyle.fontSize ?? 13) * 1.4;
    final radius = size.shortestSide / 2 - labelGap - labelSize;
    if (radius <= 0) return;

    Offset point(int i, double r) {
      final a = radarAngle(i, n);
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = gridWidth
      ..style = PaintingStyle.stroke;

    // 目盛り（25%ごと）と軸
    for (final step in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path()
        ..addPolygon([
          for (var i = 0; i < n; i++) point(i, radius * step),
        ], true);
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, radius), gridPaint);
    }

    // 正答率の多角形
    final values = [for (final r in rates) (r ?? 0).clamp(0.0, 1.0)];
    final shape = Path()
      ..addPolygon([
        for (var i = 0; i < n; i++) point(i, radius * values[i]),
      ], true);
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = line
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final dotPaint = Paint()..color = line;
    for (var i = 0; i < n; i++) {
      if (rates[i] == null) continue;
      canvas.drawCircle(point(i, radius * values[i]), dotRadius, dotPaint);
    }

    // 軸の先の番号
    for (var i = 0; i < n; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: labelStyle.copyWith(
            color: rates[i] == null ? mutedLabelColor : labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = point(i, radius + labelGap + labelSize / 2);
      painter.paint(canvas, p - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.rates.toString() != rates.toString() ||
      old.line != line ||
      old.grid != grid;
}
