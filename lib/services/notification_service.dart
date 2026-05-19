import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
  bool _lifecycleObserverAdded = false;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  static const String _channelId = 'tammni_high_importance_channel';
  static const String _channelName = 'إشعارات طمّني';
  static const String _channelDescription =
      'إشعارات مهمة من تطبيق طمّني مثل تحديثات الأطفال والرسائل';

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint('NotificationService: Web غير مدعوم حاليًا للإشعارات');
      return;
    }

    await _requestPermission();
    await _initLocalNotifications();
    await _setupForegroundPresentationOptions();

    _setupForegroundHandler();
    _setupTokenRefreshListener();
    _setupAppLifecycleBadgeCleaner();

    await clearAppBadgeAndDeliveredNotifications();

    _initialized = true;
  }

  /// استدعي هذه الدالة بعد تسجيل الدخول مباشرة.
  /// تنظّف التوكن من أي حساب قديم، ثم تحفظه للحساب الحالي.
  Future<void> setupForCurrentUser() async {
    await init();
    await saveCurrentUserToken();
    await handleInitialMessage();
  }

  void _setupAppLifecycleBadgeCleaner() {
    if (_lifecycleObserverAdded) return;

    WidgetsBinding.instance.addObserver(_NotificationLifecycleObserver());
    _lifecycleObserverAdded = true;
  }

  Future<void> clearAppBadgeAndDeliveredNotifications() async {
    if (kIsWeb) return;

    try {
      await _localNotifications.cancelAll();

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.cancelAll();

      debugPrint('NotificationService: تم مسح إشعارات التطبيق والعداد');
    } catch (e) {
      debugPrint('NotificationService: فشل مسح الإشعارات أو العداد: $e');
    }
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'NotificationService: حالة إذن الإشعارات: ${settings.authorizationStatus}',
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        debugPrint(
          'NotificationService: تم الضغط على إشعار محلي: ${details.payload}',
        );

        await clearAppBadgeAndDeliveredNotifications();
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

  void _setupForegroundHandler() {
    _foregroundMessageSubscription?.cancel();

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
        'NotificationService: وصل إشعار والتطبيق مفتوح: ${message.data}',
      );

      final notification = message.notification;

      final title =
          notification?.title ?? message.data['title']?.toString() ?? 'طمّني';

      final body =
          notification?.body ?? message.data['body']?.toString() ?? '';

      if (title.trim().isEmpty && body.trim().isEmpty) return;

      await _showLocalNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
      );
    });

    _messageOpenedSubscription?.cancel();

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) async {
        debugPrint(
          'NotificationService: تم فتح التطبيق من إشعار وهو بالخلفية: ${message.data}',
        );

        await clearAppBadgeAndDeliveredNotifications();
      },
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    if (kIsWeb) return;

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title.trim().isEmpty ? 'طمّني' : title.trim(),
        body.trim(),
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
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService: فشل عرض الإشعار المحلي: $e');
    }
  }

  Future<void> handleInitialMessage() async {
    if (kIsWeb) return;

    try {
      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint(
          'NotificationService: التطبيق فُتح من إشعار وهو مغلق: ${initialMessage.data}',
        );
      }

      await clearAppBadgeAndDeliveredNotifications();
    } catch (e) {
      debugPrint('NotificationService: فشل handleInitialMessage: $e');
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;

    try {
      final token = await _messaging.getToken();
      debugPrint('NotificationService: FCM TOKEN: $token');
      return token;
    } catch (e) {
      debugPrint('NotificationService: فشل جلب FCM token: $e');
      return null;
    }
  }

  Future<void> _removeTokenFromOldAccounts({
    required String token,
    required String currentUid,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty || currentUid.trim().isEmpty) return;

    final usersRef = FirebaseFirestore.instance.collection('users');

    try {
      final oldArrayOwners = await usersRef
          .where('fcmTokens', arrayContains: cleanToken)
          .get();

      for (final doc in oldArrayOwners.docs) {
        if (doc.id == currentUid) continue;

        await doc.reference.set({
          'fcmTokens': FieldValue.arrayRemove([cleanToken]),
          'lastTokenRemovedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          'NotificationService: تم حذف token من حساب قديم array uid=${doc.id}',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: فشل تنظيف fcmTokens القديمة: $e');
    }

    try {
      final oldSingleOwners =
          await usersRef.where('fcmToken', isEqualTo: cleanToken).get();

      for (final doc in oldSingleOwners.docs) {
        if (doc.id == currentUid) continue;

        await doc.reference.set({
          'fcmToken': FieldValue.delete(),
          'lastTokenRemovedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
          'NotificationService: تم حذف token مفرد من حساب قديم uid=${doc.id}',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: فشل تنظيف fcmToken القديم: $e');
    }
  }

  Future<void> saveCurrentUserToken() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('NotificationService: لا يوجد مستخدم لحفظ FCM token');
      return;
    }

    final token = await getToken();

    if (token == null || token.trim().isEmpty) {
      debugPrint('NotificationService: FCM token فارغ، لم يتم الحفظ');
      return;
    }

    final cleanToken = token.trim();

    try {
      await _removeTokenFromOldAccounts(
        token: cleanToken,
        currentUid: user.uid,
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([cleanToken]),
        'fcmToken': cleanToken,
        'fcmTokenOwnerUid': user.uid,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('NotificationService: تم حفظ FCM token للحساب الحالي فقط');
    } catch (e) {
      debugPrint('NotificationService: فشل حفظ FCM token: $e');
    }
  }

  Future<void> removeCurrentUserToken() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await getToken();
    if (token == null || token.trim().isEmpty) return;

    final cleanToken = token.trim();

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userDoc = await userRef.get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final currentSingleToken = (data['fcmToken'] ?? '').toString().trim();

      final updateData = <String, dynamic>{
        'fcmTokens': FieldValue.arrayRemove([cleanToken]),
        'lastTokenRemovedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (currentSingleToken == cleanToken) {
        updateData['fcmToken'] = FieldValue.delete();
      }

      await userRef.set(updateData, SetOptions(merge: true));

      debugPrint('NotificationService: تم حذف FCM token من الحساب الحالي');
    } catch (e) {
      debugPrint('NotificationService: فشل حذف FCM token من الحساب الحالي: $e');
    }
  }

  void _setupTokenRefreshListener() {
    if (kIsWeb) return;

    _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) async {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          debugPrint(
            'NotificationService: token refresh وصل لكن لا يوجد مستخدم حالي',
          );
          return;
        }

        if (newToken.trim().isEmpty) return;

        final cleanToken = newToken.trim();

        try {
          await _removeTokenFromOldAccounts(
            token: cleanToken,
            currentUid: user.uid,
          );

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fcmTokens': FieldValue.arrayUnion([cleanToken]),
            'fcmToken': cleanToken,
            'fcmTokenOwnerUid': user.uid,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          debugPrint('NotificationService: تم تحديث FCM token للحساب الحالي فقط');
        } catch (e) {
          debugPrint('NotificationService: فشل تحديث FCM token: $e');
        }
      },
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;

    _initialized = false;
  }
}

class _NotificationLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        NotificationService.instance.clearAppBadgeAndDeliveredNotifications(),
      );
    }
  }
}