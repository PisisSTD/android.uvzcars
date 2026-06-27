import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'chat_screen.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService service = FirebaseService();

    return StreamBuilder<List<AppUser>>(
      stream: service.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) return const Center(child: Text('Сотрудники не найдены'));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueGrey[100],
                    child: Text(user.fullName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: user.status == 'online' ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${user.department} | ${user.role}'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(receiver: user))),
            );
          },
        );
      },
    );
  }
}
