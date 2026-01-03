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

  // --- Bảng màu hiện đại ---
  final Color _bgColor = const Color(0xFF1E1E2C); // Nền tối
  final Color _cardColor = const Color(0xFF2D2D44); // Nền card
  final Color _primaryColor = const Color(0xFF6C63FF); // Tím nổi bật
  final Color _correctColor = const Color(0xFF00E676); // Xanh lá neon
  final Color _wrongColor = const Color(0xFFFF5252); // Đỏ cam
  final Color _textColor = Colors.white; // Chữ trắng

  void _answerQuestion(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;

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
      _showScoreDialog();
    }
  }

  void _showScoreDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Kết quả', style: TextStyle(color: _textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              '$_score / ${widget.questions.length}',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor),
            ),
            const SizedBox(height: 12),
            Text(
              _score == widget.questions.length
                  ? 'Tuyệt vời! Bạn đã hiểu bài hoàn hảo.'
                  : _score >= widget.questions.length / 2
                      ? 'Khá tốt! Hãy cố gắng hơn nhé.'
                      : 'Cần đọc kỹ lại bài này nha!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Hoàn thành',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Câu hỏi ${_currentQuestionIndex + 1}/${widget.questions.length}',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6.0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / widget.questions.length,
                backgroundColor: _cardColor,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                minHeight: 6,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Phần hiển thị câu hỏi ---
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                question.question,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // --- Phần danh sách đáp án ---
            ...List.generate(question.options.length, (index) {
              final isSelected = _selectedOptionIndex == index;
              final isCorrect = index == question.correctIndex;

              // Xác định màu sắc dựa trên trạng thái
              Color borderColor = Colors.transparent;
              Color bgColor = _cardColor;
              IconData? icon;

              if (_isAnswered) {
                if (isCorrect) {
                  borderColor = _correctColor;
                  bgColor = _correctColor.withOpacity(0.2);
                  icon = Icons.check_circle;
                } else if (isSelected) {
                  borderColor = _wrongColor;
                  bgColor = _wrongColor.withOpacity(0.2);
                  icon = Icons.cancel;
                }
              } else {
                if (isSelected) {
                  borderColor = _primaryColor;
                  bgColor = _primaryColor.withOpacity(0.1);
                }
              }

              return GestureDetector(
                onTap: () => _answerQuestion(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(
                      color: borderColor == Colors.transparent
                          ? Colors.white12 // Viền mờ khi chưa chọn
                          : borderColor,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Vòng tròn A, B, C, D
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: borderColor == Colors.transparent
                              ? Colors.white10
                              : borderColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: icon != null
                            ? Icon(icon, size: 20, color: Colors.white)
                            : Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          question.options[index],
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // --- Phần giải thích ---
            if (_isAnswered)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amberAccent),
                        SizedBox(width: 8),
                        Text(
                          'Giải thích:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.explanation,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15,
                          height: 1.4),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // --- Nút Next ---
            if (_isAnswered)
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: _primaryColor.withOpacity(0.5),
                  ),
                  child: Text(
                    _currentQuestionIndex < widget.questions.length - 1
                        ? 'Câu tiếp theo'
                        : 'Xem kết quả',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
