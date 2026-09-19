import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<String>? _tokenSub;

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _saveToken(user.uid);
    _tokenSub = _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || token.isEmpty) return;
      await _db.collection('users').doc(uid).collection('fcmTokens').doc(token).set({
        'token': token,
        'platform': 'flutter',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _saveToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _db.collection('users').doc(uid).collection('fcmTokens').doc(token).set({
      'token': token,
      'platform': 'flutter',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> dispose() async => _tokenSub?.cancel();
}
