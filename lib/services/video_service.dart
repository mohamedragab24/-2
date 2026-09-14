import 'package:cloud_functions/cloud_functions.dart';

class SignedVideoResult {
  final String url;
  final DateTime expiresAt;
  SignedVideoResult({required this.url, required this.expiresAt});
}

/// The app NEVER stores or reads a raw video URL. Every time the player
/// needs to start (or resume, or move to the next lesson) it calls this
/// Cloud Function, which — server-side — checks:
///   1) the caller is authenticated,
///   2) the caller purchased the course the lesson belongs to,
/// and only then mints a short-lived signed URL to the file in Cloud
/// Storage (see functions/index.js for the actual implementation).
class VideoService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<SignedVideoResult> getSignedVideoUrl({
    required String courseId,
    required String lessonId,
  }) async {
    final callable = _functions.httpsCallable('getSignedVideoUrl');
    final result = await callable.call<Map<String, dynamic>>({
      'courseId': courseId,
      'lessonId': lessonId,
    });
    final data = result.data;
    return SignedVideoResult(
      url: data['url'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAtMs'] as int),
    );
  }
}
