import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingCourses() {
    return _db
        .collection('courses')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Future<void> reviewCourse({
    required String courseId,
    required String decision,
    String? rejectionReason,
  }) async {
    final callable = _functions.httpsCallable('reviewCourse');
    await callable.call({
      'courseId': courseId,
      'decision': decision,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReviewHistory(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('reviews')
        .orderBy('reviewedAt', descending: true)
        .snapshots();
  }
}
