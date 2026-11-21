import 'package:material_ui/material_ui.dart';

import '../data/certification_repository.dart';
import '../data/question_repository.dart';
import '../data/study_repository.dart';
import '../logic/mock_builder.dart';
import '../models/exam.dart';
import '../models/question.dart';
import 'mock_screen.dart';
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
  const _ExamData(this.questions, this.accuracy, this.lastMock);

  final List<Question> questions;

  /// 分野ID → 正答率
  final Map<String, Accuracy> accuracy;

  /// 前回の模試の結果（まだ受けていなければ null）
  final MockResult? lastMock;

  /// 本番形式の問題（分野別の出題・模試に使う）
  List<Question> get examFormat => questions.where((q) => !q.isDrill).toList();

  /// 一問一答
  List<Question> get drills => questions.where((q) => q.isDrill).toList();

  int countOf(String domainId) =>
      examFormat.where((q) => q.domainId == domainId).length;

  int drillCountOf(String domainId) =>
      drills.where((q) => q.domainId == domainId).length;
}

class _ExamScreenState extends State<ExamScreen> {
  late Future<_ExamData> _future;
  final _certRepo = CertificationRepository();
  bool _certified = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _certRepo.load().then((map) {
      if (mounted) setState(() => _certified = map.containsKey(widget.exam.id));
    });
  }

  Future<void> _setCertified(bool value) async {
    setState(() => _certified = value);
    await _certRepo.set(widget.exam.id, value);
  }

  Future<_ExamData> _load() async {
    final questions = await QuestionRepository().load(widget.exam.id);
    var accuracy = <String, Accuracy>{};
    MockResult? lastMock;
    try {
      final repo = await StudyRepository.instance();
      accuracy = await repo.accuracyByDomain(widget.exam.id, questions);
      final mocks = await repo.mockResults(widget.exam.id, limit: 1);
      lastMock = mocks.firstOrNull;
    } catch (e) {
      // 記録が読めなくても、出題はできるようにする
      debugPrint('学習記録の読み込みに失敗: $e');
    }
    return _ExamData(questions, accuracy, lastMock);
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
    final questions = data.examFormat
        .where((q) => domainIds.contains(q.domainId))
        .toList();
    final title = domainIds.length == 1
        ? (widget.exam.domainById(domainIds.first)?.name ?? '分野別')
        : '選択した分野';
    _start(questions, title);
  }

  /// 模試を始める。収録数が足りなければ、その旨を伝えてから始める
  Future<void> _startMock(_ExamData data) async {
    final exam = widget.exam;
    final set = buildMockSet(exam, data.questions);
    if (set.questions.isEmpty) return;
    final minutes = (set.timeLimit.inSeconds / 60).ceil();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('模試を始めますか？'),
        content: Text(
          [
            if (set.isShort)
              '収録数が足りないため、${set.questions.length}問・$minutes分で実施します'
                  '（本番は${exam.mock.questionCount}問・${exam.mock.timeLimitMinutes}分）。'
            else
              '${set.questions.length}問・$minutes分で実施します。',
            '1問ごとの正誤は出さず、最後にまとめて採点します。',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('始める'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MockScreen(exam: exam, mockSet: set),
      ),
    );
    if (mounted) setState(() => _future = _load());
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
          final questions = data.examFormat;
          final drills = data.drills;

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
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _certified,
                onChanged: _setCertified,
                title: const Text('この試験は取得済み'),
                secondary: Icon(
                  _certified ? Icons.verified : Icons.check_circle_outline,
                  color: _certified ? scheme.primary : scheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              // 一問一答で理解 → 本番形式で確認 → 模試で仕上げる、の順に並べる
              if (drills.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () => _start(drills, '一問一答'),
                  icon: const Icon(Icons.bolt),
                  label: Text('一問一答（${drills.length}問）'),
                ),
                const SizedBox(height: 12),
              ],
              (drills.isNotEmpty ? OutlinedButton.new : FilledButton.new)(
                onPressed: () => _start(questions, '本番形式'),
                child: Text('本番形式で全分野から出題（${questions.length}問）'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _pickDomains(data),
                child: const Text('分野を選んで出題'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: questions.isEmpty ? null : () => _startMock(data),
                child: Text(
                  '模試（${exam.mock.questionCount}問・${exam.mock.timeLimitMinutes}分）',
                ),
              ),
              if (data.lastMock case final last?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '前回の模試：${(last.rate * 100).round()}%'
                    '（${last.takenAt.month}/${last.takenAt.day}・${last.questionCount}問）',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              Text('出題分野', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'タップすると、その分野の本番形式の問題だけを出題します',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final domain in exam.domains)
                _DomainRow(
                  domain: domain,
                  count: data.countOf(domain.id),
                  drillCount: data.drillCountOf(domain.id),
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
    required this.drillCount,
    required this.accuracy,
    required this.onTap,
  });

  final Domain domain;

  /// 本番形式の問題数
  final int count;

  /// 一問一答の問題数
  final int drillCount;
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
                  [
                    '$count問',
                    if (drillCount > 0) '一問一答 $drillCount問',
                    '解いた ${accuracy.answered}問',
                    '比重 ${domain.weight}%',
                  ].join('・'),
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
