import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class EntryExitLogPage extends StatefulWidget {
  final ChildModel child;

  const EntryExitLogPage({
    super.key,
    required this.child,
  });

  @override
  State<EntryExitLogPage> createState() => _EntryExitLogPageState();
}

class _EntryExitLogPageState extends State<EntryExitLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _noteCtrl = TextEditingController();

  bool isSaving = false;
  bool isLoadingCurrentState = true;
  bool isLoadingRole = true;
  bool isAdminUser = false;
  String currentUserRole = '';

  String selectedEventType = 'entry';
  String? currentStatus; // inside / outside / unknown
  String? lastEventType;
  Timestamp? lastEventTime;
  String? lastCreatedByName;

  final List<Map<String, String>> eventTypes = const [
    {'value': 'entry', 'label': 'دخول'},
    {'value': 'exit', 'label': 'خروج'},
  ];

  @override
  void initState() {
    super.initState();
    initPage();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> initPage() async {
    await loadCurrentUserRole();
    await loadCurrentState();
  }

  Future<void> loadCurrentUserRole() async {
    setState(() {
      isLoadingRole = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          currentUserRole = '';
          isAdminUser = false;
          isLoadingRole = false;
        });
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final data = userDoc.data() ?? {};
      final role = (data['role'] ?? '').toString().trim().toLowerCase();

      if (!mounted) return;
      setState(() {
        currentUserRole = role;
        isAdminUser = role == 'admin';
        isLoadingRole = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentUserRole = '';
        isAdminUser = false;
        isLoadingRole = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التحقق من الصلاحية: $e'),
        ),
      );
    }
  }

  Future<void> loadCurrentState() async {
    setState(() {
      isLoadingCurrentState = true;
    });

    try {
      final latestSnapshot = await _firestore
          .collection('entry_exit_logs')
          .where('childId', isEqualTo: widget.child.id)
          .get();

      String? tempLastEventType;
      Timestamp? tempLastTime;
      String? tempLastCreatedByName;

      for (final doc in latestSnapshot.docs) {
        final data = doc.data();
        final currentType = (data['eventType'] ?? '').toString();
        final currentTime = extractTimestamp(data);
        final createdByName = (data['createdByName'] ?? '').toString();

        if (currentTime == null) continue;

        if (tempLastTime == null || currentTime.compareTo(tempLastTime) > 0) {
          tempLastTime = currentTime;
          tempLastEventType = currentType;
          tempLastCreatedByName = createdByName;
        }
      }

      String nextEventType = 'entry';
      String status = 'unknown';

      if (tempLastEventType == 'entry') {
        status = 'inside';
        nextEventType = 'exit';
      } else if (tempLastEventType == 'exit') {
        status = 'outside';
        nextEventType = 'entry';
      } else {
        status = 'unknown';
        nextEventType = 'entry';
      }

      if (!mounted) return;
      setState(() {
        lastEventType = tempLastEventType;
        lastEventTime = tempLastTime;
        lastCreatedByName = tempLastCreatedByName;
        currentStatus = status;
        selectedEventType = nextEventType;
        isLoadingCurrentState = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingCurrentState = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحميل الحالة الحالية: $e'),
        ),
      );
    }
  }

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {
        'uid': '',
        'name': 'مستخدم غير معروف',
        'role': '',
      };
    }

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data() ?? {};

    return {
      'uid': currentUser.uid,
      'name': (data['displayName'] ?? data['username'] ?? 'مستخدم').toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  Future<void> saveEntryExitEvent() async {
    if (!isAdminUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الصفحة مخصصة للإدارة فقط'),
        ),
      );
      return;
    }

    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final latestSnapshot = await _firestore
          .collection('entry_exit_logs')
          .where('childId', isEqualTo: widget.child.id)
          .get();

      String? latestType;
      Timestamp? latestTime;

      for (final doc in latestSnapshot.docs) {
        final data = doc.data();
        final currentType = (data['eventType'] ?? '').toString();
        final effectiveTime = extractTimestamp(data);

        if (effectiveTime == null) continue;

        if (latestTime == null || effectiveTime.compareTo(latestTime) > 0) {
          latestTime = effectiveTime;
          latestType = currentType;
        }
      }

      if (latestType == selectedEventType) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedEventType == 'entry'
                  ? 'الطفل مسجل كـ دخول بالفعل، لا يمكن تكرار نفس الحدث'
                  : 'الطفل مسجل كـ خروج بالفعل، لا يمكن تكرار نفس الحدث',
            ),
          ),
        );

        setState(() {
          isSaving = false;
        });
        return;
      }

      final userInfo = await fetchCurrentUserInfo();

      await _firestore.collection('entry_exit_logs').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'section': widget.child.section,
        'group': widget.child.group,
        'eventType': selectedEventType,
        'note': _noteCtrl.text.trim(),
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedEventType == 'entry'
                ? 'تم تسجيل دخول الطفل بنجاح'
                : 'تم تسجيل خروج الطفل بنجاح',
          ),
        ),
      );

      _noteCtrl.clear();
      await loadCurrentState();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ السجل: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Timestamp? extractTimestamp(Map data) {
    final dynamic primary = data['time'];
    final dynamic fallback = data['createdAt'];

    if (primary is Timestamp) return primary;
    if (fallback is Timestamp) return fallback;
    return null;
  }

  String formatDateTime(dynamic time) {
    if (time is Timestamp) {
      final date = time.toDate();
      return '${date.year}/${date.month}/${date.day} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  String eventLabel(String value) {
    switch (value) {
      case 'entry':
        return 'دخول';
      case 'exit':
        return 'خروج';
      default:
        return 'حدث';
    }
  }

  Color eventColor(String value) {
    switch (value) {
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.red;
      default:
        return AppColors.textLight;
    }
  }

  IconData eventIcon(String value) {
    switch (value) {
      case 'entry':
        return Icons.login_rounded;
      case 'exit':
        return Icons.logout_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  String currentStatusText() {
    switch (currentStatus) {
      case 'inside':
        return 'داخل الآن';
      case 'outside':
        return 'خارج الآن';
      default:
        return 'لا يوجد سجل بعد';
    }
  }

  Color currentStatusColor() {
    switch (currentStatus) {
      case 'inside':
        return Colors.green;
      case 'outside':
        return Colors.red;
      default:
        return AppColors.textLight;
    }
  }

  IconData currentStatusIcon() {
    switch (currentStatus) {
      case 'inside':
        return Icons.how_to_reg_rounded;
      case 'outside':
        return Icons.logout_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String suggestedNextActionText() {
    return selectedEventType == 'entry' ? 'تسجيل دخول' : 'تسجيل خروج';
  }

  IconData suggestedNextActionIcon() {
    return selectedEventType == 'entry'
        ? Icons.login_rounded
        : Icons.logout_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'سجل الدخول والخروج',
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (isLoadingRole || isLoadingCurrentState)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            )
          else ...[
            if (!isAdminUser) _buildAccessDeniedCard(),
            _buildCurrentStatusCard(),
            const SizedBox(height: 16),
            if (isAdminUser) _buildFormCard(),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('entry_exit_logs')
                  .where('childId', isEqualTo: widget.child.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'حدث خطأ أثناء تحميل السجل\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 40),
                      _buildEmptyState(),
                    ],
                  );
                }

                final items = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'data': data,
                    'sortTime': extractTimestamp(data),
                  };
                }).toList();

                items.sort((a, b) {
                  final aTime = a['sortTime'] as Timestamp?;
                  final bTime = b['sortTime'] as Timestamp?;

                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime);
                });

                return RefreshIndicator(
                  onRefresh: loadCurrentState,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = items[index]['data'] as Map<String, dynamic>;
                      final eventType = (data['eventType'] ?? '').toString();
                      final note = (data['note'] ?? '').toString();
                      final createdByName =
                          (data['createdByName'] ?? '').toString();
                      final createdByRole =
                          (data['createdByRole'] ?? '').toString();
                      final time = extractTimestamp(data);

                      return _EntryExitLogCard(
                        eventText: eventLabel(eventType),
                        timeText: formatDateTime(time),
                        note: note,
                        createdByName: createdByName,
                        createdByRole: createdByRole,
                        color: eventColor(eventType),
                        icon: eventIcon(eventType),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.14),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'السجل الإداري لـ ${widget.child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'هذه الصفحة مخصصة للإدارة فقط لتوثيق دخول وخروج طفل الحضانة كأحداث رسمية داخل النظام.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.redAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذه الصفحة مخصصة للإدارة فقط. يمكن لموظفة الحضانة الاطلاع على السجل، لكن لا يمكنها تسجيل دخول أو خروج من هنا.',
              style: TextStyle(
                color: AppColors.textDark,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: currentStatusColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  currentStatusIcon(),
                  color: currentStatusColor(),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الحالة الحالية',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStatusText(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: currentStatusColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'آخر حركة',
            value: lastEventType == null
                ? 'لا يوجد سجل سابق'
                : '${eventLabel(lastEventType!)} - ${formatDateTime(lastEventTime)}',
          ),
          if ((lastCreatedByName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'آخر تسجيل بواسطة',
              value: lastCreatedByName!,
            ),
          ],
          if (isAdminUser) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'الحدث المقترح التالي',
              value: suggestedNextActionText(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedEventType,
            decoration: const InputDecoration(
              labelText: 'نوع الحدث',
            ),
            items: eventTypes.map((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(item['label']!),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedEventType = value ?? 'entry';
              });
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'معبأ تلقائيًا حسب آخر حالة، ويمكن للإدارة تغييره عند الحاجة.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textLight.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظة إدارية',
              hintText: 'أدخلي ملاحظة إضافية إن وجدت',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveEntryExitEvent,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(suggestedNextActionIcon()),
              label: Text(
                isSaving ? 'جاري الحفظ...' : suggestedNextActionText(),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد سجل دخول أو خروج بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند تسجيل أول حدث إداري سيظهر هنا مباشرة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryExitLogCard extends StatelessWidget {
  final String eventText;
  final String timeText;
  final String note;
  final String createdByName;
  final String createdByRole;
  final Color color;
  final IconData icon;

  const _EntryExitLogCard({
    required this.eventText,
    required this.timeText,
    required this.note,
    required this.createdByName,
    required this.createdByRole,
    required this.color,
    required this.icon,
  });

  String roleLabel(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'admin') return 'الإدارة';
    if (role == 'teacher') return 'معلمة';
    if (role == 'nursery_staff' || role == 'nursery staff' || role == 'nursery') {
      return 'موظفة حضانة';
    }
    if (role == 'parent') return 'ولي أمر';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eventText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'الوقت',
            value: timeText,
          ),
          if (createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'سُجّل بواسطة',
              value: createdByRole.trim().isNotEmpty
                  ? '$createdByName - ${roleLabel(createdByRole)}'
                  : createdByName,
            ),
          ],
          if (note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'ملاحظة',
              value: note,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}