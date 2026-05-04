import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'start_live_stream_page.dart';

class AdminLiveStreamRequestsPage extends StatefulWidget {
  const AdminLiveStreamRequestsPage({super.key});

  @override
  State<AdminLiveStreamRequestsPage> createState() =>
      _AdminLiveStreamRequestsPageState();
}

class _AdminLiveStreamRequestsPageState
    extends State<AdminLiveStreamRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> _processingRequestIds = {};

  String selectedStatusFilter = 'open';

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'بانتظار المراجعة';
      case 'queued':
        return 'ضمن قائمة الانتظار';
      case 'approved':
        return 'تمت الموافقة';
      case 'active':
        return 'بث نشط';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغى';
      case 'completed':
        return 'مكتمل';
      default:
        return status.trim().isEmpty ? 'غير محدد' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'queued':
        return Colors.indigo;
      case 'approved':
        return Colors.green;
      case 'active':
        return Colors.red;
      case 'completed':
        return Colors.teal;
      case 'rejected':
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'queued':
        return Icons.queue_rounded;
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'active':
        return Icons.wifi_tethering_rounded;
      case 'completed':
        return Icons.done_all_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancelled':
        return Icons.block_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  bool _isActionableStatus(String status) {
    final clean = status.trim().toLowerCase();
    return clean == 'pending' || clean == 'queued';
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _requestDate(Map<String, dynamic> data) {
    return _dateFromDynamic(data['requestedAt']) ??
        _dateFromDynamic(data['createdAt']) ??
        _dateFromDynamic(data['updatedAt']);
  }

  String _formatDateTime(dynamic value) {
    final date = _dateFromDynamic(value);

    if (date == null) return 'غير محدد';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$year/$month/$day - $hour:$minute $period';
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query =
        _firestore.collection('live_stream_requests');

    if (selectedStatusFilter == 'open') {
      query = query.where('status', whereIn: ['pending', 'queued']);
    } else if (selectedStatusFilter != 'all') {
      query = query.where('status', isEqualTo: selectedStatusFilter);
    }

    return query.limit(100);
  }

  Future<Map<String, String>> _adminInfo() async {
    final user = _auth.currentUser;

    if (user == null) {
      return {
        'uid': '',
        'name': 'الإدارة',
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      return {
        'uid': user.uid,
        'name': (data['displayName'] ??
                data['name'] ??
                data['fullName'] ??
                data['username'] ??
                user.displayName ??
                'الإدارة')
            .toString()
            .trim(),
      };
    } catch (_) {
      return {
        'uid': user.uid,
        'name': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'الإدارة',
      };
    }
  }

  Future<bool> _hasActiveLiveStream() async {
    final snapshot = await _firestore
        .collection('live_streams')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>?> _getFreshActionableRequestData(
    String requestId,
  ) async {
    final doc =
        await _firestore.collection('live_stream_requests').doc(requestId).get();

    if (!doc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يعد هذا الطلب موجودًا')),
        );
      }
      return null;
    }

    final data = doc.data() ?? <String, dynamic>{};
    final status = (data['status'] ?? '').toString();

    if (!_isActionableStatus(status)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'cancelled'
                  ? 'لا يمكن تنفيذ العملية لأن ولي الأمر ألغى الطلب'
                  : 'لا يمكن تنفيذ العملية لأن حالة الطلب أصبحت: ${_statusLabel(status)}',
            ),
          ),
        );
      }
      return null;
    }

    return {
      ...data,
      'requestId': requestId,
    };
  }

  Future<void> _updateRequestStatus({
    required String requestId,
    required String newStatus,
    required String note,
  }) async {
    final admin = await _adminInfo();

    await _firestore.collection('live_stream_requests').doc(requestId).set({
      'status': newStatus,
      'reviewNote': note,
      'reviewedByUid': admin['uid'],
      'reviewedByName': admin['name'],
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _notifyParent({
    required Map<String, dynamic> requestData,
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
  }) async {
    final admin = await _adminInfo();

    final parentUid = (requestData['parentUid'] ?? '').toString().trim();
    final parentUsername =
        (requestData['parentUsername'] ?? '').toString().trim().toLowerCase();
    final parentName = (requestData['parentName'] ?? '').toString().trim();

    if (parentUid.isEmpty && parentUsername.isEmpty) return;

    await _firestore.collection('notifications').add({
      'title': title,
      'body': body,
      'message': body,
      'type': type,
      'notificationType': type,
      'category': 'live_stream',
      'notificationFor': 'parent',
      'targetUid': parentUid,
      'targetUsername': parentUsername,
      'targetRole': 'parent',
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'childId': (requestData['childId'] ?? '').toString(),
      'childName': (requestData['childName'] ?? '').toString(),
      'section': (requestData['section'] ?? 'Nursery').toString(),
      'group': (requestData['group'] ?? '').toString(),
      'requestId': (requestData['requestId'] ?? '').toString(),
      'liveStreamRequestId': (requestData['requestId'] ?? '').toString(),
      'isRead': false,
      'read': false,
      'seen': false,
      'priority': priority,
      'importance': priority,
      'createdByUid': admin['uid'],
      'createdByName': admin['name'],
      'createdByRole': 'admin',
      'byRole': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'time': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveAndStartStream({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    if (_processingRequestIds.contains(requestId)) return;

    setState(() {
      _processingRequestIds.add(requestId);
    });

    try {
      final freshData = await _getFreshActionableRequestData(requestId);
      if (freshData == null) return;

      final active = await _hasActiveLiveStream();

      if (active) {
        await _updateRequestStatus(
          requestId: requestId,
          newStatus: 'queued',
          note: 'تم وضع الطلب ضمن قائمة الانتظار بسبب وجود بث جارٍ.',
        );

        await _notifyParent(
          requestData: freshData,
          title: 'تم وضعك ضمن قائمة الانتظار',
          body:
              'طلب البث المباشر لطفلك ${(freshData['childName'] ?? '').toString()} ضمن قائمة الانتظار لحين انتهاء البث الجاري.',
          type: 'live_stream_queued',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('يوجد بث نشط حاليًا، تم وضع الطلب ضمن قائمة الانتظار'),
          ),
        );

        setState(() {});
        return;
      }

      await _updateRequestStatus(
        requestId: requestId,
        newStatus: 'approved',
        note: 'تمت الموافقة على الطلب وجاري بدء البث.',
      );

      await _notifyParent(
        requestData: freshData,
        title: 'تمت الموافقة على طلب البث',
        body:
            'تمت الموافقة على طلب البث المباشر لطفلك ${(freshData['childName'] ?? '').toString()}.',
        type: 'live_stream_request_approved',
        priority: 'important',
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StartLiveStreamPage(
            liveStreamRequestId: requestId,
            requestedChildId: (freshData['childId'] ?? '').toString(),
            requestedChildName: (freshData['childName'] ?? '').toString(),
            requestedParentUid: (freshData['parentUid'] ?? '').toString(),
            requestedParentUsername:
                (freshData['parentUsername'] ?? '').toString(),
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Approve live stream request error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('permission-denied')
                ? 'لا توجد صلاحية لتنفيذ العملية'
                : 'حدث خطأ أثناء قبول الطلب',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _moveToQueue({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    if (_processingRequestIds.contains(requestId)) return;

    setState(() {
      _processingRequestIds.add(requestId);
    });

    try {
      final freshData = await _getFreshActionableRequestData(requestId);
      if (freshData == null) return;

      await _updateRequestStatus(
        requestId: requestId,
        newStatus: 'queued',
        note: 'تم وضع الطلب ضمن قائمة الانتظار يدويًا من الإدارة.',
      );

      await _notifyParent(
        requestData: freshData,
        title: 'تم وضعك ضمن قائمة الانتظار',
        body:
            'تم وضع طلب البث المباشر لطفلك ${(freshData['childName'] ?? '').toString()} ضمن قائمة الانتظار.',
        type: 'live_stream_queued',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم وضع الطلب ضمن قائمة الانتظار')),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Move live stream request to queue error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('permission-denied')
                ? 'لا توجد صلاحية لتنفيذ العملية'
                : 'حدث خطأ أثناء وضع الطلب في الانتظار',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestIds.remove(requestId);
        });
      }
    }
  }

  Future<void> _rejectRequest({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    if (_processingRequestIds.contains(requestId)) return;

    final freshData = await _getFreshActionableRequestData(requestId);
    if (freshData == null) return;

    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض طلب البث'),
          content: TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض اختياري',
              hintText: 'مثال: الوقت غير مناسب حاليًا',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('رفض الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      noteCtrl.dispose();
      return;
    }

    final note = noteCtrl.text.trim();
    noteCtrl.dispose();

    setState(() {
      _processingRequestIds.add(requestId);
    });

    try {
      await _updateRequestStatus(
        requestId: requestId,
        newStatus: 'rejected',
        note: note.isEmpty ? 'تم رفض طلب البث من الإدارة.' : note,
      );

      await _notifyParent(
        requestData: freshData,
        title: 'تم رفض طلب البث المباشر',
        body: note.isEmpty
            ? 'تعذر قبول طلب البث المباشر حاليًا.'
            : 'تعذر قبول طلب البث المباشر حاليًا. السبب: $note',
        type: 'live_stream_request_rejected',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض الطلب')),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Reject live stream request error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('permission-denied')
                ? 'لا توجد صلاحية لتنفيذ العملية'
                : 'حدث خطأ أثناء رفض الطلب',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestIds.remove(requestId);
        });
      }
    }
  }

  Widget _buildStatusFilter() {
    final filters = [
      {'value': 'open', 'label': 'المفتوحة'},
      {'value': 'pending', 'label': 'بانتظار المراجعة'},
      {'value': 'queued', 'label': 'قائمة الانتظار'},
      {'value': 'approved', 'label': 'الموافق عليها'},
      {'value': 'active', 'label': 'النشطة'},
      {'value': 'completed', 'label': 'المكتملة'},
      {'value': 'rejected', 'label': 'المرفوضة'},
      {'value': 'cancelled', 'label': 'الملغاة'},
      {'value': 'all', 'label': 'الكل'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final value = item['value']!;
          final label = item['label']!;
          final selected = selectedStatusFilter == value;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedStatusFilter = value;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestCard({
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    final status = (data['status'] ?? 'pending').toString();
    final color = _statusColor(status);
    final isProcessing = _processingRequestIds.contains(requestId);

    final parentName = (data['parentName'] ?? 'ولي الأمر').toString();
    final parentUsername = (data['parentUsername'] ?? '').toString();
    final childName = (data['childName'] ?? 'الطفل').toString();
    final group = (data['group'] ?? '').toString();

    final note = (data['note'] ?? '').toString().trim();
    final reviewNote = (data['reviewNote'] ?? '').toString().trim();
    final cancelReason = (data['cancelReason'] ?? '').toString().trim();
    final message = (data['message'] ?? '').toString().trim();

    final shownMessage = message.isNotEmpty
        ? message
        : note.isNotEmpty
            ? note
            : reviewNote.isNotEmpty
                ? reviewNote
                : cancelReason;

    final createdAt = data['createdAt'] ?? data['requestedAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(_statusIcon(status), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'طلب بث مباشر للطفل $childName',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              text: parentUsername.trim().isEmpty
                  ? 'ولي الأمر: $parentName'
                  : 'ولي الأمر: $parentName • $parentUsername',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.child_care_rounded,
              text: group.trim().isEmpty
                  ? 'الطفل: $childName'
                  : 'الطفل: $childName • المجموعة: $group',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.schedule_rounded,
              text: 'وقت الطلب: ${_formatDateTime(createdAt)}',
            ),
            if (status == 'cancelled') ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.block_rounded,
                text: 'تم إلغاء الطلب من ولي الأمر',
              ),
            ],
            if (shownMessage.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  shownMessage,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (_isActionableStatus(status)) ...[
              const SizedBox(height: 14),
              if (isProcessing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('جاري تنفيذ العملية...'),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveAndStartStream(
                          requestId: requestId,
                          requestData: data,
                        ),
                        icon: const Icon(Icons.wifi_tethering_rounded),
                        label: const Text('قبول وبدء بث'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: status == 'queued'
                            ? null
                            : () => _moveToQueue(
                                  requestId: requestId,
                                  requestData: data,
                                ),
                        icon: const Icon(Icons.queue_rounded),
                        label: const Text('انتظار'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _rejectRequest(
                      requestId: requestId,
                      requestData: data,
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('رفض الطلب'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'طلبات البث المباشر',
      actions: [
        IconButton(
          onPressed: () => setState(() {}),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'تحديث',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.12),
              ),
            ),
            child: const Text(
              'هنا تظهر طلبات أولياء الأمور لمشاهدة بث مباشر لطفل محدد. إذا كان هناك بث جارٍ، يتم وضع الطلبات ضمن قائمة الانتظار.',
              style: TextStyle(
                color: AppColors.textDark,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildStatusFilter(),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل الطلبات:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: _EmptyRequestsBox(),
                  );
                }

                final sortedDocs = docs.toList()
                  ..sort((a, b) {
                    final aDate = _requestDate(a.data()) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate = _requestDate(b.data()) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bDate.compareTo(aDate);
                  });

                return ListView.builder(
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    return _buildRequestCard(
                      requestId: doc.id,
                      data: doc.data(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textLight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRequestsBox extends StatelessWidget {
  const _EmptyRequestsBox();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.video_call_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد طلبات بث مباشر',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'عند إرسال ولي أمر طلب بث مباشر سيظهر هنا للمراجعة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}