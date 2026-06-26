import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'my_requests_screen.dart';
import 'dispatcher_requests_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _service = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Ждем, пока Firebase проверит наличие сохраненной сессии
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Если сессии нет — на экран логина
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // Если сессия есть, загружаем профиль из Firestore
        return FutureBuilder<AppUser?>(
          future: _service.getCurrentAppUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final user = userSnapshot.data;

            if (user == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Ошибка: Профиль не найден"),
                      ElevatedButton(
                        onPressed: () => _service.signOut(),
                        child: const Text("Выйти"),
                      )
                    ],
                  ),
                ),
              );
            }

            // ПРИ КАЖДОМ ВХОДЕ (в т.ч. автоматическом):
            // 1. Ставим статус online
            _service.updateUserStatus('online');
            // 2. Настраиваем пуши (токен обновится в базе)
            _service.setupPushNotifications();

            // Перенаправляем на нужный экран
            if (user.role == 'dispatcher') {
              return DispatcherRequestsScreen(currentUser: user);
            } else {
              return MyRequestsScreen(currentUser: user);
            }
          },
        );
      },
    );
  }
}
