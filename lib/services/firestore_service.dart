import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/lesson.dart';
import '../models/user_profile.dart';

/// All reads/writes go through this service so the Firestore collection
/// names stay in one place. Collections match the project's data model:
/// Users, Courses, Lessons, Purchases, Progress, Payments, Sessions, Notifications.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Courses ----------

  Stream<List<Course>> watchCourses({String? category}) {
    Query<Map<String, dynamic>> q = _db.collection('courses').where('isPublished', isEqualTo: true);
    if (category != null && category != 'الكل') {
      q = q.where('category', isEqualTo: category);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map((d) => Course.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Course?> getCourse(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return Course.fromMap(doc.id, doc.data()!);
  }

  Stream<List<Lesson>> watchLessons(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('lessons')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Lesson.fromMap(d.id, courseId, d.data())).toList());
  }

  // ---------- Users ----------

  /// Reads the customer's profile document — this is the same `users`
  /// collection the website writes to, so any customer who registered
  /// through the website already has a doc here the app can read.
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.id, doc.data()!);
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (doc) => doc.exists ? UserProfile.fromMap(doc.id, doc.data()!) : null,
        );
  }

  /// Called right after a successful sign-in (not just sign-up), because a
  /// customer might already exist as a Firebase Auth user from the website
  /// without a `users/{uid}` doc yet, or might be signing into the app for
  /// the first time. `merge: true` means it never overwrites fields the
  /// website already filled in (e.g. phone) with blanks from the app.
  Future<void> ensureUserProfile({
    required String uid,
    String? name,
    String? email,
    String? phone,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final existing = await ref.get();
    await ref.set({
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (!existing.exists) 'joinedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Purchases ----------

  /// A purchase document id is conventionally `${uid}_${courseId}` so this
  /// is a single doc read (cheap + rules-friendly) instead of a query.
  Future<bool> hasPurchased(String uid, String courseId) async {
    final doc = await _db.collection('purchases').doc('${uid}_$courseId').get();
    return doc.exists && (doc.data()?['status'] == 'completed');
  }

  Stream<List<String>> watchMyCourseIds(String uid) {
    return _db
        .collection('purchases')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()['courseId'] as String).toList());
  }

  // ---------- Progress ----------

  String _progressId(String uid, String courseId, String lessonId) => '${uid}_${courseId}_$lessonId';

  Future<int> getLessonProgressSeconds(String uid, String courseId, String lessonId) async {
    final doc = await _db.collection('progress').doc(_progressId(uid, courseId, lessonId)).get();
    return (doc.data()?['positionSeconds'] ?? 0) as int;
  }

  /// Called periodically (e.g. every 10s) from the player and once on pause/exit.
  Future<void> saveLessonProgress({
    required String uid,
    required String courseId,
    required String lessonId,
    required int positionSeconds,
    required int durationSeconds,
    required bool completed,
  }) {
    final pct = durationSeconds == 0 ? 0 : ((positionSeconds / durationSeconds) * 100).clamp(0, 100).round();
    return _db.collection('progress').doc(_progressId(uid, courseId, lessonId)).set({
      'uid': uid,
      'courseId': courseId,
      'lessonId': lessonId,
      'positionSeconds': positionSeconds,
      'percent': pct,
      'completed': completed,
      'lastWatchedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
