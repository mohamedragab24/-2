import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../services/firestore_service.dart';
import '../services/video_service.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String courseId;
  final String lessonId;
  const LessonPlayerScreen({super.key, required this.courseId, required this.lessonId});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  final _firestore = FirestoreService();
  final _videoService = VideoService();

  VideoPlayerController? _controller;
  Timer? _progressTimer;
  Timer? _urlRefreshTimer;
  bool _loading = true;
  String? _error;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Screen protection (Android FLAG_SECURE + iOS recording/screenshot
  /// detection) is now applied once, app-wide, in main.dart — every
  /// screen is covered for the whole session, not just this one.

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final signed = await _videoService.getSignedVideoUrl(
        courseId: widget.courseId,
        lessonId: widget.lessonId,
      );
      final savedSeconds = await _firestore.getLessonProgressSeconds(_uid, widget.courseId, widget.lessonId);

      final controller = VideoPlayerController.networkUrl(Uri.parse(signed.url));
      await controller.initialize();
      if (savedSeconds > 0 && savedSeconds < controller.value.duration.inSeconds) {
        await controller.seekTo(Duration(seconds: savedSeconds));
      }
      controller.play();

      // Re-fetch a fresh signed URL shortly before the current one expires,
      // so long lessons don't hit a dead link mid-playback.
      final refreshIn = signed.expiresAt.difference(DateTime.now()) - const Duration(seconds: 30);
      _urlRefreshTimer = Timer(refreshIn.isNegative ? const Duration(seconds: 5) : refreshIn, _load);

      // Save watch position every 10 seconds.
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());

      setState(() { _controller = controller; _loading = false; });
    } catch (e) {
      setState(() { _error = 'تعذّر تحميل الفيديو — تأكد إن الكورس ده مشترى'; _loading = false; });
    }
  }

  Future<void> _saveProgress({bool completed = false}) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await _firestore.saveLessonProgress(
      uid: _uid,
      courseId: widget.courseId,
      lessonId: widget.lessonId,
      positionSeconds: c.value.position.inSeconds,
      durationSeconds: c.value.duration.inSeconds,
      completed: completed,
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    _urlRefreshTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(color: Colors.black),
                  if (_loading) const CircularProgressIndicator(color: AppColors.gold),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                    ),
                  if (_controller != null && _controller!.value.isInitialized)
                    GestureDetector(
                      onTap: () => setState(() => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play()),
                      child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!)),
                    ),
                  Positioned(
                    top: 8, right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
            if (_controller != null && _controller!.value.isInitialized)
              VideoProgressIndicator(_controller!, allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: AppColors.gold, bufferedColor: Colors.white24)),
            Expanded(
              child: StreamBuilder<List<Lesson>>(
                stream: _firestore.watchLessons(widget.courseId),
                builder: (context, snap) {
                  final lessons = snap.data ?? [];
                  Lesson? current;
                  for (final l in lessons) {
                    if (l.id == widget.lessonId) current = l;
                  }
                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      if (current != null) ...[
                        Text(current.title, style: const TextStyle(color: AppColors.paper, fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('الدرس ${current.order} من ${lessons.length}', style: const TextStyle(color: Color(0xFF8FA0A8), fontSize: 12)),
                        const SizedBox(height: 18),
                      ],
                      const Text('دروس الكورس', style: TextStyle(color: AppColors.paper, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...lessons.map((l) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: l.id == widget.lessonId ? AppColors.gold : Colors.white12,
                              child: Text('${l.order}', style: TextStyle(fontSize: 11, color: l.id == widget.lessonId ? AppColors.ink : Colors.white70)),
                            ),
                            title: Text(l.title, style: const TextStyle(color: AppColors.paper, fontSize: 13)),
                            subtitle: Text(l.durationLabel, style: const TextStyle(color: Color(0xFF8FA0A8), fontSize: 11)),
                            onTap: () async {
                              await _saveProgress();
                              if (context.mounted) context.pushReplacement('/course/${widget.courseId}/lesson/${l.id}');
                            },
                          )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
