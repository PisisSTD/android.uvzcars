import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';

class ChatScreen extends StatefulWidget {
  final AppUser receiver;
  const ChatScreen({super.key, required this.receiver});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _service = FirebaseService();
  bool _isSending = false;

  void _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _service.sendMessage(widget.receiver.uid, text);
      _messageCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String chatId = _service.getChatId(_service.currentUserUid, widget.receiver.uid);

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<AppUser>(
          stream: _service.getUserStream(widget.receiver.uid),
          initialData: widget.receiver,
          builder: (context, snapshot) {
            final user = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user.status == 'online' ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.status,
                      style: TextStyle(
                        fontSize: 11,
                        color: user.status == 'online' ? Colors.greenAccent : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _service.getMessages(widget.receiver.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SelectableText(
                        'Ошибка чата: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Сообщений пока нет. Напишите первым!'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg.senderId == _service.currentUserUid;
                    final String decryptedText = _service.decryptMessage(msg.text, chatId);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueGrey[700] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(18).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          decryptedText,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // SafeArea защищает от перекрытия панелью навигации (стрелочками и т.д.)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Сообщение...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _isSending 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.blueGrey),
                        onPressed: _send,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
