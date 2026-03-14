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

  Future<void> init() async {
    if (_initialized) return;

    await _requestPermission();
    await _initLocalNotifications();
    await _setupForegroundHandler();
    await _setupTokenRefreshListener();

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('تم الضغط على إشعار محلي: ${details.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'tammni_updates_channel',
      'تحديثات طمّني',
      description: 'إشعارات تحديثات الأطفال',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _setupForegroundHandler() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tammni_updates_channel',
            'تحديثات طمّني',
            channelDescription: 'إشعارات تحديثات الأطفال',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('تم فتح التطبيق من إشعار: ${message.data}');
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

  return await _messaging.getToken();
}

  Future<void> saveCurrentUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await getToken();
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setupTokenRefreshListener() async {
    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}