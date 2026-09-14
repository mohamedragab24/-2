class Lesson {
  final String id;
  final String courseId;
  final String title;
  final int order;
  final int durationSeconds;
  final bool isPreview; // true = playable without purchase (e.g. lesson 1 intro)
  /// Path inside Cloud Storage, e.g. "courses/c1/lessons/l3.mp4".
  /// This is NEVER a public URL — the app never reads this field directly
  /// for playback; it only sends the lessonId to the getSignedVideoUrl
  /// Cloud Function, which resolves this path server-side after checking
  /// purchase + auth, and returns a short-lived signed URL.
  final String storagePath;

  Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.order,
    required this.durationSeconds,
    required this.isPreview,
    required this.storagePath,
  });

  factory Lesson.fromMap(String id, String courseId, Map<String, dynamic> map) {
    return Lesson(
      id: id,
      courseId: courseId,
      title: map['title'] ?? '',
      order: (map['order'] ?? 0) as int,
      durationSeconds: (map['durationSeconds'] ?? 0) as int,
      isPreview: map['isPreview'] ?? false,
      storagePath: map['storagePath'] ?? '',
    );
  }

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
