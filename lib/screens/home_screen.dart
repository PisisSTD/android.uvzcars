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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseService _service = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkInitialStatus() {
    if (FirebaseAuth.instance.currentUser != null) {
      _service.updateUserStatus('online');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 2. Исправляем статус online/offline
    if (state == AppLifecycleState.resumed) {
      _service.updateUserStatus('online');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _service.updateUserStatus('offline');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

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
                  child: ElevatedButton(
                    onPressed: () => _service.signOut(),
                    child: const Text("Ошибка профиля. Выйти"),
                  ),
                ),
              );
            }

            _service.updateUserStatus('online');
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
