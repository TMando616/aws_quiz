import 'package:material_ui/material_ui.dart';

import '../data/question_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import 'quiz_screen.dart';

/// 試験ごとのトップ。分野ごとの問題数と、出題方法を選ぶ
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.exam});

  final Exam exam;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late Future<List<Question>> _future;

  @override
  void initState() {
    super.initState();
    _future = QuestionRepository().load(widget.exam.id);
  }

  void _startAll(List<Question> questions) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(exam: widget.exam, questions: questions, title: '全分野'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(exam.shortName)),
      body: FutureBuilder<List<Question>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('問題を読み込めませんでした\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final questions = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                exam.code,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(exam.nameJa, style: theme.textTheme.headlineSmall),
              Text(
                exam.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: questions.isEmpty
                    ? null
                    : () => _startAll(questions),
                child: Text('全分野から出題（${questions.length}問）'),
              ),
              const SizedBox(height: 32),
              Text('出題分野', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final domain in exam.domains)
                _DomainRow(
                  domain: domain,
                  count: questions.where((q) => q.domainId == domain.id).length,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.domain, required this.count});

  final Domain domain;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(domain.name, style: theme.textTheme.bodyMedium),
                  Text(
                    '比重 ${domain.weight}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$count問', style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
