import 'package:material_ui/material_ui.dart';

import '../ads/ad_consent.dart';
import '../ads/banner_ad_view.dart';
import '../ads/interstitial_ad_manager.dart';
import '../data/study_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../settings/quiz_layout.dart';
import '../theme/app_tokens.dart';
import '../widgets/design_parts.dart';
import '../widgets/domain_accuracy_bar.dart';
import '../widgets/explanation_view.dart';
import '../widgets/related_questions_buttons.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.exam,
    required this.questions,
    required this.title,
  });

  final Exam exam;

  /// 出題する問題（出題範囲の絞り込みや並べ替えは呼び出し側で行う）
  final List<Question> questions;

  /// AppBarに出す出題範囲の名前（例: 全分野）
  final String title;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0; // 今何問目か
  final Set<int> _selected = {}; // 選んでいる選択肢
  bool _answered = false; // 「回答する」を押したか
  int _correctCount = 0;

  /// 問題の番号 → 正解したか（結果画面の分野別の内訳に使う）
  final Map<int, bool> _results = {};
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
    // 一問一答はテンポを優先し、選択肢をタップした時点で回答する
    if (q.isDrill) {
      _selected
        ..clear()
        ..add(i);
      _submit(q);
      return;
    }
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
    final correct = q.isCorrect(_selected);
    setState(() {
      _answered = true;
      if (correct) _correctCount++;
      _results[_index] = correct;
    });
    _record(q, correct);
    // スワイプモードでは解説が問題文の下に出るので、そこまでスクロールする
    if (_layout == QuizLayout.swipeChoices && !q.isDrill) {
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

  /// 回答を端末のDBに記録する。保存に失敗しても出題は続けられるようにする
  Future<void> _record(Question q, bool correct) async {
    try {
      final repo = await StudyRepository.instance();
      await repo.recordAnswer(
        examId: widget.exam.id,
        questionId: q.id,
        correct: correct,
        mode: q.isDrill ? StudyMode.drill : StudyMode.practice,
      );
    } catch (e) {
      debugPrint('回答の記録に失敗: $e');
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
      _results.clear();
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
    final questions = widget.questions;
    if (_finished) return _buildResult(questions.length);
    return _buildQuestion(questions[_index], questions.length);
  }

  Widget _buildQuestion(Question q, int total) {
    final t = context.tokens;
    final canSubmit = q.isMultiple
        ? _selected.length == q.answers.length
        : _selected.isNotEmpty;

    // 一問一答は短いので、表示モードに関係なく1画面にまとめる
    final body = q.isDrill
        ? _buildDrillBody(q)
        : switch (_layout) {
            QuizLayout.tabs => _buildTabsBody(q),
            QuizLayout.swipeChoices => _buildSwipeBody(q),
          };

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam.shortName} ${widget.title}'),
        actions: [?_buildMenu(q)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(total),
            Expanded(
              // 次の問題へ進むとき、カードを1枚めくるように横にスライドさせる（DESIGN.md 6章）
              child: AnimatedSwitcher(
                duration: t.cardFlip,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_index);
                  final shift = incoming ? t.cardFlipShift : -t.cardFlipShift;
                  return SlideTransition(
                    position: Tween(
                      begin: Offset(shift, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_index), child: body),
              ),
            ),
            // 一問一答は選択肢をタップした時点で回答するので、答えるまではボタンを見せない。
            // ただし場所は空けておき、ボタンが出ても選択肢の位置が動かないようにする
            Visibility(
              visible: !q.isDrill || _answered,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space5,
                  t.space3,
                  t.space5,
                  t.space3,
                ),
                child: FilledButton(
                  onPressed: _answered
                      ? () => _next(total)
                      : (canSubmit ? () => _submit(q) : null),
                  child: Text(
                    !_answered
                        ? (q.isDrill ? '選択肢をタップして回答' : '回答する')
                        : (_index + 1 >= total ? '結果を見る' : '次へ'),
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

  /// 上部の進捗。マーカーの黄色のバーと、等幅の「何問目 / 全部で何問」
  Widget _buildProgress(int total) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space5, t.space2, t.space5, t.space2),
      child: Row(
        children: [
          Expanded(child: ThinBar(value: (_index + 1) / total)),
          SizedBox(width: t.space3),
          Text(
            '${_index + 1} / $total',
            style: t.caption.copyWith(color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  /// 右上のメニュー。レイアウトの切り替えと、広告のプライバシー設定。
  /// 一問一答は表示モードに関係なく1画面なので、切り替えは出さない（項目が無ければメニューごと出さない）
  Widget? _buildMenu(Question q) {
    final showLayouts = !q.isDrill;
    if (!showLayouts && !_privacyOptionsRequired) return null;
    return PopupMenuButton<QuizLayout>(
      icon: Icon(showLayouts ? Icons.view_agenda_outlined : Icons.more_horiz),
      tooltip: showLayouts ? '表示の切り替え' : 'メニュー',
      onSelected: _changeLayout,
      itemBuilder: (context) => [
        if (showLayouts)
          for (final layout in QuizLayout.values)
            CheckedPopupMenuItem(
              value: layout,
              checked: layout == _layout,
              child: Text(layout.label),
            ),
        if (_privacyOptionsRequired) ...[
          if (showLayouts) const PopupMenuDivider(),
          const PopupMenuItem(
            onTap: AdConsent.showPrivacyOptions,
            child: Text('広告のプライバシー設定'),
          ),
        ],
      ],
    );
  }

  // ---------- 一問一答 ----------

  /// 問題のカードを上に、選択肢を親指の届く下に寄せる。回答後は解説が下に続く
  Widget _buildDrillBody(Question q) {
    final t = context.tokens;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(t.space5, t.space3, t.space5, 0),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionCard(child: _buildQuestionText(q)),
                SizedBox(height: t.space5),
                const Spacer(),
                ..._buildChoiceList(q),
              ],
            ),
          ),
        ),
        if (_answered)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(t.space5, 0, t.space5, t.space6),
            sliver: SliverToBoxAdapter(child: _buildExplanation(q)),
          ),
      ],
    );
  }

  // ---------- 問題と選択肢を分けるモード ----------

  Widget _buildTabsBody(Question q) {
    final t = context.tokens;
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
                  padding: EdgeInsets.all(t.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuestionCard(child: _buildQuestionText(q)),
                      SizedBox(height: t.space3),
                      // 読み終えたら、そのまま選択肢のタブへ進めるようにする
                      Builder(
                        builder: (context) => Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                DefaultTabController.of(context).animateTo(1),
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('選択肢へ'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.all(t.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuestionSummary(q),
                      SizedBox(height: t.space4),
                      ..._buildChoiceList(q),
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
    final t = context.tokens;
    final sentences = q.question
        .split('。')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final last = sentences.isEmpty ? q.question : '${sentences.last}。';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: last),
          if (q.isMultiple)
            TextSpan(
              text: '（${q.answers.length}つ選択）',
              style: t.body.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
      style: t.body,
    );
  }

  // ---------- 選択肢だけスワイプするモード ----------

  Widget _buildSwipeBody(Question q) {
    final t = context.tokens;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _questionScroll,
            padding: EdgeInsets.all(t.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionCard(child: _buildQuestionText(q)),
                if (_answered) _buildExplanation(q),
              ],
            ),
          ),
        ),
        SizedBox(
          height: t.swipeChoiceHeight,
          child: PageView.builder(
            controller: _choicePager,
            itemCount: q.choices.length,
            onPageChanged: (page) => setState(() => _choicePage = page),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space1),
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
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < q.choices.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space1),
              child: ChoiceChip(
                label: Text(String.fromCharCode(65 + i)),
                selected: i == _choicePage,
                showCheckmark: false,
                avatar: _selected.contains(i)
                    ? Icon(Icons.check, color: t.ink)
                    : null,
                onSelected: (_) => _choicePager.animateToPage(
                  i,
                  duration: t.cardFlip,
                  curve: Curves.easeOut,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 両方のモードで使う部品 ----------

  /// 問題のカードの中身：分野（と一問一答の印）→ ポイント → 問題文
  Widget _buildQuestionText(Question q) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [
            if (q.isDrill) '一問一答',
            widget.exam.domainById(q.domainId)?.name ?? '',
          ].join('・'),
          style: t.label,
        ),
        // 設計判断のポイントには、単語帳のマーカーのような黄色の下線を引く
        if (q.point case final point?) ...[
          SizedBox(height: t.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: t.marker, width: t.markerUnderline),
                ),
              ),
              child: Text(
                point,
                style: t.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        SizedBox(height: t.space3),
        Text(q.question, style: t.question),
        if (q.isMultiple) ...[
          SizedBox(height: t.space2),
          Text(
            '（${q.answers.length}つ選択）',
            style: t.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Widget _buildExplanation(Question q) => ExplanationView(
    question: q,
    selected: _selected,
    action: RelatedQuestionsButtons(exam: widget.exam, question: q),
  );

  /// ○×の問題か（選択肢の文に記号が入っているので、A・B を出さない）
  static bool _isTrueFalse(Question q) =>
      q.choices.length == 2 && q.choices.first.text.startsWith('○');

  ChoiceState _stateOf(Question q, int i) {
    final selected = _selected.contains(i);
    if (!_answered) return selected ? ChoiceState.selected : ChoiceState.idle;
    if (q.answers.contains(i)) return ChoiceState.correct;
    if (selected) return ChoiceState.wrong;
    return ChoiceState.inactive;
  }

  List<Widget> _buildChoiceList(Question q) {
    final t = context.tokens;
    return [
      for (var i = 0; i < q.choices.length; i++) ...[
        if (i > 0) SizedBox(height: t.space2),
        _buildChoice(q, i),
      ],
    ];
  }

  Widget _buildChoice(Question q, int i, {bool expand = false}) => ChoiceTile(
    letter: _isTrueFalse(q) ? '' : String.fromCharCode(65 + i),
    text: q.choices[i].text,
    state: _stateOf(q, i),
    multiple: q.isMultiple,
    expand: expand,
    onTap: _answered ? null : () => _toggle(q, i),
  );

  Widget _buildResult(int total) {
    final t = context.tokens;
    final rate = total == 0 ? 0 : _correctCount / total;

    // 分野ごとの出題数と正解数
    final answered = <String, int>{};
    final correct = <String, int>{};
    for (final e in _results.entries) {
      final domainId = widget.questions[e.key].domainId;
      answered.update(domainId, (v) => v + 1, ifAbsent: () => 1);
      if (e.value) correct.update(domainId, (v) => v + 1, ifAbsent: () => 1);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam.shortName} ${widget.title}の結果'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const SafeArea(child: BannerAdView()),
      body: ListView(
        padding: EdgeInsets.fromLTRB(t.space5, t.space5, t.space5, t.space6),
        children: [
          Text('${(rate * 100).round()}%', style: t.display),
          SizedBox(height: t.space1),
          Text('$total問中 $_correctCount問正解', style: t.caption),
          SizedBox(height: t.space6),
          const SectionLabel('分野ごとの内訳'),
          for (final d in widget.exam.domains)
            if (answered[d.id] case final n?)
              DomainAccuracyBar(
                name: d.name,
                accuracy: Accuracy(answered: n, correct: correct[d.id] ?? 0),
              ),
          SizedBox(height: t.space6),
          FilledButton(onPressed: _restart, child: const Text('もう一度解く')),
          SizedBox(height: t.space2),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('試験トップに戻る'),
          ),
        ],
      ),
    );
  }
}
