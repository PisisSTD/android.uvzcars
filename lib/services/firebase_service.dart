import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../models/app_models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Идентификатор твоего проекта из настроек Firebase
  final String _projectId = 'cars-9aa2a'; 

  // Метод для получения токена доступа из JSON-файла сервисного аккаунта
  Future<String> _getAccessToken() async {
    // Файл должен лежать в корневой папке assets/
    final serviceAccountJson = await rootBundle.loadString('assets/service-account.json');
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    
    final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
    return client.credentials.accessToken.data;
  }

  // Смена статуса диспетчером + отправка уведомления (V1)
  Future<void> updateRequestStatus(TransportRequest request, String newStatus) async {
    // 1. Обновляем статус в Firestore
    await _db.collection('requests').doc(request.id).update({'status': newStatus});

    // 2. Получаем токен пользователя
    DocumentSnapshot userDoc = await _db.collection('users').doc(request.userId).get();
    
    if (userDoc.exists && userDoc.data() != null) {
      String? userToken = (userDoc.data() as Map<String, dynamic>)['fcmToken'];
      
      if (userToken != null) {
        // 3. Отправляем пуш через новый API
        await _sendPushV1(
          userToken,
          'Статус заявки изменен',
          'Ваша заявка (${request.transportType}) теперь имеет статус: $newStatus',
        );
      }
    }
  }

  // Внутренний метод отправки V1
  Future<void> _sendPushV1(String token, String title, String body) async {
    try {
      final String accessToken = await _getAccessToken();
      final String fcmUrl = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
            'data': {'status': 'updated'}
          }
        }),
      );

      if (kDebugMode) {
        if (response.statusCode == 200) {
          print('Push V1 sent successfully');
        } else {
          print('Error V1: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Exception sending push: $e');
    }
  }

  // Стримы и авторизация
  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async => await _auth.signOut();

  Future<bool> verifySignature(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
        await user.reauthenticateWithCredential(credential);
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<AppUser?> getCurrentAppUser() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  Future<void> createRequest(TransportRequest request) async {
    await _db.collection('requests').add(request.toMap());
  }

  Stream<List<TransportRequest>> getUserRequests() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _db.collection('requests').where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true).snapshots()
        .map((sn) => sn.docs.map((doc) => TransportRequest.fromFirestore(doc)).toList());
  }

  Stream<List<TransportRequest>> getAllRequests() {
    return _db.collection('requests').orderBy('createdAt', descending: true).snapshots()
        .map((sn) => sn.docs.map((doc) => TransportRequest.fromFirestore(doc)).toList());
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    String? token = await messaging.getToken();
    if (token != null) {
      if (kDebugMode) print("FCM TOKEN: $token");
      String uid = _auth.currentUser!.uid;
      await _db.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
    }
  }
}
