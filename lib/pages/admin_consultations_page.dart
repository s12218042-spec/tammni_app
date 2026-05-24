import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminConsultationsPage extends StatefulWidget {
  const AdminConsultationsPage({super.key});

  @override
  State<AdminConsultationsPage> createState() => _AdminConsultationsPageState();
}

class _AdminConsultationsPageState extends State<AdminConsultationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final hoursCtrl = TextEditingController(text: '1');
  final hourlyPriceCtrl = TextEditingController(text: '50');
  final notesCtrl = TextEditingController();

  Map<String, dynamic>? selectedChild;
  String selectedConsultationType = 'behavioral';
  DateTime suggestedDate = DateTime.now();

  bool isLoading = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    descriptionCtrl.dispose();
    hoursCtrl.dispose();
    hourlyPriceCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get hours => _numValue(hoursCtrl.text.trim());
  double get hourlyPrice => _numValue(hourlyPriceCtrl.text.trim());
  double get totalAmount => hours * hourlyPrice;

  String formatMoney(dynamic value) {
    final val = _numValue(value);
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  String consultationTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'behavioral':
        return 'استشارة سلوكية';
      case 'speech':
        return 'استشارة نطق ولغة';
      case 'educational':
        return 'استشارة تربوية';
      case 'health':
        return 'استشارة صحية';
      case 'family':
        return 'استشارة أسرية';
      case 'other':
        return 'أخرى';
      default:
        return type.trim().isEmpty ? 'غير محدد' : type;
    }
  }

String childTypeLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'temporary':
    case 'temp':
    case 'temporary_child':
    case 'مؤقت':
      return 'طفل مؤقت';
    case 'trial':
    case 'تجربة':
      return 'طفل تجربة';
    case 'permanent':
    case 'regular':
    case 'active':
    case 'دائم':
      return 'طفل دائم';
    default:
      return 'طفل دائم';
  }
}

  String formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> pickSuggestedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: suggestedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      suggestedDate = picked;
    });
  }

  Future<Map<String, String>> getCurrentAdminInfo() async {
    final user = _auth.currentUser;

    if (user == null) {
      return {
        'uid': '',
        'name': 'الإدارة',
        'role': '',
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
                'الإدارة')
            .toString()
            .trim(),
        'role': (data['role'] ?? '').toString().trim(),
      };
    } catch (_) {
      return {
        'uid': user.uid,
        'name': 'الإدارة',
        'role': '',
      };
    }
  }

Future<List<Map<String, dynamic>>> fetchChildren() async {
  final snapshot = await _firestore.collection('children').get();

  final children = snapshot.docs.map((doc) {
    final data = doc.data();

    final status = (data['status'] ?? data['childStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final childTypeRaw = (data['childType'] ??
            data['enrollmentType'] ??
            data['type'] ??
            data['childStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final isTrial = childTypeRaw == 'trial' ||
        status == 'trial' ||
        data['isTrialChild'] == true;

    final isTemporary = childTypeRaw == 'temporary' ||
        childTypeRaw == 'temp' ||
        childTypeRaw == 'temporary_child' ||
        childTypeRaw == 'مؤقت' ||
        status == 'temporary' ||
        data['isTemporaryChild'] == true;

    final normalizedChildType = isTrial
        ? 'trial'
        : isTemporary
            ? 'temporary'
            : 'permanent';

    final isActiveValue = data['isActive'];

    final isActive = isActiveValue == null
        ? status != 'inactive' &&
            status != 'withdrawn' &&
            status != 'rejected_after_trial' &&
            status != 'archived'
        : isActiveValue == true;

    return {
      'id': doc.id,
      'name': (data['name'] ??
              data['childName'] ??
              data['fullName'] ??
              'طفل بدون اسم')
          .toString()
          .trim(),
      'parentUid': (data['parentUid'] ?? '').toString().trim(),
      'parentUsername':
          (data['parentUsername'] ?? '').toString().trim().toLowerCase(),
      'parentName': (data['parentName'] ?? '').toString().trim(),
      'group': (data['groupName'] ?? data['group'] ?? '').toString().trim(),
      'groupId': (data['groupId'] ?? '').toString().trim(),
      'section': (data['section'] ?? 'Nursery').toString().trim(),
      'childType': normalizedChildType,
      'childTypeLabel': childTypeLabel(normalizedChildType),
      'childStatus': status,
      'isTemporary': isTemporary,
      'isTemporaryChild': isTemporary,
      'isTrialChild': isTrial,
      'isBillable': data['isBillable'],
      'excludeFromMonthlyInvoice': data['excludeFromMonthlyInvoice'] == true,
      'isActive': isActive,
    };
  }).where((child) {
    final name = (child['name'] ?? '').toString().trim();
    return name.isNotEmpty && child['isActive'] == true;
  }).toList();

  children.sort(
    (a, b) => (a['name'] as String).compareTo(b['name'] as String),
  );

  return children;
}

  String childLabel(Map<String, dynamic> child) {
    final name = (child['name'] ?? 'طفل بدون اسم').toString();
    final group = (child['group'] ?? '').toString();
    final parent = (child['parentName'] ?? '').toString();
    final type = (child['childTypeLabel'] ?? '').toString();

    return [
      name,
      if (type.isNotEmpty) type,
      group.isEmpty ? 'بدون مجموعة' : group,
      if (parent.isNotEmpty) parent,
    ].join(' • ');
  }

  Future<void> createConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedChild == null) {
      _showSnack('اختاري الطفل أولًا');
      return;
    }

    if (hours <= 0) {
      _showSnack('عدد الساعات يجب أن يكون أكبر من صفر');
      return;
    }

    if (hourlyPrice <= 0) {
      _showSnack('سعر الساعة يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final adminInfo = await getCurrentAdminInfo();

      if ((adminInfo['role'] ?? '').trim().toLowerCase() != 'admin') {
        _showSnack('فقط الأدمن يستطيع إنشاء استشارة');
        return;
      }

      final now = DateTime.now();
      final docRef = _firestore.collection('child_consultations').doc();

      final title = titleCtrl.text.trim().isEmpty
          ? consultationTypeLabel(selectedConsultationType)
          : titleCtrl.text.trim();

      final parentUid = (selectedChild!['parentUid'] ?? '').toString().trim();
      final parentUsername =
          (selectedChild!['parentUsername'] ?? '').toString().trim().toLowerCase();
      final parentName =
          (selectedChild!['parentName'] ?? '').toString().trim();
      final childId = (selectedChild!['id'] ?? '').toString().trim();
      final childName = (selectedChild!['name'] ?? '').toString().trim();
      final childType = (selectedChild!['childType'] ?? '').toString().trim();
      final childStatus = (selectedChild!['childStatus'] ?? '').toString().trim();
      final childTypeLabelValue =
         (selectedChild!['childTypeLabel'] ?? '').toString().trim();

      final isTemporaryChild = selectedChild!['isTemporaryChild'] == true ||
         selectedChild!['isTemporary'] == true ||
         childType == 'temporary';

      final isTrialChild =
         selectedChild!['isTrialChild'] == true || childType == 'trial';

      final isBillableChild = selectedChild!['isBillable'] == null
        ? true
        : selectedChild!['isBillable'] == true;

      final excludeFromMonthlyInvoice =
         selectedChild!['excludeFromMonthlyInvoice'] == true || isTrialChild;

      final effectiveHourlyPrice = isTrialChild ? 0.0 : hourlyPrice;
      final effectiveTotalAmount = isTrialChild ? 0.0 : totalAmount;

      await docRef.set({
        'id': docRef.id,
        'consultationId': docRef.id,

        'title': title,
        'description': descriptionCtrl.text.trim(),
        'consultationType': selectedConsultationType,
        'consultationTypeLabel': consultationTypeLabel(selectedConsultationType),

        'childId': childId,
        'childName': childName,
        'childType': childType,
        'childTypeLabel': childTypeLabelValue,
        'childStatus': childStatus,
        'isTemporaryChild': isTemporaryChild,
        'isTrialChild': isTrialChild,
        'isBillableChild': isBillableChild,
        'excludeFromMonthlyInvoice': excludeFromMonthlyInvoice,

        'parentUid': parentUid,
        'parentUsername': parentUsername,
        'parentName': parentName,

        'group': selectedChild!['group'] ?? '',
        'groupId': selectedChild!['groupId'] ?? '',
        'section': selectedChild!['section'] ?? 'Nursery',

        'suggestedDate': Timestamp.fromDate(suggestedDate),
        'hours': hours,
        'hourlyPrice': effectiveHourlyPrice,
        'totalAmount': effectiveTotalAmount,

        'parentApprovalStatus': 'pending',
        'consultationStatus': 'proposed',

        'billable': false,
        'invoiceStatus': 'pending_approval',
        'billingStatus': 'pending_approval',
        'addedToInvoice': false,
        'invoiceId': '',
        'invoiceMonth': '',

        'notes': notesCtrl.text.trim(),

        'createdByUid': adminInfo['uid'] ?? '',
        'createdByName': adminInfo['name'] ?? 'الإدارة',
        'createdByRole': 'admin',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      try {
        if (parentUid.isNotEmpty || parentUsername.isNotEmpty || childId.isNotEmpty) {
          await AppNotificationService.instance.notifyChildParent(
          parentUid: parentUid,
          parentUsername: parentUsername,
          parentName: parentName,
          title: 'استشارة جديدة بانتظار الموافقة',
          body:
              isTrialChild
            ? 'تم اقتراح ${consultationTypeLabel(selectedConsultationType)} للطفل $childName مجانًا خلال فترة التجربة.'
            : 'تم اقتراح ${consultationTypeLabel(selectedConsultationType)} للطفل $childName بقيمة ${formatMoney(effectiveTotalAmount)} شيكل.',
          type: 'consultation',
          childId: childId,
          childName: childName,
          section: selectedChild!['section'] ?? 'Nursery',
          group: selectedChild!['group'] ?? '',
          priority: 'normal',
          createdByUid: adminInfo['uid'] ?? '',
          createdByName: adminInfo['name'] ?? 'الإدارة',
          createdByRole: 'admin',
          extraData: {
            'consultationId': docRef.id,
            'consultationType': selectedConsultationType,
            'consultationTypeLabel':
                consultationTypeLabel(selectedConsultationType),
            'suggestedDate': Timestamp.fromDate(suggestedDate),
            'hours': hours,
            'hourlyPrice': effectiveHourlyPrice,
            'totalAmount': effectiveTotalAmount,
            'parentApprovalStatus': 'pending',
            'consultationStatus': 'proposed',
            'invoiceStatus': 'pending_approval',
            'billable': false,
            'childType': childType,
            'childStatus': childStatus,
            'isTemporaryChild': isTemporaryChild,
            'isTrialChild': isTrialChild,
            'isBillableChild': isBillableChild,
            'excludeFromMonthlyInvoice': excludeFromMonthlyInvoice,
            'category': 'consultations',
            'notificationType': 'consultation',
            'screen': 'consultations',
            'route': 'parent_consultations',
            'relatedCollection': 'child_consultations',
            'relatedDocId': docRef.id,
          },
        );
        
        }
      } catch (e) {
        debugPrint('AdminConsultationsPage: فشل إرسال إشعار الاستشارة: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الاستشارة بنجاح')),
      );

      setState(() {
        selectedChild = null;
        selectedConsultationType = 'behavioral';
        suggestedDate = DateTime.now();
        titleCtrl.clear();
        descriptionCtrl.clear();
        hoursCtrl.text = '1';
        hourlyPriceCtrl.text = '50';
        notesCtrl.clear();
      });
    } catch (e) {
      _showSnack('حدث خطأ أثناء إنشاء الاستشارة: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> markConsultationCompleted(String consultationId) async {
  try {
    final now = DateTime.now();

    final ref = _firestore.collection('child_consultations').doc(consultationId);
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};

    final isTrialChild = data['isTrialChild'] == true;
    final isBillableChild = data['isBillableChild'] == true;

    final shouldBill = !isTrialChild && isBillableChild;

    await ref.update({
      'consultationStatus': 'completed',
      'invoiceStatus': shouldBill ? 'ready_for_invoice' : 'not_billed',
      'billingStatus': shouldBill ? 'ready_for_invoice' : 'not_billed',
      'billable': shouldBill,
      'addedToInvoice': false,
      'completedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldBill
              ? 'تم اعتماد الجلسة كمكتملة وجاهزة للفوترة'
              : 'تم اعتماد الجلسة كمكتملة بدون فوترة',
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('حدث خطأ أثناء تحديث الجلسة: $e'),
      ),
    );
  }
}

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration customDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget mainCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
    );
  }

  Widget consultationsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('child_consultations')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return mainCard(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return mainCard(
            child: Text('حدث خطأ أثناء تحميل الاستشارات: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return mainCard(
            child: const Text('لا توجد استشارات حاليًا'),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();

            final title = (data['title'] ?? 'استشارة').toString();
            final childName = (data['childName'] ?? '').toString();
            final parentName = (data['parentName'] ?? '').toString();
            final childType =
                (data['childTypeLabel'] ?? childTypeLabel(data['childType'] ?? ''))
                    .toString();

            final approval =
                (data['parentApprovalStatus'] ?? 'pending').toString();
            final status =
                (data['consultationStatus'] ?? 'proposed').toString();
            final invoiceStatus =
                (data['invoiceStatus'] ?? 'pending_approval').toString();

            final total = _numValue(data['totalAmount']);

            final isApproved = approval.trim().toLowerCase() == 'approved';
            final isRejected = approval.trim().toLowerCase() == 'rejected';
            final isCompleted = status.trim().toLowerCase() == 'completed';
            final isInvoiced =
                invoiceStatus.trim().toLowerCase() == 'invoiced' ||
                    invoiceStatus.trim().toLowerCase() == 'added_to_invoice';

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
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(
                            Icons.psychology_alt_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Text(
                          '${formatMoney(total)} شيكل',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (childName.isNotEmpty) Text('الطفل: $childName'),
                    if (childType.isNotEmpty) Text('نوع الطفل: $childType'),
                    if (parentName.isNotEmpty) Text('ولي الأمر: $parentName'),
                    const SizedBox(height: 6),
                    Text('موافقة ولي الأمر: ${_approvalLabel(approval)}'),
                    Text('حالة الاستشارة: ${_consultationStatusLabel(status)}'),
                    Text('حالة الفاتورة: ${_invoiceStatusLabel(invoiceStatus)}'),
                    if (isRejected) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.18),
                          ),
                        ),
                        child: const Text(
                          'تم رفض الاستشارة من ولي الأمر',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (isCompleted) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.20),
                          ),
                        ),
                        child: Text(
                          isInvoiced
                              ? 'تم تنفيذ الجلسة وتم ربطها بفاتورة'
                              : 'تم تنفيذ الجلسة وهي جاهزة للإضافة على الفاتورة',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (isApproved && !isCompleted) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('تم تنفيذ الجلسة'),
                          onPressed: () => markConsultationCompleted(doc.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _approvalLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'approved':
        return 'موافق';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'بانتظار الموافقة';
    }
  }

  String _consultationStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      case 'scheduled':
        return 'مجدولة';
      case 'proposed':
      default:
        return 'مقترحة';
    }
  }

  String _invoiceStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'invoiced':
      case 'added_to_invoice':
        return 'تمت إضافتها لفاتورة';
      case 'ready_for_invoice':
        return 'جاهزة للفوترة';
      case 'pending_invoice':
        return 'بانتظار الفوترة';
      case 'pending_approval':
        return 'بانتظار موافقة ولي الأمر';
      case 'not_billed':
        return 'غير مفوترة';
      default:
        return 'بانتظار الفوترة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الاستشارات',
      child: Form(
        key: _formKey,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchChildren(),
          builder: (context, snapshot) {
            final children = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('اقتراح استشارة'),
                      const SizedBox(height: 14),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (children.isEmpty)
                        const Text('لا يوجد أطفال حاليًا')
                      else
                        DropdownButtonFormField<String>(
                          value: selectedChild?['id'],
                          decoration: customDecoration(
                            label: 'الطفل',
                            icon: Icons.child_care_rounded,
                          ),
                          items: children.map((child) {
                            return DropdownMenuItem<String>(
                              value: child['id'] as String,
                              child: Text(childLabel(child)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedChild = children.firstWhere(
                                (child) => child['id'] == value,
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'اختاري الطفل';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedConsultationType,
                        decoration: customDecoration(
                          label: 'نوع الاستشارة',
                          icon: Icons.psychology_alt_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'behavioral',
                            child: Text('استشارة سلوكية'),
                          ),
                          DropdownMenuItem(
                            value: 'speech',
                            child: Text('استشارة نطق ولغة'),
                          ),
                          DropdownMenuItem(
                            value: 'educational',
                            child: Text('استشارة تربوية'),
                          ),
                          DropdownMenuItem(
                            value: 'health',
                            child: Text('استشارة صحية'),
                          ),
                          DropdownMenuItem(
                            value: 'family',
                            child: Text('استشارة أسرية'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('أخرى'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedConsultationType = value ?? 'behavioral';
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: customDecoration(
                          label: 'عنوان الاستشارة',
                          icon: Icons.title_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: customDecoration(
                          label: 'الوصف',
                          icon: Icons.description_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('التكلفة والموعد'),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: customDecoration(
                          label: 'عدد الساعات',
                          icon: Icons.access_time_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final val = _numValue(value);
                          if (val <= 0) return 'أدخلي عدد ساعات صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: hourlyPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: customDecoration(
                          label: 'سعر الساعة',
                          icon: Icons.payments_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final val = _numValue(value);
                          if (val <= 0) return 'أدخلي سعر صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: const Text('تاريخ مقترح'),
                        subtitle: Text(formatDate(suggestedDate)),
                        onTap: pickSuggestedDate,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: customDecoration(
                          label: 'ملاحظات داخلية',
                          icon: Icons.notes_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calculate_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'عدد الساعات: ${formatMoney(hours)}\n'
                              'سعر الساعة: ${formatMoney(hourlyPrice)} شيكل\n'
                              'الإجمالي: ${formatMoney(totalAmount)} شيكل',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : createConsultation,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            isLoading ? 'جارٍ الحفظ...' : 'إنشاء الاستشارة',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                sectionTitle('آخر الاستشارات'),
                const SizedBox(height: 12),
                consultationsList(),
              ],
            );
          },
        ),
      ),
    );
  }
}