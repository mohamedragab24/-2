import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../models/course.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final int initialLessonNumber;
  const CourseDetailScreen({super.key, required this.courseId, this.initialLessonNumber = 1});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _openedInitialLesson = false;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: FutureBuilder<Course?>(
        future: firestore.getCourse(widget.courseId),
        builder: (context, courseSnap) {
          if (!courseSnap.hasData) return const Center(child: CircularProgressIndicator());
          final course = courseSnap.data;
          if (course == null) return const Center(child: Text('الكورس غير موجود'));

          return FutureBuilder<bool>(
            future: uid == null ? Future.value(false) : firestore.hasPurchased(uid, widget.courseId),
            builder: (context, purchasedSnap) {
              final purchased = purchasedSnap.data ?? false;
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 210,
                    pinned: true,
                    backgroundColor: AppColors.ink,
                    leading: IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.white), onPressed: () => context.pop()),
                    flexibleSpace: FlexibleSpaceBar(
                      background: CachedNetworkImage(imageUrl: course.thumbnailUrl, fit: BoxFit.cover),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 21)),
                          const SizedBox(height: 8),
                          Text('المدرب: ${course.instructorName}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(height: 14),
                          Row(children: [
                            const Icon(Icons.star, color: AppColors.gold, size: 15),
                            Text(' ${course.rating}   ', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${course.studentsCount} طالب   ', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                            Text(course.durationLabel, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ]),
                          const SizedBox(height: 16),
                          Text(course.description, style: const TextStyle(height: 1.8, fontSize: 13.5, color: Color(0xFF3C4650))),
                          const SizedBox(height: 20),
                          ...course.features.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  const Icon(Icons.check_circle, color: AppColors.emerald, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                                ]),
                              )),
                          const SizedBox(height: 20),
                          Text('محتوى الكورس', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16.5)),
                          StreamBuilder<List<Lesson>>(
                            stream: firestore.watchLessons(widget.courseId),
                            builder: (context, lessonSnap) {
                              final lessons = lessonSnap.data ?? [];
                              if (!_openedInitialLesson && widget.initialLessonNumber >= 2 && lessons.isNotEmpty) {
                                final matches = lessons.where((l) => l.order == widget.initialLessonNumber).toList();
                                final target = matches.isEmpty ? null : matches.first;
                                if (target != null) {
                                  _openedInitialLesson = true;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) context.push('/course/${widget.courseId}/lesson/${target.id}');
                                  });
                                }
                              }
                              return Column(
                                children: lessons.map((l) {
                                  final locked = !purchased && !l.isPreview;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppColors.paperDim,
                                      child: Text('${l.order}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                    ),
                                    title: Text(l.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    subtitle: Text(l.durationLabel, style: const TextStyle(fontSize: 11.5)),
                                    trailing: Icon(locked ? Icons.lock_outline : Icons.play_circle_outline, size: 18, color: AppColors.muted),
                                    onTap: locked ? null : () => context.push('/course/${widget.courseId}/lesson/${l.id}'),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
