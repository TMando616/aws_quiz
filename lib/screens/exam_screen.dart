import 'package:material_ui/material_ui.dart';

import '../data/question_repository.dart';
import '../data/study_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import 'quiz_screen.dart';

/// 試験ごとのトップ。分野ごとの問題数・正答率と、出題方法を選ぶ
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.exam});

  final Exam exam;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

/// 画面に出すデータをまとめたもの
class _ExamData {
  const _ExamData(this.questions, this.accuracy);

  final List<Question> questions;

  /// 分野ID → 正答率
  final Map<String, Accuracy> accuracy;

  int countOf(String domainId) =>
      questions.where((q) => q.domainId == domainId).length;
}

class _ExamScreenState extends State<ExamScreen> {
  late Future<_ExamData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExamData> _load() async {
    final questions = await QuestionRepository().load(widget.exam.id);
    var accuracy = <String, Accuracy>{};
    try {
      final repo = await StudyRepository.instance();
      accuracy = await repo.accuracyByDomain(widget.exam.id, questions);
    } catch (e) {
      // 記録が読めなくても、出題はできるようにする
      debugPrint('学習記録の読み込みに失敗: $e');
    }
    return _ExamData(questions, accuracy);
  }

  /// 出題画面へ。戻ってきたら正答率を読み直す
  Future<void> _start(List<Question> questions, String title) async {
    if (questions.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(exam: widget.exam, questions: questions, title: title),
      ),
    );
    if (mounted) setState(() => _future = _load());
  }

  void _startDomains(_ExamData data, Set<String> domainIds) {
    final questions = data.questions
        .where((q) => domainIds.contains(q.domainId))
        .toList();
    final title = domainIds.length == 1
        ? (widget.exam.domainById(domainIds.first)?.name ?? '分野別')
        : '選択した分野';
    _start(questions, title);
  }

  Future<void> _pickDomains(_ExamData data) async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DomainPicker(exam: widget.exam, data: data),
    );
    if (picked != null && picked.isNotEmpty) _startDomains(data, picked);
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(exam.shortName)),
      body: FutureBuilder<_ExamData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('問題を読み込めませんでした\n${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final questions = data.questions;

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
                onPressed: () => _start(questions, '全分野'),
                child: Text('全分野から出題（${questions.length}問）'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _pickDomains(data),
                child: const Text('分野を選んで出題'),
              ),
              const SizedBox(height: 32),
              Text('出題分野', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'タップすると、その分野だけを出題します',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final domain in exam.domains)
                _DomainRow(
                  domain: domain,
                  count: data.countOf(domain.id),
                  accuracy: data.accuracy[domain.id] ?? Accuracy.empty,
                  onTap: () => _startDomains(data, {domain.id}),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 分野1つ分の行。問題数・正答率・比重を出す
class _DomainRow extends StatelessWidget {
  const _DomainRow({
    required this.domain,
    required this.count,
    required this.accuracy,
    required this.onTap,
  });

  final Domain domain;
  final int count;
  final Accuracy accuracy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rate = accuracy.rate;
    final enabled = count > 0;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        domain.name,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rate == null ? '未回答' : '${(rate * 100).round()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: rate == null
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate ?? 0,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count問・解いた ${accuracy.answered}問・比重 ${domain.weight}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「分野を選んで出題」のシート。複数の分野を選べる
class _DomainPicker extends StatefulWidget {
  const _DomainPicker({required this.exam, required this.data});

  final Exam exam;
  final _ExamData data;

  @override
  State<_DomainPicker> createState() => _DomainPickerState();
}

class _DomainPickerState extends State<_DomainPicker> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.data.questions
        .where((q) => _picked.contains(q.domainId))
        .length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('出題する分野を選ぶ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in widget.exam.domains)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _picked.contains(d.id),
                      onChanged: widget.data.countOf(d.id) == 0
                          ? null
                          : (v) => setState(
                              () => v == true
                                  ? _picked.add(d.id)
                                  : _picked.remove(d.id),
                            ),
                      title: Text(d.name, style: theme.textTheme.bodyMedium),
                      subtitle: Text('${widget.data.countOf(d.id)}問'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: total == 0
                  ? null
                  : () => Navigator.of(context).pop(_picked),
              child: Text(total == 0 ? '分野を選んでください' : '$total問を出題'),
            ),
          ],
        ),
      ),
    );
  }
}
