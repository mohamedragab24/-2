import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_router.dart';
import 'theme/app_theme.dart';
import 'services/deep_link_service.dart';
import 'services/screen_protection_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android and iOS, Firebase.initializeApp() reads the native config
  // files automatically — android/app/google-services.json and
  // ios/Runner/GoogleService-Info.plist (already placed in this project).
  // No FirebaseOptions object is required for those two platforms.
  await Firebase.initializeApp();

  runApp(const MasarApp());
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
  bool _blockContent = false;

  @override
  void initState() {
    super.initState();
    deepLinkService.init(router);
    // Applied once, here, for the whole app — every screen is covered by
    // Android's FLAG_SECURE from this point on; on iOS this starts the
    // recording/screenshot listener that drives the overlay below.
    screenProtection.init();
    screenProtection.shouldBlockContent.listen((block) {
      if (mounted) setState(() => _blockContent = block);
    });
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
