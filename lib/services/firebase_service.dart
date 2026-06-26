import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/app_models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _projectId = 'cars-9aa2a'; 

  String get currentUserUid => _auth.currentUser?.uid ?? '';

  // --- СТАТУС ПОЛЬЗОВАТЕЛЯ ---

  Future<void> updateUserStatus(String status) async {
    if (_auth.currentUser != null) {
      await _db.collection('users').doc(_auth.currentUser!.uid).update({
        'status': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- РЕГИСТРАЦИЯ И АВТОРИЗАЦИЯ ---

  Future<UserCredential?> signUp(String email, String password, String fullName, String department, String role) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (res.user != null) {
        await _db.collection('users').doc(res.user!.uid).set({
          'email': email,
          'fullName': fullName,
          'department': department,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'online',
        });
      }
      return res;
    } catch (e) { rethrow; }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    UserCredential res = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await updateUserStatus('online');
    return res;
  }

  Future<void> signOut() async {
    await updateUserStatus('offline');
    await _auth.signOut();
  }

  // --- МЕССЕНДЖЕР И ШИФРОВАНИЕ ---

  String getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  String encryptMessage(String plainText, String chatId) {
    final key = encrypt.Key.fromUtf8(chatId.padRight(32).substring(0, 32));
    final iv = encrypt.IV.fromUtf8(chatId.substring(0, 16)); 
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  String decryptMessage(String encryptedBase64, String chatId) {
    try {
      final key = encrypt.Key.fromUtf8(chatId.padRight(32).substring(0, 32));
      final iv = encrypt.IV.fromUtf8(chatId.substring(0, 16)); 
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt64(encryptedBase64, iv: iv);
    } catch (e) { return "[Ошибка расшифровки]"; }
  }

  Future<void> sendMessage(String receiverId, String text) async {
    final String senderId = currentUserUid;
    final String chatId = getChatId(senderId, receiverId);
    final String encryptedText = encryptMessage(text, chatId);

    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': senderId,
      'text': encryptedText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('chats').doc(chatId).set({
      'lastMessage': encryptedText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [senderId, receiverId],
    }, SetOptions(merge: true));

    // ОТПРАВКА УВЕДОМЛЕНИЯ О СООБЩЕНИИ
    final senderDoc = await _db.collection('users').doc(senderId).get();
    final receiverDoc = await _db.collection('users').doc(receiverId).get();

    if (senderDoc.exists && receiverDoc.exists) {
      final senderName = senderDoc.get('fullName') ?? 'Сотрудник';
      final receiverToken = receiverDoc.data()?['fcmToken'];

      if (receiverToken != null) {
        await _sendPushV1(
          receiverToken,
          senderName,
          'Отправил(а) вам сообщение',
        );
      }
    }
  }

  Stream<List<ChatMessage>> getMessages(String receiverId) {
    final String chatId = getChatId(currentUserUid, receiverId);
    return _db.collection('chats').doc(chatId).collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((sn) => sn.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  Stream<AppUser> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => AppUser.fromFirestore(doc));
  }

  Stream<List<AppUser>> getAllUsers() {
    return _db.collection('users').snapshots().map((sn) => 
      sn.docs.where((doc) => doc.id != _auth.currentUser?.uid)
      .map((doc) => AppUser.fromFirestore(doc)).toList()
    );
  }

  // --- ЗАЯВКИ И ПУШИ ---

  Future<AppUser?> getCurrentAppUser() async {
    if (_auth.currentUser == null) return null;
    DocumentSnapshot doc = await _db.collection('users').doc(_auth.currentUser!.uid).get();
    return doc.exists ? AppUser.fromFirestore(doc) : null;
  }

  Future<void> updateRequestStatus(TransportRequest request, String newStatus) async {
    await _db.collection('requests').doc(request.id).update({'status': newStatus});
    final userDoc = await _db.collection('users').doc(request.userId).get();
    final token = userDoc.data()?['fcmToken'];
    if (token != null) {
      await _sendPushV1(token, 'Статус изменен', 'Заявка (${request.transportType}): $newStatus');
    }
  }

  Future<void> createRequest(TransportRequest request) async {
    await _db.collection('requests').add(request.toMap());
  }

  Stream<List<TransportRequest>> getUserRequests() {
    if (_auth.currentUser == null) return Stream.value([]);
    return _db.collection('requests').where('userId', isEqualTo: _auth.currentUser!.uid)
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
      await _db.collection('users').doc(_auth.currentUser!.uid).set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  Future<String> _getAccessToken() async {
    final serviceAccountJson = await rootBundle.loadString('assets/service-account.json');
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
    return client.credentials.accessToken.data;
  }

  Future<void> _sendPushV1(String token, String title, String body) async {
    try {
      final String accessToken = await _getAccessToken();
      final String fcmUrl = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      await http.post(Uri.parse(fcmUrl),
        headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
        body: jsonEncode({'message': {'token': token, 'notification': {'title': title, 'body': body}}}),
      );
    } catch (e) { if (kDebugMode) print('Push error: $e'); }
  }

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
}
