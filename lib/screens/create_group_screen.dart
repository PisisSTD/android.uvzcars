import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _service = FirebaseService();
  final _nameCtrl = TextEditingController();
  final List<String> _selectedUsers = [];
  bool _isCreating = false;

  void _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название и выберите участников')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      await _service.createGroup(_nameCtrl.text.trim(), _selectedUsers);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая группа / Цех'),
        actions: [
          if (_isCreating)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _submit,
              child: const Text('СОЗДАТЬ', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название группы (например, Цех №34)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.factory_outlined),
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Выберите участников:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _service.getAllUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUsers.contains(user.uid);
                    return CheckboxListTile(
                      title: Text(user.fullName),
                      subtitle: Text(user.department),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val!) {
                            _selectedUsers.add(user.uid);
                          } else {
                            _selectedUsers.remove(user.uid);
                          }
                        });
                      },
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
