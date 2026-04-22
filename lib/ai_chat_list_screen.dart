import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/chat_firestore_service.dart';
import 'ai_chat_screen.dart';

class AiChatListScreen extends StatefulWidget {
  const AiChatListScreen({super.key});

  @override
  State<AiChatListScreen> createState() => _AiChatListScreenState();
}

class _AiChatListScreenState extends State<AiChatListScreen> {
  final ChatFirestoreService _chatService = ChatFirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats guardados')),
        body: const Center(
          child: Text('No hay un usuario autenticado.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats guardados'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getChats(_currentUser!.uid),
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

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Text('Todavía no tienes chats guardados.'),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final data = chat.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'Sin título';
              final lastMessage = data['lastMessage'] ?? '';
              final messageCount = data['messageCount'] ?? 0;

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.chat_bubble_outline),
                ),
                title: Text(title),
                subtitle: Text(
                  lastMessage.isEmpty ? 'Sin mensajes' : lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('$messageCount'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatScreen(
                        chatId: chat.id,
                        initialMessageCount: messageCount,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}