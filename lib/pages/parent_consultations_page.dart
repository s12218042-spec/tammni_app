import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentConsultationsPage extends StatefulWidget {
  final String parentUsername;

  const ParentConsultationsPage({
    super.key,
    required this.parentUsername,
  });

  @override
  State<ParentConsultationsPage> createState() =>
      _ParentConsultationsPageState();
}

class _ParentConsultationsPageState extends State<ParentConsultationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedStatus = 'all';
  bool isUpdating = false;

  String get cleanUsername => widget.parentUsername.trim().toLowerCase();

  String formatMoney(dynamic value) {
    if (value == null) return '0';
    if (value is int) return value.toString();

    if (value is double) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(2);
    }

    if (value is num) {
      final val = value.toDouble();
      if (val == val.roundToDouble()) return val.toInt().toString();
      return val.toStringAsFixed(2);
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) return value.toString();
    if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();
    return parsed.toStringAsFixed(2);
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }

    if (value is DateTime) {
      return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
    }

    return 'غير محدد';
  }

  String approvalLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوضة';
      case 'pending':
      default:
        return 'بانتظار موافقتك';
    }
  }

  Color approvalColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String consultationStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
        return 'مكتملة';
      case 'scheduled':
        return 'مجدولة';
      case 'cancelled':
        return 'ملغاة';
      case 'proposed':
      default:
        return 'مقترحة';
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchConsultations() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid != null && currentUid.trim().isNotEmpty) {
      final byUid = await _firestore
          .collection('child_consultations')
          .where('parentUid', isEqualTo: currentUid)
          .get();

      if (byUid.docs.isNotEmpty) {
        return byUid.docs;
      }
    }

    if (cleanUsername.isEmpty) return [];

    final byUsername = await _firestore
        .collection('child_consultations')
        .where('parentUsername', isEqualTo: cleanUsername)
        .get();

    return byUsername.docs;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (selectedStatus == 'all') return docs;

    return docs.where((doc) {
      final status =
          (doc.data()['parentApprovalStatus'] ?? 'pending').toString();

      return status.trim().toLowerCase() == selectedStatus;
    }).toList();
  }

Future<Map<String, String>> fetchCurrentParentInfo() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return {
      'uid': '',
      'name': 'ولي الأمر',
      'username': cleanUsername,
    };
  }

  try {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    return {
      'uid': user.uid,
      'name': (data['displayName'] ??
              data['name'] ??
              data['fullName'] ??
              data['username'] ??
              'ولي الأمر')
          .toString()
          .trim(),
      'username': (data['username'] ?? cleanUsername)
          .toString()
          .trim()
          .toLowerCase(),
    };
  } catch (_) {
    return {
      'uid': user.uid,
      'name': 'ولي الأمر',
      'username': cleanUsername,
    };
  }
}

Future<void> notifyAdminConsultationResponse({
  required String consultationId,
  required bool approved,
  required Map<String, dynamic> consultationData,
}) async {
  final parentInfo = await fetchCurrentParentInfo();

  final parentUid = (parentInfo['uid'] ?? '').trim();
  final parentUsername = (parentInfo['username'] ?? '').trim().toLowerCase();
  final parentName = (parentInfo['name'] ?? 'ولي الأمر').trim();

  final childName = (consultationData['childName'] ?? '').toString().trim();
  final title = (consultationData['title'] ?? 'استشارة').toString().trim();
  final totalAmount = consultationData['totalAmount'] ?? 0;

  final responseText = approved ? 'وافق' : 'رفض';

  await AppNotificationService.instance.notifyAdmin(
    title: approved ? 'تمت الموافقة على استشارة' : 'تم رفض استشارة',
    body:
        '$responseText ولي الأمر $parentName على الاستشارة "$title"${childName.isNotEmpty ? ' للطفل $childName' : ''}. المبلغ: ${formatMoney(totalAmount)} شيكل.',
    type: approved ? 'consultation_approved' : 'consultation_rejected',
    priority: approved ? 'normal' : 'important',
    parentUid: parentUid,
    parentUsername: parentUsername,
    parentName: parentName,
    childId: (consultationData['childId'] ?? '').toString(),
    childName: childName,
    section: (consultationData['section'] ?? 'Nursery').toString(),
    group: (consultationData['group'] ?? '').toString(),
    createdByUid: parentUid,
    createdByName: parentName,
    createdByRole: 'parent',
    extraData: {
      'consultationId': consultationId,
      'consultationStatus': approved ? 'scheduled' : 'cancelled',
      'parentApprovalStatus': approved ? 'approved' : 'rejected',
      'notificationType':
          approved ? 'consultation_approved' : 'consultation_rejected',
      'category': 'consultations',
      'screen': 'consultations',
      'route': 'admin_consultations',
      'relatedCollection': 'child_consultations',
      'relatedDocId': consultationId,
      'totalAmount': totalAmount,
      'hourlyPrice': consultationData['hourlyPrice'] ?? 50,
      'hours': consultationData['hours'] ?? 0,
    },
  );
}

  Future<void> respondToConsultation({
    required String consultationId,
    required bool approved,
  }) async {
    if (isUpdating) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final now = DateTime.now();
    final consultationRef =
    _firestore.collection('child_consultations').doc(consultationId);

    final consultationDoc = await consultationRef.get();
    final consultationData = consultationDoc.data() ?? <String, dynamic>{};

      await consultationRef.update({
  'parentApprovalStatus': approved ? 'approved' : 'rejected',
  'parentRespondedAt': Timestamp.fromDate(now),
  'consultationStatus': approved ? 'scheduled' : 'cancelled',
  'updatedAt': Timestamp.fromDate(now),
});

await notifyAdminConsultationResponse(
  consultationId: consultationId,
  approved: approved,
  consultationData: consultationData,
);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'تمت الموافقة على الاستشارة ✅'
                : 'تم رفض الاستشارة',
          ),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديث الاستشارة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> confirmResponse({
    required String consultationId,
    required bool approved,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(approved ? 'الموافقة على الاستشارة' : 'رفض الاستشارة'),
          content: Text(
            approved
                ? 'هل تريدين الموافقة على هذه الاستشارة؟ سيتم اعتمادها وترتيبها من الإدارة.'
                : 'هل تريدين رفض هذه الاستشارة؟ سيتم إبلاغ الإدارة بالرفض.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(approved ? 'موافقة' : 'رفض'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    await respondToConsultation(
      consultationId: consultationId,
      approved: approved,
    );
  }

  Widget statusFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DropdownButtonFormField<String>(
          value: selectedStatus,
          decoration: InputDecoration(
            labelText: 'فلترة حسب الحالة',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text('كل الاستشارات'),
            ),
            DropdownMenuItem(
              value: 'pending',
              child: Text('بانتظار موافقتي'),
            ),
            DropdownMenuItem(
              value: 'approved',
              child: Text('تمت الموافقة'),
            ),
            DropdownMenuItem(
              value: 'rejected',
              child: Text('مرفوضة'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedStatus = value ?? 'all';
            });
          },
        ),
      ),
    );
  }

  Widget emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد استشارات متاحة حاليًا.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget consultationCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final title = (data['title'] ?? 'استشارة').toString();
    final childName = (data['childName'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final typeLabel = (data['consultationTypeLabel'] ??
            data['consultationType'] ??
            'استشارة')
        .toString();

    final approval = (data['parentApprovalStatus'] ?? 'pending').toString();
    final consultationStatus =
        (data['consultationStatus'] ?? 'proposed').toString();

    final hours = data['hours'] ?? 0;
    final hourlyPrice = data['hourlyPrice'] ?? 50;
    final totalAmount = data['totalAmount'] ?? 0;
    final suggestedDate = data['suggestedDate'];

    final color = approvalColor(approval);
    final isPending = approval.trim().toLowerCase() == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'استشارة' : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (childName.trim().isNotEmpty)
                        Text(
                          'الطفل: $childName',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    approvalLabel(approval),
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
            _ConsultationInfoRow(
              icon: Icons.category_outlined,
              label: 'نوع الاستشارة',
              value: typeLabel,
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'التاريخ المقترح',
              value: formatDate(suggestedDate),
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.access_time_rounded,
              label: 'عدد الساعات',
              value: formatMoney(hours),
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.payments_outlined,
              label: 'سعر الساعة',
              value: '${formatMoney(hourlyPrice)} شيكل',
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.receipt_long_rounded,
              label: 'المبلغ الإجمالي',
              value: '${formatMoney(totalAmount)} شيكل',
              strong: true,
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.info_outline_rounded,
              label: 'حالة الاستشارة',
              value: consultationStatusLabel(consultationStatus),
            ),
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => confirmResponse(
                                consultationId: doc.id,
                                approved: false,
                              ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => confirmResponse(
                                consultationId: doc.id,
                                approved: true,
                              ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('موافقة'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الاستشارات',
      child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: fetchConsultations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data ?? [];
          final filteredDocs = applyFilter(docs);

          filteredDocs.sort((a, b) {
            final aCreated = a.data()['createdAt'];
            final bCreated = b.data()['createdAt'];

            final aTs = aCreated is Timestamp ? aCreated : null;
            final bTs = bCreated is Timestamp ? bCreated : null;

            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;

            return bTs.compareTo(aTs);
          });

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'استشارات الأطفال',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هنا يمكنك مراجعة الاستشارات المقترحة من الإدارة والموافقة عليها أو رفضها.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                ),
                const SizedBox(height: 16),
                statusFilterCard(),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  emptyState()
                else
                  ...filteredDocs.map(consultationCard),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConsultationInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  const _ConsultationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = strong ? AppColors.primary : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: strong ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: TextStyle(
                color: color,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

