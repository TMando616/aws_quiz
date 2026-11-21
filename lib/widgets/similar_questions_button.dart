import 'package:material_ui/material_ui.dart';

import '../data/question_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../screens/quiz_screen.dart';

/// 「類題に挑戦」ボタン。同じ類題のグループの問題がほかにあるときだけ表示する。
/// 間違えた論点を、条件を変えた問題ですぐに確かめられるようにするため
class SimilarQuestionsButton extends StatefulWidget {
  const SimilarQuestionsButton({
    super.key,
    required this.exam,
    required this.question,
  });

  final Exam exam;
  final Question question;

  @override
  State<SimilarQuestionsButton> createState() => _SimilarQuestionsButtonState();
}

class _SimilarQuestionsButtonState extends State<SimilarQuestionsButton> {
  List<Question> _similar = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SimilarQuestionsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) _load();
  }

  Future<void> _load() async {
    final group = widget.question.group;
    if (group == null) {
      setState(() => _similar = const []);
      return;
    }
    final all = await QuestionRepository().load(widget.exam.id);
    if (!mounted) return;
    setState(() {
      _similar = [
        for (final q in all)
          if (q.group == group && q.id != widget.question.id) q,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_similar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizScreen(
              exam: widget.exam,
              questions: _similar,
              title: '類題',
            ),
          ),
        ),
        icon: const Icon(Icons.repeat),
        label: Text('類題に挑戦（${_similar.length}問）'),
      ),
    );
  }
}
