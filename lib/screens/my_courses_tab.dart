import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/course.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class MyCoursesTab extends StatelessWidget {
  const MyCoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('يجب تسجيل الدخول أولاً'),
        ),
      );
    }

    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('كورساتي'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<String>>(
        stream: service.watchMyCourseIds(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final ids = snapshot.data ?? [];

          if (ids.isEmpty) {
            return const _EmptyCourses();
          }

          return FutureBuilder<List<Course>>(
            future: service.getCoursesByIds(ids),
            builder: (context, courseSnapshot) {
              if (courseSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final courses = courseSnapshot.data ?? [];

              if (courses.isEmpty) {
                return const _EmptyCourses();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final course = courses[index];

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        context.push('/course/${course.id}');
                      },
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: course.thumbnailUrl.isEmpty
                                ? Container(
                                    color:
                                        AppColors.emeraldLight,
                                    child: const Icon(
                                      Icons.menu_book,
                                      size: 60,
                                    ),
                                  )
                                : Image.network(
                                    course.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) {
                                      return Container(
                                        color: AppColors
                                            .emeraldLight,
                                        child: const Icon(
                                          Icons.menu_book,
                                          size: 60,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  course.instructorName,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${course.lessonsCount} درس',
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 72,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'لم تشترِ أي كورس بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'الكورسات التي تشتريها ستظهر هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
