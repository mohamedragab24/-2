import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_router.dart';
import 'theme/app_theme.dart';
import 'services/deep_link_service.dart';
import 'services/screen_protection_service.dart';
import 'services/app_update_service.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization is local/native configuration and should not be
  // artificially failed by a short network timeout. We initialize it before
  // building Firebase-dependent screens, and show a retry only if the native
  // Firebase plugin actually reports an error.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    runApp(const MasarApp());
  } catch (error) {
    runApp(FirebaseStartupErrorApp(error: error));
  }
}

class FirebaseStartupErrorApp extends StatefulWidget {
  final Object error;
  const FirebaseStartupErrorApp({super.key, required this.error});

  @override
  State<FirebaseStartupErrorApp> createState() => _FirebaseStartupErrorAppState();
}

class _FirebaseStartupErrorAppState extends State<FirebaseStartupErrorApp> {
  bool _retrying = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _errorText = widget.error.toString();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MasarApp()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.gold, size: 58),
                  const SizedBox(height: 18),
                  const Text(
                    'تعذر تشغيل خدمات Firebase',
                    style: TextStyle(color: AppColors.paper, fontSize: 21, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'حدث خطأ أثناء تهيئة Firebase. اضغط إعادة المحاولة.',
                    style: TextStyle(color: Color(0xFFA9BAC0), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (_retrying)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _errorText ?? '',
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF81939A), fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MasarApp extends StatefulWidget {
  const MasarApp({super.key});

  @override
  State<MasarApp> createState() => _MasarAppState();
}

class _MasarAppState extends State<MasarApp> {
  late final router = buildRouter();
  final deepLinkService = DeepLinkService();
  final screenProtection = ScreenProtectionService();
  final appUpdateService = AppUpdateService();
  bool _blockContent = false;
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    // Keep startup lightweight: optional services are initialized after the
    // first frame and each failure is isolated so one plugin can never stop
    // the main application from opening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try { deepLinkService.init(router); } catch (_) {}
      screenProtection.init().catchError((_) {});
      NotificationService().init().catchError((_) {});
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        try {
          final requestId = message.data['requestId']?.toString();
          if (requestId != null && requestId.isNotEmpty) router.push('/meeting/$requestId');
        } catch (_) {}
      });
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (!mounted) return;
        final requestId = message?.data['requestId']?.toString();
        if (requestId != null && requestId.isNotEmpty) router.push('/meeting/$requestId');
      }).catchError((_) {});
      _checkForUpdate();
    });
    screenProtection.shouldBlockContent.listen((block) {
      if (mounted) setState(() => _blockContent = block);
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      // Give Firebase/router time to finish starting before showing a dialog.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || _updateDialogShown) return;

      final update = await appUpdateService.checkForAndroidUpdate();
      if (!mounted || update == null || _updateDialogShown) return;

      _updateDialogShown = true;
      await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('تحديث جديد متاح'),
        content: Text(
          'يوجد إصدار جديد من التطبيق (${update.versionName}).\n'
          'اضغط «تحديث الآن» لتحميل أحدث نسخة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقًا'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await appUpdateService.openUpdate(update);
            },
            icon: const Icon(Icons.system_update),
            label: const Text('تحديث الآن'),
          ),
        ],
      ),
      );
    } catch (_) {
      // Optional update checking must never affect normal app usage.
    }
  }

  @override
  void dispose() {
    deepLinkService.dispose();
    screenProtection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'مسار',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) {
        // Force RTL app-wide regardless of device locale, matching the
        // brand's primary language.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: [
              child!,
              // iOS-only in practice (Android never sets _blockContent since
              // FLAG_SECURE already blocks capture at the OS level). Covers
              // every screen — not just the player — the instant a
              // recording starts or a screenshot is taken.
              if (_blockContent)
                Container(
                  color: AppColors.ink,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: AppColors.gold, size: 34),
                      SizedBox(height: 12),
                      Text('تم إخفاء المحتوى لحمايته',
                          style: TextStyle(color: AppColors.paper, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
