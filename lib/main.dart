import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('وصل إشعار والتطبيق بالخلفية: ${message.messageId}');
  debugPrint('بيانات الإشعار بالخلفية: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://ogkshpljxxwrcifvakzf.supabase.co',
    anonKey: 'sb_publishable_O1heqMdoC3f0nUR6euY0Uw_y6RJypv1',
  );

  await NotificationService.instance.init();
  await NotificationService.instance.handleInitialMessage();
  await NotificationService.instance.clearAppBadgeAndDeliveredNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: const WelcomePage(),
    );
  }
}