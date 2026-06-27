import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'video_circle_recorder.dart';

class ChatScreen extends StatefulWidget {
  final AppUser receiver;
  const ChatScreen({super.key, required this.receiver});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _service = FirebaseService();
  final _picker = ImagePicker();
  
  ChatMessage? _replyingTo;
  late Stream<List<ChatMessage>> _messageStream;
  late String _chatId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _chatId = _service.getChatId(_service.currentUserUid, widget.receiver.uid);
    _messageStream = _service.getMessages(widget.receiver.uid);
    _service.markMessagesAsRead(widget.receiver.uid);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _sendText() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    _messageCtrl.clear(); // 3. Очищаем мгновенно
    
    final replyData = _replyingTo != null ? {
      'text': _replyingTo!.text, 
      'senderId': _replyingTo!.senderId,
      'senderName': _replyingTo!.senderName
    } : null;
    
    setState(() => _replyingTo = null);

    try {
      await _service.sendMessage(widget.receiver.uid, text, replyTo: replyData);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void _uploadAndSendMedia(File file, String type) async {
    setState(() => _isUploading = true);
    final url = await _service.uploadMedia(file, type);
    if (url != null) {
      await _service.sendMessage(widget.receiver.uid, '', type: type, mediaUrl: url);
    }
    if (mounted) setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
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
                Text(user.status == 'online' ? 'в сети' : 'не в сети', 
                  style: TextStyle(fontSize: 12, color: user.status == 'online' ? Colors.greenAccent : Colors.white70)),
              ],
            );
          },
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(color: Colors.orange),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data ?? [];
                
                if (messages.isNotEmpty && messages.first.senderId == widget.receiver.uid && !messages.first.isRead) {
                  _service.markMessagesAsRead(widget.receiver.uid);
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessageItem(messages[index]),
                );
              },
            ),
          ),
          _buildInputPanel(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final bool isMe = msg.senderId == _service.currentUserUid;
    final String decryptedText = _service.decryptMessage(msg.text, _chatId); // 6. Расшифровка
    final String time = DateFormat('HH:mm').format(msg.createdAt.toDate());

    return Dismissible(
      key: Key(msg.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        setState(() => _replyingTo = msg);
        return false; // 5. Ответ по свайпу
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.reply, color: Colors.blueGrey),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.circular(12).copyWith(
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
              bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(12),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.replyTo != null) _buildReplyBadge(msg.replyTo!),
              _buildMediaContent(msg),
              // 6. SelectableText для копирования
              if (decryptedText.isNotEmpty)
                SelectableText(
                  decryptedText,
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                ),
              const SizedBox(height: 4),
              // 4. Время и статус прочтения
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: msg.isRead ? Colors.blue : Colors.grey,
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(ChatMessage msg) {
    if (msg.type == 'image') return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(msg.mediaUrl!));
    if (msg.type == 'circle') return Container(width: 150, height: 150, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black12), child: const Icon(Icons.play_circle_fill, size: 50, color: Colors.white));
    if (msg.type == 'voice') return const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.mic, size: 16), Text(' Голосовое сообщение', style: TextStyle(fontSize: 13))]);
    return const SizedBox.shrink();
  }

  Widget _buildReplyBadge(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: Colors.blueGrey, width: 3)),
      ),
      child: Text(
        _service.decryptMessage(reply['text'], _chatId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_service.decryptMessage(_replyingTo!.text, _chatId), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54))),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyingTo = null)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey), onPressed: _showMediaMenu),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFFF5F6F7), borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageCtrl,
                        // 7. Enter - новая строка
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 5,
                        minLines: 1,
                        // 1. Всегда черный текст
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(hintText: 'Сообщение...', border: InputBorder.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.send_rounded, color: Colors.blueGrey), onPressed: _sendText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaMenu() {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.image), title: const Text('Фото'), onTap: () { Navigator.pop(context); _pickImage(); }),
      ListTile(leading: const Icon(Icons.videocam), title: const Text('Видео-кружок'), onTap: () { Navigator.pop(context); _openCircleRecorder(); }),
      ListTile(leading: const Icon(Icons.file_present), title: const Text('Файл'), onTap: () { Navigator.pop(context); _pickFile(); }),
    ])));
  }

  void _pickImage() async { final XFile? img = await _picker.pickImage(source: ImageSource.gallery); if (img != null) _uploadAndSendMedia(File(img.path), 'image'); }
  void _pickFile() async { final res = await FilePicker.pickFiles(); if (res != null) _uploadAndSendMedia(File(res.files.single.path!), 'file'); }
  void _openCircleRecorder() async { final File? videoFile = await Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoCircleRecorder())); if (videoFile != null) _uploadAndSendMedia(videoFile, 'circle'); }
}
