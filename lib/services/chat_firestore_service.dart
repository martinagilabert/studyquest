import 'package:cloud_firestore/cloud_firestore.dart';

class ChatFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createChat(String uid) async {
    final chatRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_chats')
        .add({
      'title': 'Nuevo chat',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'messageCount': 0,
    });

    return chatRef.id;
  }

  Future<void> addMessage({
    required String uid,
    required String chatId,
    required String role,
    required String content,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'role': role,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChatInfo({
    required String uid,
    required String chatId,
    required String lastMessage,
    required int messageCount,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_chats')
        .doc(chatId)
        .update({
      'lastMessage': lastMessage,
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': messageCount,
    });
  }

  Future<void> updateChatTitle({
    required String uid,
    required String chatId,
    required String title,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_chats')
        .doc(chatId)
        .update({
      'title': title,
    });
  }

  Stream<QuerySnapshot> getChats(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_chats')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
  Stream<QuerySnapshot> getMessages({
  required String uid,
  required String chatId,
}) {
  return _firestore
      .collection('users')
      .doc(uid)
      .collection('ai_chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots();
}
Future<List<Map<String, dynamic>>> getMessagesOnce({
  required String uid,
  required String chatId,
}) async {
  final snapshot = await _firestore
      .collection('users')
      .doc(uid)
      .collection('ai_chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .get();

  return snapshot.docs
      .map((doc) => doc.data())
      .toList();
}
}