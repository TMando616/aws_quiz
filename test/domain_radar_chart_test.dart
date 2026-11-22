import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:aws_quiz/theme/app_theme.dart';
import 'package:aws_quiz/widgets/domain_radar_chart.dart';

void main() {
  test('1本目の軸は真上、そこから時計回りに等間隔', () {
    expect(radarAngle(0, 4), closeTo(-math.pi / 2, 1e-9));
    expect(radarAngle(1, 4), closeTo(0, 1e-9)); // 右
    expect(radarAngle(2, 4), closeTo(math.pi / 2, 1e-9)); // 下
  });

  testWidgets('正方形で描き、分野ごとの正答率を読み上げ用のラベルに出す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: DomainRadarChart(rates: [0.8, null, 0.5, 1.2]),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(DomainRadarChart));
    expect(size.width, size.height);
    expect(
      find.bySemanticsLabel('分野1 80%、分野2 未回答、分野3 50%、分野4 100%'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
