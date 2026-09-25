import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course.dart';
import '../models/lesson.dart';
import '../models/user_profile.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ==================== COURSES ====================

  Stream<List<Course>> watchCourses({String? category}) {
    Query<Map<String, dynamic>> query = _db
        .collection('courses')
        .where('status', isEqualTo: 'published');

    if (category != null && category != 'الكل') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
          (snapshot) {
            final courses = snapshot.docs
                .map(
                  (doc) => Course.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .toList();

            // Keep the app catalog deterministic and aligned with the
            // platform's course list.
            courses.sort(
              (a, b) => a.title.toLowerCase().compareTo(
                    b.title.toLowerCase(),
                  ),
            );
            return courses;
          },
        );
  }

  Future<List<Course>> getPublishedCoursesOnce({String? category}) async {
    Query<Map<String, dynamic>> query = _db.collection('courses').where('status', isEqualTo: 'published');
    if (category != null && category != 'الكل') {
      query = query.where('category', isEqualTo: category);
    }
    final snapshot = await query.get();
    final courses = snapshot.docs.map((doc) => Course.fromMap(doc.id, doc.data())).toList();
    courses.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return courses;
  }

  Future<Course?> getCourse(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Course.fromMap(
      doc.id,
      doc.data()!,
    );
  }

  Future<List<Course>> getCoursesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }

    final courses = <Course>[];

    for (final id in ids) {
      if (id.trim().isEmpty) {
        continue;
      }

      final doc = await _db.collection('courses').doc(id).get();

      if (doc.exists && doc.data() != null) {
        courses.add(
          Course.fromMap(
            doc.id,
            doc.data()!,
          ),
        );
      }
    }

    return courses;
  }

  Stream<List<Lesson>> watchLessons(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('lessons')
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Lesson.fromMap(
                  doc.id,
                  courseId,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  // ==================== USERS ====================

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserProfile.fromMap(
      doc.id,
      doc.data()!,
    );
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data() != null
              ? UserProfile.fromMap(
                  doc.id,
                  doc.data()!,
                )
              : null,
        );
  }

  Future<void> ensureUserProfile({
    required String uid,
    String? name,
    String? email,
    String? phone,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final existing = await ref.get();

    await ref.set(
      {
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (!existing.exists) ...{
          'joinedAt': FieldValue.serverTimestamp(),
          'mode': 'mostafhem',
        },
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? photoUrl,
    String? mode,
  }) async {
    final data = <String, dynamic>{
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (mode != null && (mode == 'mofahhem' || mode == 'mostafhem')) 'mode': mode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<String> createPendingCourse({
    required String uid,
    required String instructorName,
    required String title,
    required String description,
    required String category,
    required double price,
    String thumbnailUrl = '',
  }) async {
    final ref = await _db.collection('courses').add({
      'title': title.trim(),
      'description': description.trim(),
      'instructorName': instructorName.trim(),
      'instructorUid': uid,
      'ownerUid': uid,
      'createdBy': uid,
      'category': category,
      'price': price,
      'rating': 0,
      'studentsCount': 0,
      'lessonsCount': 0,
      'durationLabel': '',
      'features': <String>[],
      'thumbnailUrl': thumbnailUrl.trim(),
      'status': 'pending',
      'isPublished': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyCourses(String uid) {
    return _db.collection('courses').where('ownerUid', isEqualTo: uid).snapshots();
  }

  // ==================== PURCHASES ====================

  Future<bool> hasPurchased(
    String uid,
    String courseId,
  ) async {
    final doc = await _db
        .collection('purchases')
        .doc('${uid}_$courseId')
        .get();

    if (!doc.exists || doc.data() == null) {
      return false;
    }

    return doc.data()!['status'] == 'completed';
  }

  Stream<List<String>> watchMyCourseIds(String uid) {
    return _db
        .collection('purchases')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => (doc.data()['courseId'] ?? '').toString(),
              )
              .where(
                (courseId) => courseId.isNotEmpty,
              )
              .toList(),
        );
  }

  // ==================== FAVORITES ====================

  Stream<List<String>> watchFavoriteIds(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.id)
              .toList(),
        );
  }

  Future<void> setFavorite(
    String uid,
    String courseId,
    bool isFavorite,
  ) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(courseId);

    if (isFavorite) {
      await ref.set({
        'courseId': courseId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  // ==================== NOTIFICATIONS ====================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchNotifications(
    String uid,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  Future<void> markNotificationRead(
    String uid,
    String notificationId,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
    });
  }

  // ==================== PROGRESS ====================

  String _progressId(
    String uid,
    String courseId,
    String lessonId,
  ) {
    return '${uid}_${courseId}_$lessonId';
  }

  Future<int> getLessonProgressSeconds(
    String uid,
    String courseId,
    String lessonId,
  ) async {
    final doc = await _db
        .collection('progress')
        .doc(
          _progressId(
            uid,
            courseId,
            lessonId,
          ),
        )
        .get();

    if (!doc.exists || doc.data() == null) {
      return 0;
    }

    final value = doc.data()!['positionSeconds'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  Future<void> saveLessonProgress({
    required String uid,
    required String courseId,
    required String lessonId,
    required int positionSeconds,
    required int durationSeconds,
    required bool completed,
  }) async {
    final percent = durationSeconds <= 0
        ? 0
        : ((positionSeconds / durationSeconds) * 100)
            .clamp(0, 100)
            .round();

    await _db
        .collection('progress')
        .doc(
          _progressId(
            uid,
            courseId,
            lessonId,
          ),
        )
        .set(
      {
        'uid': uid,
        'courseId': courseId,
        'lessonId': lessonId,
        'positionSeconds': positionSeconds,
        'percent': percent,
        'completed': completed,
        'lastWatchedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
