import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'chat_screen.dart';

class UsersListScreen extends StatelessWidget {
  final FirebaseService _service = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заводская сеть (УВЗ)'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _service.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Сотрудники не найдены'));
          }

          final users = snapshot.data!;
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey[100],
                  child: Text(user.fullName[0].toUpperCase()),
                ),
                title: Text(user.fullName),
                subtitle: Text('${user.department} | ${user.role}'),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.status == 'online' ? Colors.green : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(receiver: user),
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
