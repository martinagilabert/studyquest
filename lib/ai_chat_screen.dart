import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_service.dart';
import 'services/chat_firestore_service.dart';
import 'ai_chat_list_screen.dart';

class AiChatScreen extends StatefulWidget {
  final String? chatId;
  final int initialMessageCount;

  const AiChatScreen({
    super.key,
    this.chatId,
    this.initialMessageCount = 0,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatFirestoreService _chatService = ChatFirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _chatId;
  int _messageCount = 0;

  String respuesta = '';
  bool cargando = false;
  bool hizoPregunta = false;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _messageCount = widget.initialMessageCount;
  }

  Future<void> preguntar() async {
    final texto = _controller.text.trim();

    if (texto.isEmpty || cargando) return;

    _controller.clear();

    if (_currentUser == null) {
      setState(() {
        respuesta = 'No hay un usuario autenticado.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      cargando = true;
      respuesta = '';
    });

    try {
      if (_chatId == null) {
        _chatId = await _chatService.createChat(_currentUser!.uid);

        await _chatService.updateChatTitle(
          uid: _currentUser!.uid,
          chatId: _chatId!,
          title: texto.length > 40 ? '${texto.substring(0, 40)}...' : texto,
        );
      }

      await _chatService.addMessage(
        uid: _currentUser!.uid,
        chatId: _chatId!,
        role: 'user',
        content: texto,
      );

      _messageCount++;

      await _chatService.updateChatInfo(
        uid: _currentUser!.uid,
        chatId: _chatId!,
        lastMessage: texto,
        messageCount: _messageCount,
      );

      final result = await AiService.askProfessor(texto);

      await _chatService.addMessage(
        uid: _currentUser!.uid,
        chatId: _chatId!,
        role: 'assistant',
        content: result,
      );

      _messageCount++;

      await _chatService.updateChatInfo(
        uid: _currentUser!.uid,
        chatId: _chatId!,
        lastMessage:
            result.length > 120 ? '${result.substring(0, 120)}...' : result,
        messageCount: _messageCount,
      );

      setState(() {
        respuesta = result;
        hizoPregunta = true;
      });
    } catch (e) {
      setState(() {
        respuesta =
            'Ha ocurrido un error al consultar el profesor virtual.\n\nDetalle: $e';
      });
    } finally {
      setState(() {
        cargando = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble({
    required String role,
    required String content,
  }) {
    final bool isUser = role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? Colors.purple : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isUser
            ? Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              )
            : MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                  h1: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Pensando...',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseContent() {
    if (_currentUser == null) {
      return const Center(
        child: Text('No hay un usuario autenticado.'),
      );
    }

    if (_chatId == null) {
      if (cargando) {
        return Column(
          key: const ValueKey('loading'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 18),
            Text(
              'El profesor virtual está pensando...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Esto puede tardar unos segundos.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }

      return Column(
        key: const ValueKey('empty'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 52, color: Colors.purple.shade300),
          const SizedBox(height: 12),
          Text(
            'La respuesta aparecerá aquí.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escribe una pregunta y pulsa "Preguntar".',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(
        uid: _currentUser!.uid,
        chatId: _chatId!,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar mensajes: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty && !cargando) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 52,
                color: Colors.purple.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Este chat todavía no tiene mensajes.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          key: const ValueKey('messages'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: docs.length + (cargando ? 1 : 0),
          itemBuilder: (context, index) {
            if (cargando && index == docs.length) {
              return _buildThinkingBubble();
            }

            final data = docs[index].data() as Map<String, dynamic>;
            final role = data['role'] ?? '';
            final content = data['content'] ?? '';

            return _buildMessageBubble(
              role: role,
              content: content,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hayTexto = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profesor Virtual'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, hizoPregunta);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver chats guardados',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiChatListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cargando ? Colors.purple.shade100 : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.school, color: Colors.purple.shade400),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Haz una pregunta de estudio y te responderé como un profesor particular.',
                      style: TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 2,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => preguntar(),
              decoration: InputDecoration(
                hintText: 'Ejemplo: Explícame la fotosíntesis fácil',
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
                      BorderSide(color: Colors.purple.shade300, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!hayTexto || cargando) ? null : preguntar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: cargando
                      ? const SizedBox(
                          key: ValueKey('spinner'),
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          key: ValueKey('send'),
                        ),
                ),
                label: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    cargando ? 'Consultando...' : 'Preguntar',
                    key: ValueKey(cargando),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cargando ? Colors.purple.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildResponseContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}