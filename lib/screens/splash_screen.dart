import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase_bootstrap.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _waitForStartup();
  }

  Future<void> _waitForStartup() async {
    // Splash is only a visual hand-off. Never wait for Firebase here.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    if (FirebaseBootstrap.instance.ready.value && Firebase.apps.isNotEmpty) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      context.go(loggedIn ? '/home' : '/login');
    } else {
      // Firebase may still finish in the background. The router listens to
      // FirebaseBootstrap.ready and will move an already-authenticated user
      // to the correct screen when it becomes available.
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.school_outlined, color: AppColors.ink, size: 40),
            ),
            const SizedBox(height: 18),
            Text('مسار',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.paper, fontSize: 30)),
            const SizedBox(height: 6),
            const Text('تعلّم في أي وقت، من أي مكان', style: TextStyle(color: Color(0xFFA9BAC0), fontSize: 13)),
            const SizedBox(height: 26),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}
