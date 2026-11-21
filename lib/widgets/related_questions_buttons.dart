import 'package:material_ui/material_ui.dart';

import '../data/question_repository.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../screens/quiz_screen.dart';

/// 解説の下に出す、関連する問題へのボタン。関連する問題があるときだけ表示する
///
/// - 類題に挑戦：同じ類題のグループ（[Question.group]）で、同じ種類の問題
/// - ポイント別の一問一答：本番形式の問題から、分解した一問一答へ
/// - 元の問題に挑戦：一問一答から、分解元の本番形式の問題へ
class RelatedQuestionsButtons extends StatefulWidget {
  const RelatedQuestionsButtons({
    super.key,
    required this.exam,
    required this.question,
  });

  final Exam exam;
  final Question question;

  @override
  State<RelatedQuestionsButtons> createState() =>
      _RelatedQuestionsButtonsState();
}

class _RelatedQuestionsButtonsState extends State<RelatedQuestionsButtons> {
  List<Question> _similar = const [];
  List<Question> _drills = const [];
  Question? _source;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RelatedQuestionsButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) _load();
  }

  Future<void> _load() async {
    final q = widget.question;
    final all = await QuestionRepository().load(widget.exam.id);
    if (!mounted) return;
    setState(() {
      _similar = [
        if (q.group != null)
          for (final other in all)
            if (other.group == q.group &&
                other.id != q.id &&
                other.type == q.type)
              other,
      ];
      _drills = [
        if (!q.isDrill)
          for (final other in all)
            if (other.isDrill && other.source == q.id) other,
      ];
      _source = q.isDrill && q.source != null
          ? all.where((o) => o.id == q.source).firstOrNull
          : null;
    });
  }

  void _open(List<Question> questions, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(exam: widget.exam, questions: questions, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final buttons = [
      if (_drills.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _open(_drills, 'ポイント別の一問一答'),
          icon: const Icon(Icons.bolt),
          label: Text('ポイント別の一問一答（${_drills.length}問）'),
        ),
      if (source != null)
        OutlinedButton.icon(
          onPressed: () => _open([source], '元の問題'),
          icon: const Icon(Icons.article_outlined),
          label: const Text('元の問題（本番形式）に挑戦'),
        ),
      if (_similar.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _open(_similar, '類題'),
          icon: const Icon(Icons.repeat),
          label: Text('類題に挑戦（${_similar.length}問）'),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }
}
