import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'create_request_screen.dart';
import 'login_screen.dart';
import 'request_detail_screen.dart';
import 'profile_screen.dart';
import 'users_list_screen.dart';
import 'groups_list_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  final AppUser currentUser;
  const MyRequestsScreen({super.key, required this.currentUser});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final FirebaseService _service = FirebaseService();
  int _selectedIndex = 0;

  // Список заголовков для вкладок
  final List<String> _titles = ['Мои заявки', 'Сотрудники', 'Группы'];

  // Метод для выхода
  Future<void> _confirmSignOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.signOut();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(currentUser: widget.currentUser))),
          ),
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _confirmSignOut),
        ],
      ),
      // Переключаем контент в зависимости от выбранной вкладки
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRequestsList(),
          UsersListScreen(), // Вкладка сотрудников
          GroupsListScreen(), // Вкладка групп
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blueGrey[900],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Заявки'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Люди'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'Группы'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRequestScreen(currentUser: widget.currentUser))),
            label: const Text('Новая заявка'),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
          )
        : null,
    );
  }

  // Вынесли список заявок в отдельный метод для чистоты кода
  Widget _buildRequestsList() {
    return StreamBuilder<List<TransportRequest>>(
      stream: _service.getUserRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const Center(child: Text('У вас пока нет заявок'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(req.transportType, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Дата: ${req.date}\nСтатус: ${req.status}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestDetailScreen(request: req))),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text('ОШИБКА ИНДЕКСА', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SelectableText(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}
