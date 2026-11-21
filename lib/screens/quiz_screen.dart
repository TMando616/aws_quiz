import 'package:material_ui/material_ui.dart';

import '../ads/ad_consent.dart';
import '../ads/banner_ad_view.dart';
import '../ads/interstitial_ad_manager.dart';
import '../data/question_repository.dart';
import '../models/question.dart';
import '../settings/quiz_layout.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.exam});

  final String exam;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<Question>> _future;

  int _index = 0; // 今何問目か
  final Set<int> _selected = {}; // 選んでいる選択肢
  bool _answered = false; // 「回答する」を押したか
  int _correctCount = 0;
  bool _finished = false;

  final _interstitial = InterstitialAdManager();
  final _layoutSetting = QuizLayoutSetting();
  QuizLayout _layout = QuizLayout.tabs;
  bool _privacyOptionsRequired = false; // メニューに「広告のプライバシー設定」を出すか

  // 選択肢スワイプモードで使う
  final _questionScroll = ScrollController();
  PageController _choicePager = PageController(viewportFraction: 0.88);
  int _choicePage = 0;

  @override
  void initState() {
    super.initState();
    _future = QuestionRepository().load(widget.exam);
    _interstitial.load();
    _layoutSetting.load().then((layout) {
      if (mounted) setState(() => _layout = layout);
    });
    _checkPrivacyOptions();
  }

  Future<void> _checkPrivacyOptions() async {
    // 同意の確認が終わってからでないと、設定が必要かどうかわからない
    await AdConsent.ready;
    final required = await AdConsent.isPrivacyOptionsRequired();
    if (mounted) setState(() => _privacyOptionsRequired = required);
  }

  @override
  void dispose() {
    _interstitial.dispose();
    _questionScroll.dispose();
    _choicePager.dispose();
    super.dispose();
  }

  void _changeLayout(QuizLayout layout) {
    setState(() => _layout = layout);
    _layoutSetting.save(layout);
  }

  void _toggle(Question q, int i) {
    if (_answered) return;
    setState(() {
      if (q.isMultiple) {
        _selected.contains(i) ? _selected.remove(i) : _selected.add(i);
      } else {
        _selected
          ..clear()
          ..add(i);
      }
    });
  }

  void _submit(Question q) {
    setState(() {
      _answered = true;
      if (q.isCorrect(_selected)) _correctCount++;
    });
    // スワイプモードでは解説が問題文の下に出るので、そこまでスクロールする
    if (_layout == QuizLayout.swipeChoices) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_questionScroll.hasClients) return;
        _questionScroll.animateTo(
          _questionScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _next(int total) {
    if (_index + 1 >= total) {
      // 最後の問題のあとは、全画面広告を挟んでから結果画面へ
      _interstitial.show(
        onDone: () {
          if (mounted) setState(() => _finished = true);
        },
      );
      return;
    }
    setState(() {
      _index++;
      _resetForQuestion();
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correctCount = 0;
      _finished = false;
      _resetForQuestion();
    });
  }

  /// 次の問題に移るときに、選択状態とスクロール位置を戻す
  void _resetForQuestion() {
    _selected.clear();
    _answered = false;
    _choicePage = 0;
    // PageControllerは位置を持っているので作り直す（古い方は描画後に破棄）
    final old = _choicePager;
    _choicePager = PageController(viewportFraction: 0.88);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    if (_questionScroll.hasClients) _questionScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('${widget.exam} 一問一答')),
            body: Center(child: Text('問題を読み込めませんでした\n${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final questions = snapshot.data!;
        if (_finished) return _buildResult(questions.length);
        return _buildQuestion(questions[_index], questions.length);
      },
    );
  }

  Widget _buildQuestion(Question q, int total) {
    final canSubmit = q.isMultiple
        ? _selected.length == q.answers.length
        : _selected.isNotEmpty;

    final body = switch (_layout) {
      QuizLayout.tabs => _buildTabsBody(q),
      QuizLayout.swipeChoices => _buildSwipeBody(q),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam} 一問一答（${_index + 1}/$total）'),
        actions: [_buildMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / total),
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _answered
                      ? () => _next(total)
                      : (canSubmit ? () => _submit(q) : null),
                  child: Text(
                    !_answered
                        ? '回答する'
                        : (_index + 1 >= total ? '結果を見る' : '次の問題へ'),
                  ),
                ),
              ),
            ),
            const BannerAdView(),
          ],
        ),
      ),
    );
  }

  /// 右上のメニュー。レイアウトの切り替えと、広告のプライバシー設定
  Widget _buildMenu() {
    return PopupMenuButton<QuizLayout>(
      icon: const Icon(Icons.view_agenda_outlined),
      tooltip: '表示の切り替え',
      onSelected: _changeLayout,
      itemBuilder: (context) => [
        for (final layout in QuizLayout.values)
          CheckedPopupMenuItem(
            value: layout,
            checked: layout == _layout,
            child: Text(layout.label),
          ),
        if (_privacyOptionsRequired) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            onTap: AdConsent.showPrivacyOptions,
            child: Text('広告のプライバシー設定'),
          ),
        ],
      ],
    );
  }

  // ---------- 問題と選択肢を分けるモード ----------

  Widget _buildTabsBody(Question q) {
    // keyに問題番号を入れて、問題が変わるたびに「問題」タブに戻す
    return DefaultTabController(
      key: ValueKey('tabs-$_index'),
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '問題'),
              Tab(text: '選択肢'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildQuestionText(q),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuestionSummary(q),
                      const SizedBox(height: 12),
                      for (var i = 0; i < q.choices.length; i++)
                        _buildChoice(q, i),
                      if (_answered) _buildExplanation(q),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 選択肢タブの上に出す、問題文の最後の一文（「〜はどれか。」の部分）
  Widget _buildQuestionSummary(Question q) {
    final theme = Theme.of(context);
    final sentences = q.question
        .split('。')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final last = sentences.isEmpty ? q.question : '${sentences.last}。';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(last, style: theme.textTheme.bodyMedium),
          if (q.isMultiple)
            Text('（${q.answers.length}つ選択）', style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }

  // ---------- 選択肢だけスワイプするモード ----------

  Widget _buildSwipeBody(Question q) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _questionScroll,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildQuestionText(q),
                if (_answered) _buildExplanation(q),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _choicePager,
            itemCount: q.choices.length,
            onPageChanged: (page) => setState(() => _choicePage = page),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildChoice(q, i, expand: true),
            ),
          ),
        ),
        _buildChoiceIndicator(q),
      ],
    );
  }

  /// 選択肢カードの下に出す A B C D のボタン。今のページと選択状態がわかり、タップでそのカードへ移動する
  Widget _buildChoiceIndicator(Question q) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < q.choices.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(String.fromCharCode(65 + i)),
                selected: i == _choicePage,
                showCheckmark: false,
                avatar: _selected.contains(i)
                    ? Icon(Icons.check, size: 16, color: scheme.primary)
                    : null,
                onSelected: (_) => _choicePager.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 両方のモードで使う部品 ----------

  Widget _buildQuestionText(Question q) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          q.domain,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(q.question, style: theme.textTheme.bodyLarge),
        if (q.isMultiple) ...[
          const SizedBox(height: 8),
          Text('（${q.answers.length}つ選択）', style: theme.textTheme.labelLarge),
        ],
      ],
    );
  }

  Widget _buildExplanation(Question q) {
    final theme = Theme.of(context);
    final isCorrect = q.isCorrect(_selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          isCorrect ? '⭕ 正解！' : '❌ 不正解',
          style: theme.textTheme.titleLarge?.copyWith(
            color: isCorrect ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(q.explanation, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  /// 選択肢のカード。[expand] がtrueならカードの高さいっぱいに広げ、長い文はカード内でスクロールする
  Widget _buildChoice(Question q, int i, {bool expand = false}) {
    final selected = _selected.contains(i);
    final isAnswer = q.answers.contains(i);

    // 回答後は正解を緑、選んだ不正解を赤で表示する
    Color? color;
    if (_answered && isAnswer) {
      color = Colors.green.shade100;
    } else if (_answered && selected) {
      color = Colors.red.shade100;
    } else if (selected) {
      color = Theme.of(context).colorScheme.primaryContainer;
    }

    final label = Text(
      String.fromCharCode(65 + i), // A, B, C, D
      style: Theme.of(context).textTheme.titleMedium,
    );
    final icon = Icon(
      q.isMultiple
          ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
          : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
    );

    if (!expand) {
      return Card(
        color: color,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: label,
          title: Text(q.choices[i]),
          trailing: icon,
          onTap: () => _toggle(q, i),
        ),
      );
    }

    return Card(
      color: color,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _toggle(q, i),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    q.choices[i],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              icon,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(int total) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.exam} 結果')),
      bottomNavigationBar: const SafeArea(child: BannerAdView()),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$total問中', style: theme.textTheme.titleMedium),
            Text(
              '$_correctCount問 正解',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _restart, child: const Text('もう一度解く')),
          ],
        ),
      ),
    );
  }
}
