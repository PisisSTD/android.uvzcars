import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';

class CreateRequestScreen extends StatefulWidget {
  final AppUser currentUser;
  CreateRequestScreen({required this.currentUser});

  @override
  _CreateRequestScreenState createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirebaseService();

  String _transportType = 'Легковой автомобиль';
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  final List<String> _transportTypes = ["Электрокар", "Грузовой автомобиль", "Автобус", "Легковой автомобиль"];

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Запрос пароля для подписи
    String? password = await _showSignatureDialog();
    if (password == null || password.isEmpty) return;

    bool isVerified = await _service.verifySignature(password);
    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Неверный пароль подписи!')));
      return;
    }

    final req = TransportRequest(
      id: '',
      userId: widget.currentUser.uid,
      userEmail: widget.currentUser.email,
      department: widget.currentUser.department,
      transportType: _transportType,
      date: _dateCtrl.text,
      timeStart: _timeCtrl.text,
      duration: _durationCtrl.text,
      purpose: _purposeCtrl.text,
      route: _routeCtrl.text,
      comment: _commentCtrl.text,
      status: 'отправлено',
    );

    await _service.createRequest(req);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Заявка подписана и отправлена')));
    Navigator.pop(context);
  }

  Future<String?> _showSignatureDialog() {
    TextEditingController _passCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Электронная подпись'),
        content: TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Введите пароль от аккаунта'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, _passCtrl.text), child: Text('Подписать')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Новая заявка')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _transportType,
              items: _transportTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _transportType = val!),
              decoration: InputDecoration(labelText: 'Тип транспорта'),
            ),
            TextFormField(controller: _dateCtrl, decoration: InputDecoration(labelText: 'Дата (ДД.ММ.ГГГГ)'), validator: (v) => v!.isEmpty ? 'Заполните поле' : null),
            TextFormField(controller: _timeCtrl, decoration: InputDecoration(labelText: 'Время начала (ЧЧ:ММ)'), validator: (v) => v!.isEmpty ? 'Заполните поле' : null),
            TextFormField(controller: _durationCtrl, decoration: InputDecoration(labelText: 'Длительность (в часах)'), validator: (v) => v!.isEmpty ? 'Заполните поле' : null),
            TextFormField(controller: _purposeCtrl, decoration: InputDecoration(labelText: 'Цель поездки'), validator: (v) => v!.isEmpty ? 'Заполните поле' : null),
            TextFormField(controller: _routeCtrl, decoration: InputDecoration(labelText: 'Маршрут'), validator: (v) => v!.isEmpty ? 'Заполните поле' : null),
            TextFormField(controller: _commentCtrl, decoration: InputDecoration(labelText: 'Комментарий (необязательно)')),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitRequest,
              child: Padding(padding: EdgeInsets.all(12.0), child: Text('Подписать и Отправить')),
            )
          ],
        ),
      ),
    );
  }
}