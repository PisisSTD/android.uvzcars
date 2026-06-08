import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Инициализируем Firebase. Если файл google-services.json на месте, 
    // пустые аргументы инициализируют платформу по умолчанию.
    await Firebase.initializeApp();
    runApp(MyApp());
  } catch (e) {
    // Если Firebase упадет, мы увидим это на экране телефона
    debugPrint("Firebase Error: $e");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Ошибка инициализации: $e",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Диспетчер ТС', // Измененное название
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(),
    );
  }
}
