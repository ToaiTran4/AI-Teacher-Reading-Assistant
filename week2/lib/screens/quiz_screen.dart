import 'package:flutter/material.dart';
import '../models/quiz_model.dart';

class QuizScreen extends StatefulWidget {
  final List<QuizModel> questions;

  const QuizScreen({super.key, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;

  void _answerQuestion(int index) {
    if (_isAnswered) return; // Không cho chọn lại

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;

      // Kiểm tra đúng sai
      if (index == widget.questions[_currentQuestionIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _isAnswered = false;
      });
    } else {
      // Đã hết câu hỏi -> Hiện bảng điểm
      _showScoreDialog();
    }
  }

  void _showScoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết quả'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              '$_score / ${widget.questions.length}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _score == widget.questions.length
                  ? 'Tuyệt vời! Bạn đã hiểu bài hoàn hảo.'
                  : _score >= widget.questions.length / 2
                      ? 'Khá tốt! Hãy cố gắng hơn nhé.'
                      : 'Cần đọc kỹ lại bài này nha!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Tắt dialog
              Navigator.of(context).pop(); // Thoát màn hình Quiz
            },
            child: const Text('Hoàn thành'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Kiểm tra kiến thức (${_currentQuestionIndex + 1}/${widget.questions.length})'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / widget.questions.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hiển thị câu hỏi
            Text(
              question.question,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Hiển thị các đáp án
            ...List.generate(question.options.length, (index) {
              final isSelected = _selectedOptionIndex == index;
              final isCorrect = index == question.correctIndex;

              // Logic màu sắc:
              // - Mặc định: Trắng
              // - Đã trả lời + Đúng: Xanh lá
              // - Đã trả lời + Sai (mà mình chọn): Đỏ
              // - Đã trả lời + Sai (đáp án đúng mà mình không chọn): Xanh lá (để user biết đáp án đúng)

              Color bgColor = Colors.white;
              Color borderColor = Colors.grey.shade300;
              IconData? icon;

              if (_isAnswered) {
                if (isCorrect) {
                  bgColor = Colors.green.shade50;
                  borderColor = Colors.green;
                  icon = Icons.check_circle;
                } else if (isSelected) {
                  bgColor = Colors.red.shade50;
                  borderColor = Colors.red;
                  icon = Icons.cancel;
                }
              } else if (isSelected) {
                borderColor = Theme.of(context).primaryColor;
                bgColor = Theme.of(context).primaryColor.withOpacity(0.1);
              }

              return GestureDetector(
                onTap: () => _answerQuestion(index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.options[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (icon != null) Icon(icon, color: borderColor),
                    ],
                  ),
                ),
              );
            }),

            // Hiển thị giải thích khi đã trả lời
            if (_isAnswered)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Giải thích:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(question.explanation,
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Nút Next
            if (_isAnswered)
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  child: Text(
                    _currentQuestionIndex < widget.questions.length - 1
                        ? 'Câu tiếp theo'
                        : 'Xem kết quả',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
