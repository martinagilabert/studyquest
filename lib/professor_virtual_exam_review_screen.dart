import 'package:flutter/material.dart';

class ProfessorVirtualExamReviewScreen extends StatelessWidget {
  final String title;
  final int score;
  final int totalQuestions;
  final List<Map<String, dynamic>> questions;
  final Map<String, dynamic> userAnswers;

  const ProfessorVirtualExamReviewScreen({
    super.key,
    required this.title,
    required this.score,
    required this.totalQuestions,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: questions.isEmpty
          ? const Center(
              child: Text('Este examen no tiene preguntas guardadas.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Resultado del examen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$score / $totalQuestions',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final questionIndex = index - 1;
                final question = questions[questionIndex];
                final questionText = question['question'] ?? '';
                final options =
                    List<String>.from(question['options'] ?? const []);
                final correctAnswer = question['correctAnswer'] ?? '';
                final selectedAnswer =
                    userAnswers[questionIndex.toString()]?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pregunta ${questionIndex + 1}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          questionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...options.map((option) {
                          final isCorrect = option == correctAnswer;
                          final isSelected = option == selectedAnswer;

                          Color? tileColor;
                          IconData? icon;
                          Color? iconColor;

                          if (isCorrect) {
                            tileColor = Colors.green.withOpacity(0.15);
                            icon = Icons.check_circle;
                            iconColor = Colors.green;
                          } else if (isSelected && !isCorrect) {
                            tileColor = Colors.red.withOpacity(0.15);
                            icon = Icons.cancel;
                            iconColor = Colors.red;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: tileColor != null
                                    ? Colors.transparent
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                if (icon != null)
                                  Icon(icon, color: iconColor, size: 20),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        Text(
                          selectedAnswer == null
                              ? 'No respondida'
                              : 'Tu respuesta: $selectedAnswer',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Correcta: $correctAnswer',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}