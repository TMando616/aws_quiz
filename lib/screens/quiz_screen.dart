import 'package:material_ui/material_ui.dart';

import '../data/question_repository.dart';
import '../models/question.dart';

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

  @override
  void initState() {
    super.initState();
    _future = QuestionRepository().load(widget.exam);
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
  }

  void _next(int total) {
    setState(() {
      if (_index + 1 >= total) {
        _finished = true;
      } else {
        _index++;
        _selected.clear();
        _answered = false;
      }
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected.clear();
      _answered = false;
      _correctCount = 0;
      _finished = false;
    });
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final questions = snapshot.data!;
        if (_finished) return _buildResult(questions.length);
        return _buildQuestion(questions[_index], questions.length);
      },
    );
  }

  Widget _buildQuestion(Question q, int total) {
    final theme = Theme.of(context);
    final canSubmit = q.isMultiple
        ? _selected.length == q.answers.length
        : _selected.isNotEmpty;
    final isCorrect = q.isCorrect(_selected);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam} 一問一答（${_index + 1}/$total）'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      q.domain,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
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
                      _buildChoice(q, i),
                    if (_answered) ...[
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
                  ],
                ),
              ),
            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildChoice(Question q, int i) {
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

    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(
          String.fromCharCode(65 + i), // A, B, C, D
          style: Theme.of(context).textTheme.titleMedium,
        ),
        title: Text(q.choices[i]),
        trailing: Icon(
          q.isMultiple
              ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
              : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
        ),
        onTap: () => _toggle(q, i),
      ),
    );
  }

  Widget _buildResult(int total) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.exam} 結果')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$total問中', style: theme.textTheme.titleMedium),
            Text(
              '$_correctCount問 正解',
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _restart, child: const Text('もう一度解く')),
          ],
        ),
      ),
    );
  }
}
