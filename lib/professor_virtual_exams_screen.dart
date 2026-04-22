import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/chat_firestore_service.dart';
import 'services/exam_firestore_service.dart';
import 'ai_service.dart';
import 'professor_virtual_exam_take_screen.dart';
import 'professor_virtual_exam_history_screen.dart';

class ProfessorVirtualExamsScreen extends StatefulWidget {
  const ProfessorVirtualExamsScreen({super.key});

  @override
  State<ProfessorVirtualExamsScreen> createState() =>
      _ProfessorVirtualExamsScreenState();
}

class _ProfessorVirtualExamsScreenState
    extends State<ProfessorVirtualExamsScreen> {
  final ChatFirestoreService _chatService = ChatFirestoreService();
  final ExamFirestoreService _examService = ExamFirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _promptController = TextEditingController();

  String? _selectedChatId;
  String? _selectedChatTitle;
  bool _generating = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateExam() async {
    if (_currentUser == null || _selectedChatId == null) return;

    setState(() {
      _generating = true;
    });

    try {
      final messages = await _chatService.getMessagesOnce(
        uid: _currentUser!.uid,
        chatId: _selectedChatId!,
      );

      final transcript = messages.map((msg) {
        final role = msg['role'] ?? 'unknown';
        final content = msg['content'] ?? '';
        return '$role: $content';
      }).join('\n');

      final questions = await AiService.generateExam(
        transcript: transcript,
        customPrompt: _promptController.text.trim(),
      );

      if (questions.isEmpty) {
        throw Exception('La IA no devolvió preguntas válidas.');
      }

      final examId = await _examService.createExam(
        uid: _currentUser!.uid,
        sourceChatId: _selectedChatId!,
        sourceChatTitle: _selectedChatTitle ?? 'Examen',
        customPrompt: _promptController.text.trim(),
        questions: questions,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfessorVirtualExamTakeScreen(
            examId: examId,
            questions: questions,
            title: _selectedChatTitle ?? 'Examen',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar el examen: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exámenes')),
        body: const Center(
          child: Text('No hay un usuario autenticado.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exámenes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de exámenes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfessorVirtualExamHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: _chatService.getChats(_currentUser!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final chats = snapshot.data?.docs ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Crea un examen tipo test a partir de uno de tus chats. También puedes añadir un prompt para indicar el nivel o el tipo de preguntas.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '1. Elige un chat',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (chats.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Todavía no tienes chats guardados para crear un examen.',
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedChatId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    hint: const Text('Selecciona un chat'),
                    items: chats.map((chat) {
                      final data = chat.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Sin título';

                      return DropdownMenuItem<String>(
                        value: chat.id,
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      final selected =
                          chats.firstWhere((doc) => doc.id == value);
                      final data = selected.data() as Map<String, dynamic>;

                      setState(() {
                        _selectedChatId = value;
                        _selectedChatTitle = data['title'] ?? 'Sin título';
                      });
                    },
                  ),
                const SizedBox(height: 20),
                const Text(
                  '2. Escribe un prompt opcional',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Ejemplo: Hazme 5 preguntas fáciles sobre lo más importante.',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.blue.shade300, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: chats.isEmpty || _generating
                        ? null
                        : () {
                            if (_selectedChatId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Selecciona un chat primero.'),
                                ),
                              );
                              return;
                            }

                            _generateExam();
                          },
                    icon: _generating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.quiz),
                    label: Text(_generating ? 'Generando...' : 'Generar examen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}