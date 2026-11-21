import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../ads/banner_ad_view.dart';
import '../ads/interstitial_ad_manager.dart';
import '../data/study_repository.dart';
import '../logic/mock_builder.dart';
import '../models/exam.dart';
import '../models/question.dart';
import 'mock_result_screen.dart';

/// 模試の出題画面
///
/// - 1問ごとの正誤は出さず、最後にまとめて採点する
/// - 前の問題に戻れる。「一覧」から未回答の問題に飛べる
/// - 制限時間を過ぎたら自動で採点する
class MockScreen extends StatefulWidget {
  const MockScreen({super.key, required this.exam, required this.mockSet});

  final Exam exam;
  final MockSet mockSet;

  @override
  State<MockScreen> createState() => _MockScreenState();
}

class _MockScreenState extends State<MockScreen> {
  late final DateTime _startedAt;
  late final DateTime _endsAt;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  int _index = 0;

  /// 問題の番号 → 選んだ選択肢
  final Map<int, Set<int>> _selections = {};
  bool _grading = false;

  final _interstitial = InterstitialAdManager();
  final _scroll = ScrollController();

  List<Question> get _questions => widget.mockSet.questions;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _endsAt = _startedAt.add(widget.mockSet.timeLimit);
    _tick();
    // 残り時間は「終了時刻 − 今」で毎秒計算する。
    // アプリを裏に回してタイマーが止まっても、時間がズレないようにするため
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _interstitial.load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _interstitial.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tick() {
    final left = _endsAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _ticker?.cancel();
      setState(() => _remaining = Duration.zero);
      _grade(timeUp: true);
      return;
    }
    setState(() => _remaining = left);
  }

  void _toggle(Question q, int i) {
    setState(() {
      final selected = _selections.putIfAbsent(_index, () => {});
      if (q.isMultiple) {
        selected.contains(i) ? selected.remove(i) : selected.add(i);
      } else {
        selected
          ..clear()
          ..add(i);
      }
    });
  }

  bool _isAnswered(int i) {
    final q = _questions[i];
    final s = _selections[i];
    return s != null && s.length == q.answers.length;
  }

  int get _unansweredCount =>
      [for (var i = 0; i < _questions.length; i++) i]
          .where((i) => !_isAnswered(i))
          .length;

  void _goTo(int i) {
    setState(() => _index = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _confirmGrade() async {
    final unanswered = _unansweredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('採点しますか？'),
        content: Text(
          unanswered == 0
              ? '全問回答済みです。'
              : '未回答が$unanswered問あります。未回答は不正解として数えます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('採点する'),
          ),
        ],
      ),
    );
    if (ok == true) _grade();
  }

  Future<void> _grade({bool timeUp = false}) async {
    if (_grading) return;
    _grading = true;
    _ticker?.cancel();

    final result = gradeMock(
      examId: widget.exam.id,
      questions: _questions,
      selections: _selections,
      startedAt: _startedAt,
      duration: DateTime.now().difference(_startedAt),
    );
    await _save(result);
    if (!mounted) return;

    void openResult() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MockResultScreen(
            exam: widget.exam,
            result: result,
            questions: _questions,
            selections: _selections,
            timeUp: timeUp,
          ),
        ),
      );
    }

    // 結果画面の前に、全画面広告を1回だけ挟む（模試の途中には出さない）
    _interstitial.show(onDone: openResult);
  }

  /// 結果と回答を記録する。回答した問題だけを正答率の記録に残す
  Future<void> _save(MockResult result) async {
    try {
      final repo = await StudyRepository.instance();
      await repo.saveMockResult(result);
      for (var i = 0; i < _questions.length; i++) {
        final s = _selections[i];
        if (s == null || s.isEmpty) continue;
        await repo.recordAnswer(
          examId: widget.exam.id,
          questionId: _questions[i].id,
          correct: _questions[i].isCorrect(s),
          mode: StudyMode.mock,
        );
      }
    } catch (e) {
      debugPrint('模試の結果の保存に失敗: $e');
    }
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('模試を中断しますか？'),
        content: const Text('ここまでの回答は保存されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('中断する'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _openPalette() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _QuestionPalette(
        count: _questions.length,
        current: _index,
        isAnswered: _isAnswered,
        onTap: (i) {
          Navigator.of(context).pop();
          _goTo(i);
        },
      ),
    );
  }

  String _formatRemaining() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _questions[_index];
    final total = _questions.length;
    final selected = _selections[_index] ?? const <int>{};
    final isLast = _index == total - 1;
    final lowTime = _remaining.inMinutes < 5;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.exam.shortName} 模試（${_index + 1}/$total）'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: lowTime ? scheme.error : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRemaining(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: lowTime ? scheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_index + 1) / total),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(q.question, style: theme.textTheme.bodyLarge),
                      if (q.isMultiple) ...[
                        const SizedBox(height: 8),
                        Text(
                          '（${q.answers.length}つ選択）',
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                      const SizedBox(height: 16),
                      for (var i = 0; i < q.choices.length; i++)
                        _MockChoice(
                          label: String.fromCharCode(65 + i),
                          text: q.choices[i].text,
                          selected: selected.contains(i),
                          multiple: q.isMultiple,
                          onTap: () => _toggle(q, i),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '前の問題',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPalette,
                        icon: const Icon(Icons.grid_view, size: 18),
                        label: Text('一覧（未回答 $_unansweredCount）'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLast)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 52),
                        ),
                        onPressed: _confirmGrade,
                        child: const Text('採点'),
                      )
                    else
                      IconButton.filled(
                        onPressed: () => _goTo(_index + 1),
                        icon: const Icon(Icons.chevron_right),
                        tooltip: '次の問題',
                      ),
                  ],
                ),
              ),
              const BannerAdView(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 模試の選択肢。正誤の色は出さず、選んだかどうかだけを表示する
class _MockChoice extends StatelessWidget {
  const _MockChoice({
    required this.label,
    required this.text,
    required this.selected,
    required this.multiple,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(label, style: theme.textTheme.titleMedium),
        title: Text(text),
        trailing: Icon(
          multiple
              ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
              : (selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 問題の一覧。回答済みは塗りつぶし、今の問題は枠で示す
class _QuestionPalette extends StatelessWidget {
  const _QuestionPalette({
    required this.count,
    required this.current,
    required this.isAnswered,
    required this.onTap,
  });

  final int count;
  final int current;
  final bool Function(int) isAnswered;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var i = 0; i < count; i++)
              InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isAnswered(i)
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: i == current
                        ? Border.all(color: scheme.primary, width: 2)
                        : null,
                  ),
                  child: Text('${i + 1}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
