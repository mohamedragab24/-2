import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'r2_worker_service.dart';

class SignedVideoResult {
  final String url;
  final DateTime expiresAt;
  SignedVideoResult({required this.url, required this.expiresAt});
}

class VideoService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<SignedVideoResult> getSignedVideoUrl({required String courseId, required String lessonId}) async {
    final lesson = await _db.collection('courses').doc(courseId).collection('lessons').doc(lessonId).get();
    final data = lesson.data();
    final candidates = <String>[
      (data?['videoUrl'] ?? '').toString(),
      (data?['storagePath'] ?? '').toString(),
      (data?['r2Key'] ?? '').toString(),
    ];
    for (final candidate in candidates) {
      final direct = R2WorkerService.tokenToUrl(candidate);
      if (direct != null) return SignedVideoResult(url: direct, expiresAt: DateTime.now().add(const Duration(hours: 1)));
      if (candidate.startsWith('courses/') || candidate.startsWith('meetings/')) {
        return SignedVideoResult(url: R2WorkerService.keyToUrl(candidate), expiresAt: DateTime.now().add(const Duration(hours: 1)));
      }
    }
    final callable = _functions.httpsCallable('getSignedVideoUrl');
    final result = await callable.call<Map<String, dynamic>>({'courseId': courseId, 'lessonId': lessonId});
    final resultData = result.data;
    return SignedVideoResult(url: resultData['url'] as String, expiresAt: DateTime.fromMillisecondsSinceEpoch(resultData['expiresAtMs'] as int));
  }
}
