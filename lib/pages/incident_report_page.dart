import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class IncidentReportPage extends StatefulWidget {
  final ChildModel child;

  const IncidentReportPage({
    super.key,
    required this.child,
  });

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController detailsCtrl = TextEditingController();
  final TextEditingController actionCtrl = TextEditingController();

  String incidentType = 'حادث بسيط';
  String priority = 'important'; // normal / important / urgent
  bool parentNotified = false;
  bool isSaving = false;

  @override
  void dispose() {
    detailsCtrl.dispose();
    actionCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {'uid': '', 'name': 'مستخدم', 'role': ''};
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

  Future<void> saveIncident() async {
    if (detailsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي تفاصيل الحادث أو الملاحظة')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();

      await _firestore.collection('incident_reports').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'section': widget.child.section,
        'group': widget.child.group,
        'incidentType': incidentType,
        'priority': priority,
        'details': detailsCtrl.text.trim(),
        'actionTaken': actionCtrl.text.trim(),
        'parentNotified': parentNotified,
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (parentNotified) {
        await _firestore.collection('notifications').add({
          'childId': widget.child.id,
          'childName': widget.child.name,
          'parentUsername': widget.child.parentUsername,
          'section': widget.child.section,
          'group': widget.child.group,
          'title': 'ملاحظة مهمة من الحضانة',
          'message':
              'تم تسجيل ملاحظة مهمة تخص ${widget.child.name}، يرجى المتابعة.',
          'type': 'incident_notification',
          'isRead': false,
          'createdAt': Timestamp.now(),
          'time': FieldValue.serverTimestamp(),
          'createdByUid': userInfo['uid'],
          'createdByName': userInfo['name'],
          'createdByRole': userInfo['role'],
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التقرير بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  String formatDateTime(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final d = rawTime.toDate();
      return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  Color priorityColor(String p) {
    if (p == 'urgent') return Colors.red;
    if (p == 'important') return Colors.orange;
    return AppColors.success;
  }

  String priorityLabel(String p) {
    if (p == 'urgent') return 'عاجل';
    if (p == 'important') return 'مهم';
    return 'عادي';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'حادث / ملاحظة مهمة',
      child: Column(
        children: [
          Container(
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
                const Text(
                  'تقرير حادث أو ملاحظة مهمة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'توثيق سريع لحالة تخص ${widget.child.name} مع إمكانية إشعار ولي الأمر.',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  DropdownButtonFormField<String>(
                    value: incidentType,
                    decoration: const InputDecoration(labelText: 'نوع الحالة'),
                    items: const [
                      DropdownMenuItem(
                          value: 'حادث بسيط', child: Text('حادث بسيط')),
                      DropdownMenuItem(
                          value: 'ملاحظة صحية', child: Text('ملاحظة صحية')),
                      DropdownMenuItem(
                          value: 'سقوط بسيط', child: Text('سقوط بسيط')),
                      DropdownMenuItem(value: 'خدش', child: Text('خدش')),
                      DropdownMenuItem(
                          value: 'بكاء شديد', child: Text('بكاء شديد')),
                      DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        incidentType = value ?? 'حادث بسيط';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'الأولوية'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('عادي')),
                      DropdownMenuItem(value: 'important', child: Text('مهم')),
                      DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        priority = value ?? 'important';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'التفاصيل',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: actionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'الإجراء الذي تم اتخاذه',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: parentNotified,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        parentNotified = value;
                      });
                    },
                    title: const Text(
                      'تم/سيتم إشعار ولي الأمر',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveIncident,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التقرير'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('incident_reports')
                  .where('childId', isEqualTo: widget.child.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('لا يوجد تقارير بعد'));
                }

                final items = docs
                    .map((e) => e.data() as Map<String, dynamic>)
                    .toList();
                items.sort((a, b) {
                  final aTime =
                      (a['time'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
                  final bTime =
                      (b['time'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final p = (item['priority'] ?? 'important').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['incidentType'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              priorityLabel(p),
                              style: TextStyle(
                                color: priorityColor(p),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الوقت: ${formatDateTime(item['time'] ?? item['createdAt'])}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'التفاصيل: ${item['details'] ?? ''}',
                              style: const TextStyle(
                                color: AppColors.textDark,
                                height: 1.4,
                              ),
                            ),
                            if ((item['actionTaken'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'الإجراء: ${item['actionTaken']}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              (item['parentNotified'] == true)
                                  ? 'تم إشعار ولي الأمر'
                                  : 'لم يتم إشعار ولي الأمر',
                              style: TextStyle(
                                color: (item['parentNotified'] == true)
                                    ? AppColors.success
                                    : AppColors.textLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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