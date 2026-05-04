import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'live_stream_viewer_page.dart';

class ParentNotificationsPage extends StatefulWidget {
  final String parentUsername;

  const ParentNotificationsPage({
    super.key,
    required this.parentUsername,
  });

  @override
  State<ParentNotificationsPage> createState() =>
      _ParentNotificationsPageState();
}

class _ParentNotificationsPageState extends State<ParentNotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _markingAllRead = false;

  String _cleanParentUsername() => widget.parentUsername.trim().toLowerCase();

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  Timestamp? _firstTimestamp(List<dynamic> values) {
    for (final value in values) {
      if (value is Timestamp) return value;
    }
    return null;
  }

  bool _firstBool(List<dynamic> values, {bool fallback = false}) {
    for (final value in values) {
      if (value is bool) return value;
    }
    return fallback;
  }

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final cleanParentUsername = _cleanParentUsername();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

    if (currentUid != null && currentUid.trim().isNotEmpty) {
      final byTargetUidSnapshot = await _firestore
          .collection('notifications')
          .where('targetUid', isEqualTo: currentUid)
          .get();

      allDocs.addAll(byTargetUidSnapshot.docs);

      final byParentUidSnapshot = await _firestore
          .collection('notifications')
          .where('parentUid', isEqualTo: currentUid)
          .get();

      allDocs.addAll(byParentUidSnapshot.docs);
    }

    if (cleanParentUsername.isNotEmpty) {
      final byUsernameSnapshot = await _firestore
          .collection('notifications')
          .where('parentUsername', isEqualTo: cleanParentUsername)
          .get();

      allDocs.addAll(byUsernameSnapshot.docs);
    }

    final seenIds = <String>{};
    final uniqueDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in allDocs) {
      if (seenIds.add(doc.id)) {
        uniqueDocs.add(doc);
      }
    }

    final items = uniqueDocs.map((doc) {
      final data = doc.data();

      final time = _firstTimestamp([
        data['time'],
        data['createdAt'],
        data['timestamp'],
        data['updatedAt'],
        data['eventAt'],
      ]);

      return {
        'id': doc.id,
        'title': _firstNonEmpty([
          data['title'],
          data['subject'],
          data['notificationTitle'],
        ]),
        'body': _firstNonEmpty([
          data['body'],
          data['message'],
          data['text'],
          data['description'],
          data['details'],
        ]),
        'childId': _firstNonEmpty([
          data['childId'],
        ]),
        'childName': _firstNonEmpty([
          data['childName'],
          data['name'],
        ]),
        'type': _firstNonEmpty([
          data['type'],
          data['notificationType'],
          data['category'],
        ]),
        'isRead': _firstBool([
          data['isRead'],
          data['read'],
          data['seen'],
        ]),
        'time': time,
        'createdByUid': _firstNonEmpty([
          data['createdByUid'],
          data['senderId'],
          data['byUid'],
        ]),
        'createdByName': _firstNonEmpty([
          data['createdByName'],
          data['senderName'],
          data['byName'],
          data['staffName'],
          data['adminName'],
        ]),
        'createdByRole': _normalizeRole(_firstNonEmpty([
          data['createdByRole'],
          data['byRole'],
          data['senderRole'],
          data['role'],
        ])),
        'priority': _firstNonEmpty([
          data['priority'],
          data['importance'],
          data['level'],
        ]),
        'targetUid': _firstNonEmpty([
          data['targetUid'],
          data['receiverId'],
          data['parentUid'],
        ]),
        'targetRole': _normalizeRole(_firstNonEmpty([
          data['targetRole'],
          data['receiverRole'],
          data['notificationFor'],
        ])),
        'notificationFor': _normalizeRole(_firstNonEmpty([
          data['notificationFor'],
          data['targetRole'],
        ])),
        'messageId': _firstNonEmpty([
          data['messageId'],
        ]),
        'conversationChildId': _firstNonEmpty([
          data['conversationChildId'],
          data['childId'],
        ]),
        'emoji': _firstNonEmpty([
          data['emoji'],
          data['reaction'],
        ]),
        'roomId': _firstNonEmpty([
          data['roomId'],
          data['liveStreamId'],
        ]),
        'liveStreamId': _firstNonEmpty([
          data['liveStreamId'],
          data['roomId'],
        ]),
        'streamTitle': _firstNonEmpty([
          data['streamTitle'],
          data['title'],
        ]),
      };
    }).toList();

    items.sort((a, b) {
      final aTime = a['time'] as Timestamp?;
      final bTime = b['time'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items;
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    try {
      await _firestore.collection('notifications').doc(notificationId).set({
        'isRead': true,
        'read': true,
        'seen': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // لا نوقف الصفحة بسبب فشل بسيط في تحديث القراءة
    }
  }

  Future<void> _markAllAsRead(List<Map<String, dynamic>> items) async {
    if (_markingAllRead) return;

    final unreadItems = items.where((item) => item['isRead'] != true).toList();

    if (unreadItems.isEmpty) return;

    setState(() {
      _markingAllRead = true;
    });

    try {
      final batch = _firestore.batch();

      for (final item in unreadItems) {
        final id = (item['id'] ?? '').toString();
        if (id.trim().isEmpty) continue;

        final ref = _firestore.collection('notifications').doc(id);
        batch.set(
          ref,
          {
            'isRead': true,
            'read': true,
            'seen': true,
            'readAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تعليم الإشعارات كمقروءة: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _markingAllRead = false;
      });
    }
  }

  Future<void> _openLiveStreamFromNotification(Map<String, dynamic> data) async {
    final notificationId = (data['id'] ?? '').toString();
    await _markNotificationAsRead(notificationId);

    final roomId = (data['roomId'] ?? data['liveStreamId'] ?? '').toString();
    final title = (data['streamTitle'] ?? data['title'] ?? 'بث مباشر من الحضانة')
        .toString();
    final startedByName = (data['createdByName'] ?? '').toString();

    if (roomId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات البث غير مكتملة')),
      );
      return;
    }

    try {
      final streamDoc =
          await _firestore.collection('live_streams').doc(roomId).get();

      if (!streamDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا البث غير موجود أو تم حذفه')),
        );
        return;
      }

      final streamData = streamDoc.data() ?? {};
      final status = (streamData['status'] ?? '').toString();

      if (status != 'active') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتهى هذا البث المباشر')),
        );
        return;
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamViewerPage(
            roomId: roomId,
            title: (streamData['title'] ?? title).toString(),
            startedByName:
                (streamData['startedByName'] ?? startedByName).toString(),
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح البث: $e')),
      );
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final id = (data['id'] ?? '').toString();
    final type = (data['type'] ?? '').toString().trim().toLowerCase();

    await _markNotificationAsRead(id);

    if (!mounted) return;

    if (type == 'live_stream_started') {
      await _openLiveStreamFromNotification(data);
      return;
    }

    setState(() {});
  }

  Widget _buildTopSummary(List<Map<String, dynamic>> items) {
    final unreadCount = items.where((item) => item['isRead'] != true).length;
    final totalCount = items.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withOpacity(0.8)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                unreadCount > 0
                    ? 'لديك $unreadCount إشعار غير مقروء من أصل $totalCount'
                    : 'كل الإشعارات مقروءة',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
            if (unreadCount > 0)
              TextButton.icon(
                onPressed: _markingAllRead ? null : () => _markAllAsRead(items),
                icon: _markingAllRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('قراءة الكل'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStreamButton(Map<String, dynamic> data) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openLiveStreamFromNotification(data),
        icon: const Icon(Icons.play_circle_outline_rounded),
        label: const Text('مشاهدة البث'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildEndedLiveStreamBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.stop_circle_outlined,
            color: Colors.grey,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم إنهاء هذا البث المباشر',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: Container(
        color: AppColors.background,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchNotifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'حدث خطأ في تحميل الإشعارات:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.notifications_none_outlined,
                          size: 46,
                          color: AppColors.textLight,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'لا يوجد إشعارات بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 10),
                itemCount: items.length + 1,
                separatorBuilder: (_, index) {
                  if (index == 0) return const SizedBox(height: 2);
                  return const SizedBox(height: 2);
                },
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildTopSummary(items);
                  }

                  final data = items[index - 1];

                  final title = (data['title'] ?? '').toString();
                  final body = (data['body'] ?? '').toString();
                  final childName = (data['childName'] ?? '').toString();
                  final type = (data['type'] ?? '').toString();

                  final isLiveStreamStarted =
                      type.trim().toLowerCase() == 'live_stream_started';

                  final isLiveStreamEnded =
                      type.trim().toLowerCase() == 'live_stream_ended';

                  final roomId =
                      (data['roomId'] ?? data['liveStreamId'] ?? '').toString();
                  final createdByName =
                      (data['createdByName'] ?? '').toString();
                  final createdByRole =
                      (data['createdByRole'] ?? '').toString();
                  final priority = (data['priority'] ?? '').toString();
                  final isRead = data['isRead'] == true;
                  final rawTime = data['time'] as Timestamp?;

                  final color = _typeColor(type);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: isRead ? 1 : 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _handleNotificationTap(data),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withOpacity(0.12),
                              child: Icon(
                                _iconForType(type),
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title.isEmpty
                                              ? _defaultTitle(type)
                                              : title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isRead
                                                ? AppColors.textLight
                                                : AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (childName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'الطفل: $childName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  if (body.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      body,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                  if (createdByName.isNotEmpty ||
                                      createdByRole.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'من: ${_senderLabel(createdByName, createdByRole)}',
                                      style: const TextStyle(
                                        color: AppColors.textLight,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                  if (priority.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _priorityColor(priority)
                                            .withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _priorityLabel(priority),
                                        style: TextStyle(
                                          color: _priorityColor(priority),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTime(rawTime),
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isLiveStreamStarted &&
                                      roomId.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _buildLiveStreamButton(data),
                                  ],
                                  if (isLiveStreamEnded) ...[
                                    const SizedBox(height: 12),
                                    _buildEndedLiveStreamBox(),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _typeLabel(type),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  static String _senderLabel(String createdByName, String createdByRole) {
    final role = createdByRole.trim().toLowerCase();

    String roleLabel;
    if (role == 'nursery' ||
        role == 'nursery_staff' ||
        role == 'nursery staff') {
      roleLabel = 'موظفة الحضانة';
    } else if (role == 'admin') {
      roleLabel = 'الإدارة';
    } else if (role == 'parent') {
      roleLabel = 'وليّ الأمر';
    } else {
      roleLabel = createdByRole.trim();
    }

    if (createdByName.trim().isNotEmpty && roleLabel.isNotEmpty) {
      return '$createdByName - $roleLabel';
    }

    if (createdByName.trim().isNotEmpty) {
      return createdByName;
    }

    if (roleLabel.isNotEmpty) {
      return roleLabel;
    }

    return 'غير محدد';
  }

  static IconData _iconForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'message_reaction':
        return Icons.emoji_emotions_outlined;
      case 'live_stream_started':
        return Icons.wifi_tethering_rounded;
      case 'live_stream_ended':
        return Icons.stop_circle_outlined;
      case 'entry':
        return Icons.login_outlined;
      case 'exit':
        return Icons.logout_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'supplies':
        return Icons.inventory_2_outlined;
      case 'media':
        return Icons.photo_camera_back_outlined;
      case 'update_notification':
        return Icons.campaign_outlined;
      case 'nursery_notification':
        return Icons.notifications_active_outlined;
      case 'custom':
        return Icons.mark_email_unread_outlined;
      case 'complaint_reply':
        return Icons.reply_all_rounded;
      case 'invoice_created':
      case 'invoice_updated':
        return Icons.receipt_long_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  static Color _typeColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'message':
        return Colors.blue;
      case 'message_reaction':
        return Colors.purple;
      case 'live_stream_started':
        return Colors.red;
      case 'live_stream_ended':
        return Colors.grey;
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.orange;
      case 'health':
        return Colors.redAccent;
      case 'supplies':
        return Colors.deepPurple;
      case 'media':
        return Colors.blue;
      case 'nursery_notification':
        return AppColors.secondary;
      case 'update_notification':
        return AppColors.primary;
      case 'custom':
        return Colors.teal;
      case 'complaint_reply':
        return Colors.indigo;
      case 'invoice_created':
      case 'invoice_updated':
        return Colors.brown;
      default:
        return AppColors.primary;
    }
  }

  static String _typeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'message':
        return 'رسالة';
      case 'message_reaction':
        return 'تفاعل';
      case 'live_stream_started':
        return 'بث مباشر';
      case 'live_stream_ended':
        return 'انتهاء البث';
      case 'entry':
        return 'دخول موثّق';
      case 'exit':
        return 'خروج موثّق';
      case 'health':
        return 'صحة';
      case 'supplies':
        return 'مستلزمات';
      case 'media':
        return 'وسائط';
      case 'custom':
        return 'إشعار خاص';
      case 'nursery_notification':
        return 'إشعار';
      case 'update_notification':
        return 'تحديث';
      case 'complaint_reply':
        return 'رد شكوى';
      case 'invoice_created':
        return 'فاتورة';
      case 'invoice_updated':
        return 'تحديث فاتورة';
      default:
        return type.trim().isEmpty ? 'إشعار' : type;
    }
  }

  static String _defaultTitle(String type) {
    switch (type.trim().toLowerCase()) {
      case 'message':
        return 'رسالة جديدة';
      case 'message_reaction':
        return 'تفاعل جديد على رسالتك';
      case 'live_stream_started':
        return 'بدأ بث مباشر الآن';
      case 'live_stream_ended':
        return 'انتهى البث المباشر';
      case 'entry':
        return 'تم توثيق دخول الطفل';
      case 'exit':
        return 'تم توثيق خروج الطفل';
      case 'health':
        return 'ملاحظة صحية';
      case 'supplies':
        return 'مستلزمات مطلوبة';
      case 'media':
        return 'تمت إضافة صورة أو فيديو';
      case 'update_notification':
        return 'تحديث جديد';
      case 'nursery_notification':
        return 'إشعار جديد';
      case 'custom':
        return 'إشعار خاص';
      case 'complaint_reply':
        return 'رد جديد من الإدارة';
      case 'invoice_created':
        return 'فاتورة جديدة';
      case 'invoice_updated':
        return 'تم تحديث فاتورة';
      default:
        return 'إشعار جديد';
    }
  }

  static String _priorityLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'urgent':
        return 'عاجل';
      case 'important':
        return 'مهم';
      case 'normal':
        return 'عادي';
      default:
        return value.trim().isEmpty ? 'عادي' : value;
    }
  }

  static Color _priorityColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'urgent':
        return Colors.redAccent;
      case 'important':
        return Colors.orange;
      case 'normal':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  static String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'بدون وقت';

    final date = timestamp.toDate();
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year/$month/$day - $hour:$minute';
  }
}