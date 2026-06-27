import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsListScreen extends StatelessWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService service = FirebaseService();

    return Scaffold(
      body: StreamBuilder<List<ChatGroup>>(
        stream: service.getMyGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Вы пока не состоите в группах'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                    ),
                    child: const Text('Создать первую группу'),
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.orange[100],
                  child: const Icon(Icons.factory, color: Colors.orange),
                ),
                title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  group.lastMessage != null 
                    ? (group.lastMessage!.startsWith('[') 
                        ? group.lastMessage! 
                        : service.decryptMessage(group.lastMessage!, group.id))
                    : 'Нет сообщений',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => GroupChatScreen(group: group))
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_group_btn',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        child: const Icon(Icons.group_add),
      ),
    );
  }
}
