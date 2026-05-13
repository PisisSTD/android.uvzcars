import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'my_requests_screen.dart';
import 'dispatcher_requests_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  final FirebaseService _service = FirebaseService();

  @override
  Widget build(BuildContext context) {
    // Используем StreamBuilder для отслеживания состояния авторизации в реальном времени
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Если пользователь не авторизован в Firebase Auth
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // Если авторизован, загружаем его профиль из Firestore
        return FutureBuilder<AppUser?>(
          future: _service.getCurrentAppUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text("Ошибка Firestore: ${userSnapshot.error}"),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Выйти"),
                      )
                    ],
                  ),
                ),
              );
            }

            final user = userSnapshot.data;

            // Если профиль в Firestore не найден
            if (user == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_off, color: Colors.orange, size: 60),
                      const SizedBox(height: 16),
                      const Text("Профиль пользователя не найден в базе данных (коллекция 'users')."),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Убедитесь, что в Firestore создан документ с вашим UID.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text("Ваш UID: ${authSnapshot.data!.uid}", style: const TextStyle(fontSize: 10)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Назад к логину"),
                      )
                    ],
                  ),
                ),
              );
            }

            // Если всё хорошо, переходим к экранам по ролям
            _service.setupPushNotifications();

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
