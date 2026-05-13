import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Авторизация
  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async => await _auth.signOut();

  // Электронная подпись (повторная авторизация)
  Future<bool> verifySignature(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
        await user.reauthenticateWithCredential(credential);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Получение пользователя
  Future<AppUser?> getCurrentAppUser() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }
    return null;
  }

  // Создание заявки
  Future<void> createRequest(TransportRequest request) async {
    await _db.collection('requests').add(request.toMap());
  }

  // Стримы для списков
  Stream<List<TransportRequest>> getUserRequests() {
    String uid = _auth.currentUser!.uid;
    return _db.collection('requests').where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TransportRequest.fromFirestore(doc)).toList());
  }

  Stream<List<TransportRequest>> getAllRequests() {
    return _db.collection('requests').orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TransportRequest.fromFirestore(doc)).toList());
  }

  // Смена статуса диспетчером
  Future<void> updateRequestStatus(String requestId, String newStatus) async {
    await _db.collection('requests').doc(requestId).update({'status': newStatus});
  }

  // Новый метод для настройки уведомлений
  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Запрашиваем права у пользователя (появится системное окошко)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Пользователь разрешил уведомления');

      // 2. Получаем уникальный токен этого устройства
      String? token = await messaging.getToken();

      if (token != null) {
        // 3. Сохраняем токен в документ текущего пользователя в коллекции 'users'
        String uid = _auth.currentUser!.uid;
        await _db.collection('users').doc(uid).set(
          {'fcmToken': token},
          SetOptions(merge: true) // merge: true обновляет документ, не удаляя старые поля
        );
      }
    }
  }
}
