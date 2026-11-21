import 'package:material_ui/material_ui.dart';

import '../data/study_repository.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rate = accuracy.rate ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 12),
              Text(
                '${(rate * 100).round()}%（${accuracy.correct}/${accuracy.answered}）',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
