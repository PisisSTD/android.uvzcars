import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'login_screen.dart';
import 'request_detail_screen.dart';
import 'profile_screen.dart';

class DispatcherRequestsScreen extends StatefulWidget {
  final AppUser currentUser;

  DispatcherRequestsScreen({required this.currentUser});

  @override
  _DispatcherRequestsScreenState createState() => _DispatcherRequestsScreenState();
}

class _DispatcherRequestsScreenState extends State<DispatcherRequestsScreen> {
  final FirebaseService _service = FirebaseService();
  String _statusFilter = 'Все';

  final List<String> _filterOptions = [
    'Все', 'отправлено', 'принято', 'транспорт выделен', 'отклонено', 'выполнено'
  ];

  // Вызов диалога для смены статуса
  void _changeStatus(TransportRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить статус'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _filterOptions.where((s) => s != 'Все').map((status) {
            return ListTile(
              title: Text(status),
              onTap: () async {
                Navigator.pop(context);
                await _service.updateRequestStatus(request.id, status);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Статус изменен на "$status"'))
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель диспетчера'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(currentUser: widget.currentUser),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await _service.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Фильтр по статусам
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Фильтр по статусу',
                border: OutlineInputBorder(),
              ),
              items: _filterOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
            ),
          ),

          // Список заявок
          Expanded(
            child: StreamBuilder<List<TransportRequest>>(
              stream: _service.getAllRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Нет заявок'));
                }

                // Применяем фильтр
                var filteredRequests = snapshot.data!;
                if (_statusFilter != 'Все') {
                  filteredRequests = filteredRequests.where((r) => r.status == _statusFilter).toList();
                }

                if (filteredRequests.isEmpty) {
                  return const Center(child: Text('По этому фильтру ничего не найдено'));
                }

                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final req = filteredRequests[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text('${req.transportType} - ${req.date}'),
                        subtitle: Text('От: ${req.userEmail}\nСтатус: ${req.status}'),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          onPressed: () => _changeStatus(req),
                          child: const Text('Статус'),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestDetailScreen(request: req),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
