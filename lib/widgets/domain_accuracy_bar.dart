import 'package:material_ui/material_ui.dart';

import '../data/study_repository.dart';
import '../theme/app_tokens.dart';
import 'design_parts.dart';

/// 分野1つ分の正答率（分野名・パーセント・バー）。練習と模試の結果画面で使う
class DomainAccuracyBar extends StatelessWidget {
  const DomainAccuracyBar({
    super.key,
    required this.name,
    required this.accuracy,
  });

  final String name;
  final Accuracy accuracy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rate = accuracy.rate ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(name, style: t.body)),
              SizedBox(width: t.space3),
              Text(
                '${(rate * 100).round()}%',
                style: t.numeric(t.body.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SizedBox(height: t.space2),
          ThinBar(value: rate),
          SizedBox(height: t.space1),
          Text(
            '${accuracy.answered}問中 ${accuracy.correct}問正解',
            style: t.caption,
          ),
        ],
      ),
    );
  }
}
