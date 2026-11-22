import 'package:material_ui/material_ui.dart';

import '../data/certification_repository.dart';
import '../data/question_repository.dart';
import '../data/study_repository.dart';
import '../logic/continue_order.dart';
import '../logic/mock_builder.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_parts.dart';
import '../widgets/domain_radar_chart.dart';
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
  const _ExamData(this.questions, this.accuracy, this.lastMock, this.latest);

  final List<Question> questions;

  /// 問題ID → 最新の回答が正解だったか（間違えた問題の解き直しに使う）
  final Map<String, bool> latest;

  /// 最新の回答が不正解の問題（一問一答も本番形式も含む）
  List<Question> get wrong => wrongOnly(questions, latest);

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
    var latest = <String, bool>{};
    try {
      final repo = await StudyRepository.instance();
      accuracy = await repo.accuracyByDomain(widget.exam.id, questions);
      final mocks = await repo.mockResults(widget.exam.id, limit: 1);
      lastMock = mocks.firstOrNull;
      latest = await repo.latestResults(widget.exam.id);
    } catch (e) {
      // 記録が読めなくても、出題はできるようにする
      debugPrint('学習記録の読み込みに失敗: $e');
    }
    return _ExamData(questions, accuracy, lastMock, latest);
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
    final t = context.tokens;

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
          final lastMock = data.lastMock;
          final wrong = data.wrong;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              t.space5,
              t.space3,
              t.space5,
              t.space7,
            ),
            children: [
              Text(exam.code, style: t.numeric(t.label)),
              SizedBox(height: t.space1),
              // 「ソリューションアーキテクト - アソシエイト」を単語の途中で折り返さないよう、ハイフンで改行する
              Text(exam.nameJa.replaceAll(' - ', '\n'), style: t.title),
              SizedBox(height: t.space6),
              // 主ボタンは1つだけ。一問一答で理解 → 本番形式で確認 → 模試、の流れの入口
              if (drills.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () => _start(drills, '一問一答'),
                  icon: const Icon(Icons.bolt),
                  label: Text('一問一答を始める（${drills.length}問）'),
                ),
                SizedBox(height: t.space6),
              ],
              const SectionLabel('ほかの解き方'),
              ListRow(
                title: '間違えた問題だけ解き直す',
                subtitle: wrong.isEmpty ? 'まだありません' : '${wrong.length}問',
                onTap: wrong.isEmpty ? null : () => _start(wrong, '間違えた問題'),
              ),
              ListRow(
                title: '本番形式で全分野から',
                subtitle: '${questions.length}問',
                onTap: questions.isEmpty
                    ? null
                    : () => _start(questions, '本番形式'),
              ),
              ListRow(
                title: '分野を選んで解く',
                subtitle: '本番形式',
                onTap: () => _pickDomains(data),
              ),
              ListRow(
                title: '模試',
                subtitle: [
                  '${exam.mock.questionCount}問・${exam.mock.timeLimitMinutes}分',
                  if (lastMock != null)
                    '前回 ${(lastMock.rate * 100).round()}%'
                        '（${lastMock.takenAt.month}/${lastMock.takenAt.day}）',
                ].join('・'),
                onTap: questions.isEmpty ? null : () => _startMock(data),
              ),
              SizedBox(height: t.space6),
              const SectionLabel('分野ごとの正答率', trailing: 'タップでその分野を解く'),
              // 1問でも解いていれば、苦手な分野がひと目でわかるレーダーチャートを出す
              if (data.accuracy.isNotEmpty && exam.domains.length >= 3) ...[
                SizedBox(height: t.space3),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.8,
                    child: DomainRadarChart(
                      rates: [
                        for (final d in exam.domains) data.accuracy[d.id]?.rate,
                      ],
                    ),
                  ),
                ),
                SizedBox(height: t.space3),
              ],
              for (final (i, domain) in exam.domains.indexed)
                _DomainRow(
                  number: i + 1,
                  domain: domain,
                  count: data.countOf(domain.id),
                  drillCount: data.drillCountOf(domain.id),
                  accuracy: data.accuracy[domain.id] ?? Accuracy.empty,
                  onTap: () => _startDomains(data, {domain.id}),
                ),
              SizedBox(height: t.space6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _certified,
                onChanged: _setCertified,
                title: Text('この試験は取得済み', style: t.body),
                subtitle: Text('ホームの全冠の進捗に数えます', style: t.caption),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 分野1つ分の行。分野名・正答率・バー・問題数を出す
class _DomainRow extends StatelessWidget {
  const _DomainRow({
    required this.number,
    required this.domain,
    required this.count,
    required this.drillCount,
    required this.accuracy,
    required this.onTap,
  });

  /// 分野の番号（レーダーチャートの軸の番号と対応させる）
  final int number;
  final Domain domain;

  /// 本番形式の問題数
  final int count;

  /// 一問一答の問題数
  final int drillCount;
  final Accuracy accuracy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rate = accuracy.rate;
    final enabled = count > 0;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: t.space4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.hairline, width: t.borderThin),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('$number. ${domain.name}', style: t.body)),
                SizedBox(width: t.space3),
                Text(
                  rate == null ? '未回答' : '${(rate * 100).round()}%',
                  style: t.numeric(
                    t.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: rate == null ? t.textSecondary : t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space2),
            ThinBar(value: rate ?? 0),
            SizedBox(height: t.space2),
            Text(
              [
                '比重 ${domain.weight}%',
                '本番形式 $count問',
                if (drillCount > 0) '一問一答 $drillCount問',
                if (accuracy.answered > 0) '解いた ${accuracy.answered}問',
              ].join('・'),
              style: t.caption,
            ),
          ],
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
    final t = context.tokens;
    // 解くのは本番形式の問題だけなので、一問一答は数えない
    final total = widget.data.examFormat
        .where((q) => _picked.contains(q.domainId))
        .length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space5, 0, t.space5, t.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('解く分野を選ぶ', style: t.title),
            SizedBox(height: t.space2),
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
                      title: Text(d.name, style: t.body),
                      subtitle: Text(
                        '${widget.data.countOf(d.id)}問',
                        style: t.caption,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: t.space3),
            FilledButton(
              onPressed: total == 0
                  ? null
                  : () => Navigator.of(context).pop(_picked),
              child: Text(total == 0 ? '分野を選んでください' : '$total問を解く'),
            ),
          ],
        ),
      ),
    );
  }
}
