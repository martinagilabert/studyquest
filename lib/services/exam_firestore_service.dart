import 'package:cloud_firestore/cloud_firestore.dart';

class ExamFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createExam({
    required String uid,
    required String sourceChatId,
    required String sourceChatTitle,
    required String customPrompt,
    required List<Map<String, dynamic>> questions,
  }) async {
    final examRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_exams')
        .add({
      'sourceChatId': sourceChatId,
      'sourceChatTitle': sourceChatTitle,
      'customPrompt': customPrompt,
      'questions': questions,
      'userAnswers': {},
      'score': 0,
      'totalQuestions': questions.length,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return examRef.id;
  }

  Future<void> completeExam({
    required String uid,
    required String examId,
    required Map<String, dynamic> userAnswers,
    required int score,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_exams')
        .doc(examId)
        .update({
      'userAnswers': userAnswers,
      'score': score,
      'completed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getExams(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_exams')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
}