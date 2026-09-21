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

  try {
    // Do not leave the user stuck on the native/Flutter logo forever if
    // Firebase initialization is slow or blocked by network/configuration.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 12));
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

  Future<void> _retry(BuildContext context) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 12));
      }
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MasarApp()),
          (_) => false,
        );
      }
    } catch (retryError) {
      if (!context.mounted) return;
      setState(() => _retrying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يكتمل الاتصال بعد. حاول مرة أخرى.\n$retryError'),
          duration: const Duration(seconds: 5),
        ),
      );
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
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: AppColors.ink,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'تعذر تشغيل التطبيق',
                    style: TextStyle(
                      color: AppColors.paper,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'الاتصال بـ Firebase استغرق وقتًا أطول من المتوقع. اضغط إعادة المحاولة.',
                    style: TextStyle(color: Color(0xFFA9BAC0), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.error.toString(),
                    style: const TextStyle(color: Color(0xFF7F9299), fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _retrying ? null : () => _retry(context),
                    icon: _retrying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(_retrying ? 'جاري إعادة الاتصال...' : 'إعادة المحاولة'),
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
    deepLinkService.init(router);
    // Applied once, here, for the whole app — every screen is covered by
    // Android's FLAG_SECURE from this point on; on iOS this starts the
    // recording/screenshot listener that drives the overlay below.
    screenProtection.init();
    // Notifications must never be allowed to block/crash the app startup.
    NotificationService().init().catchError((_) {});
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final requestId = message.data['requestId']?.toString();
      if (requestId != null && requestId.isNotEmpty) router.push('/meeting/$requestId');
    });
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      final requestId = message?.data['requestId']?.toString();
      if (requestId != null && requestId.isNotEmpty) router.push('/meeting/$requestId');
    });
    _checkForUpdate();
    screenProtection.shouldBlockContent.listen((block) {
      if (mounted) setState(() => _blockContent = block);
    });
  }

  Future<void> _checkForUpdate() async {
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
