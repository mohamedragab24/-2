import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  Future<void> init() async {
    await _messaging.setAutoInitEnabled(true);
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _saveToken(user.uid);
    await _messageSub?.cancel();
    _messageSub = FirebaseMessaging.onMessage.listen((message) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final n = message.notification;
      await _db.collection('users').doc(uid).collection('notifications').doc(message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString()).set({
        'title': n?.title ?? message.data['title'] ?? '',
        'body': n?.body ?? message.data['body'] ?? '',
        'imageUrl': n?.android?.imageUrl ?? message.data['imageUrl'] ?? '',
        'type': message.data['type'] ?? 'push',
        'data': message.data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    _tokenSub = _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || token.isEmpty) return;
      await _saveToken(uid, token);
    });
  }

  Future<void> _saveToken(String uid, [String? suppliedToken]) async {
    final token = suppliedToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _db.collection('users').doc(uid).collection('fcmTokens').doc(token).set({
      'token': token, 'platform': 'flutter', 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _db.collection('devices').doc(token).set({
      'uid': uid, 'token': token, 'platform': 'flutter', 'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
  }
}
