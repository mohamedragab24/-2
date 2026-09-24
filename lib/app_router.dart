import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_shell.dart';
import 'screens/course_detail_screen.dart';
import 'screens/lesson_player_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/meeting_screen.dart';
import 'screens/admin_control_center_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/firebase_bootstrap.dart';

GoRouter buildRouter() {
  final firebaseBootstrap = FirebaseBootstrap.instance;

  return GoRouter(
    initialLocation: '/',
    refreshListenable: firebaseBootstrap.ready,
    redirect: (context, state) {
      final firebaseReady = firebaseBootstrap.ready.value && Firebase.apps.isNotEmpty;
      final loggedIn = firebaseReady && FirebaseAuth.instance.currentUser != null;
      final loggingInRoutes = ['/login', '/signup', '/forgot-password', '/', '/verify-email'];

      if (!firebaseReady) {
        // Do not force protected screens while Firebase is still starting.
        // The splash hands off to login quickly instead of hanging forever.
        if (state.matchedLocation == '/') return null;
        if (!loggingInRoutes.contains(state.matchedLocation)) return '/login';
        return null;
      }

      if (loggedIn && FirebaseAuth.instance.currentUser?.emailVerified == false && state.matchedLocation != '/verify-email') {
        return '/verify-email';
      }

      if (loggedIn && ['/login', '/signup', '/forgot-password', '/'].contains(state.matchedLocation)) {
        return '/home';
      }

      if (!loggedIn && !loggingInRoutes.contains(state.matchedLocation)) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/course/:courseId',
        builder: (context, state) => CourseDetailScreen(
          courseId: state.pathParameters['courseId']!,
          initialLessonNumber: int.tryParse(state.uri.queryParameters['lesson'] ?? '') ?? 1,
        ),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin-control', builder: (context, state) => const AdminControlCenterScreen()),
      GoRoute(path: '/meeting/:requestId', builder: (context, state) => MeetingScreen(requestId: state.pathParameters['requestId']!)),
      GoRoute(path: '/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
        path: '/course/:courseId/lesson/:lessonId',
        builder: (context, state) => LessonPlayerScreen(
          courseId: state.pathParameters['courseId']!,
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
    ],
  );
}
