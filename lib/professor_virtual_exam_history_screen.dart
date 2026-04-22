import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/exam_firestore_service.dart';
import 'professor_virtual_exam_review_screen.dart';

class ProfessorVirtualExamHistoryScreen extends StatefulWidget {
  const ProfessorVirtualExamHistoryScreen({super.key});

  @override
  State<ProfessorVirtualExamHistoryScreen> createState() =>
      _ProfessorVirtualExamHistoryScreenState();
}

class _ProfessorVirtualExamHistoryScreenState
    extends State<ProfessorVirtualExamHistoryScreen> {
  final ExamFirestoreService _examService = ExamFirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Sin fecha';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial de exámenes')),
        body: const Center(
          child: Text('No hay un usuario autenticado.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de exámenes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _examService.getExams(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final exams = snapshot.data?.docs ?? [];

          if (exams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 56,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Todavía no tienes exámenes guardados.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final exam = exams[index];
              final data = exam.data() as Map<String, dynamic>;

              final title = data['sourceChatTitle'] ?? 'Sin título';
              final score = data['score'] ?? 0;
              final totalQuestions = data['totalQuestions'] ?? 0;
              final completed = data['completed'] ?? false;
              final customPrompt = data['customPrompt'] ?? '';
              final updatedAt = data['updatedAt'] as Timestamp?;
              final questions =
                  List<Map<String, dynamic>>.from(data['questions'] ?? []);
              final userAnswers =
                  Map<String, dynamic>.from(data['userAnswers'] ?? {});

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.12),
                    child: Icon(
                      completed ? Icons.check_circle : Icons.pending,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        completed
                            ? 'Nota: $score / $totalQuestions'
                            : 'Pendiente de completar',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatDate(updatedAt)}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (customPrompt.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Prompt: $customPrompt',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                  onTap: completed
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfessorVirtualExamReviewScreen(
                                title: title,
                                score: score,
                                totalQuestions: totalQuestions,
                                questions: questions,
                                userAnswers: userAnswers,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}