import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;

  static const String _channelId = 'tammni_high_importance_channel';
  static const String _channelName = 'إشعارات طمّني';
  static const String _channelDescription =
      'إشعارات مهمة من تطبيق طمّني مثل تحديثات الأطفال والرسائل';

  Future<void> init() async {
    if (_initialized) return;

    await _requestPermission();
    await _initLocalNotifications();
    await _setupForegroundPresentationOptions();
    await _setupForegroundHandler();
    await _setupTokenRefreshListener();

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('حالة إذن الإشعارات: ${settings.authorizationStatus}');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('تم الضغط على إشعار محلي: ${details.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _setupForegroundPresentationOptions() async {
    if (kIsWeb) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupForegroundHandler() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('وصل إشعار والتطبيق مفتوح: ${message.data}');

      final notification = message.notification;

      final title =
          notification?.title ?? message.data['title']?.toString() ?? 'طمّني';

      final body =
          notification?.body ?? message.data['body']?.toString() ?? '';

      if (title.trim().isEmpty && body.trim().isEmpty) return;

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.message,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('تم فتح التطبيق من إشعار وهو بالخلفية: ${message.data}');
    });
  }

  Future<void> handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('التطبيق فُتح من إشعار وهو مغلق: ${initialMessage.data}');
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;

    try {
      final token = await _messaging.getToken();
      debugPrint('FCM TOKEN: $token');
      return token;
    } catch (e) {
      debugPrint('فشل جلب FCM token: $e');
      return null;
    }
  }

  Future<void> saveCurrentUserToken() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await getToken();
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('تم حفظ FCM token للمستخدم الحالي');
  }

  Future<void> _setupTokenRefreshListener() async {
    if (kIsWeb) return;

    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('تم تحديث FCM token للمستخدم الحالي');
    });
  }
}