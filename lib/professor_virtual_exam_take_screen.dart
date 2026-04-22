import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/exam_firestore_service.dart';

class ProfessorVirtualExamTakeScreen extends StatefulWidget {
  final String examId;
  final List<Map<String, dynamic>> questions;
  final String title;

  const ProfessorVirtualExamTakeScreen({
    super.key,
    required this.examId,
    required this.questions,
    required this.title,
  });

  @override
  State<ProfessorVirtualExamTakeScreen> createState() =>
      _ProfessorVirtualExamTakeScreenState();
}

class _ProfessorVirtualExamTakeScreenState
    extends State<ProfessorVirtualExamTakeScreen> {
  final Map<int, String> selectedAnswers = {};
  final ExamFirestoreService _examService = ExamFirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool submitted = false;
  bool saving = false;

  int get score {
    int total = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final correct = widget.questions[i]['correctAnswer'];
      final selected = selectedAnswers[i];
      if (selected == correct) total++;
    }
    return total;
  }

  Future<void> _submitExam() async {
    if (_currentUser == null) return;

    setState(() {
      saving = true;
    });

    try {
      final answersMap = <String, dynamic>{};
      selectedAnswers.forEach((key, value) {
        answersMap[key.toString()] = value;
      });

      await _examService.completeExam(
        uid: _currentUser!.uid,
        examId: widget.examId,
        userAnswers: answersMap,
        score: score,
      );

      if (!mounted) return;

      setState(() {
        submitted = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el examen: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: questions.isEmpty
          ? const Center(
              child: Text('No se pudieron generar preguntas.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questions.length + 1,
              itemBuilder: (context, index) {
                if (index == questions.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 30),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: submitted || saving ? null : _submitExam,
                            child: saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Corregir examen'),
                          ),
                        ),
                        if (submitted) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Tu nota: $score / ${questions.length}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final question = questions[index];
                final questionText = question['question'] ?? '';
                final options =
                    List<String>.from(question['options'] ?? const []);
                final correctAnswer = question['correctAnswer'] ?? '';

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
                          'Pregunta ${index + 1}',
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
                          Color? tileColor;

                          if (submitted) {
                            if (option == correctAnswer) {
                              tileColor = Colors.green.withOpacity(0.15);
                            } else if (selectedAnswers[index] == option &&
                                option != correctAnswer) {
                              tileColor = Colors.red.withOpacity(0.15);
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: RadioListTile<String>(
                              value: option,
                              groupValue: selectedAnswers[index],
                              onChanged: submitted
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedAnswers[index] = value!;
                                      });
                                    },
                              title: Text(option),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}