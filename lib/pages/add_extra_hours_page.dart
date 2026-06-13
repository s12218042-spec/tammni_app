import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AddExtraHoursPage extends StatefulWidget {
  const AddExtraHoursPage({super.key});

  @override
  State<AddExtraHoursPage> createState() => _AddExtraHoursPageState();
}

class _AddExtraHoursPageState extends State<AddExtraHoursPage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final hoursCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  late Future<List<Map<String, dynamic>>> _childrenFuture;

  Map<String, dynamic>? selectedChild;
  DateTime selectedDate = DateTime.now();

  bool isLoading = false;

  static const double hourlyPrice = 10;

  @override
  void initState() {
    super.initState();
    _childrenFuture = fetchChildren();
  }

  double get hours {
    return double.tryParse(hoursCtrl.text.trim()) ?? 0;
  }

  double get totalAmount {
    return hours * hourlyPrice;
  }

  @override
  void dispose() {
    hoursCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  bool _isEligibleForExtraHours(Map<String, dynamic> data) {
    final status = _cleanText(data['status']).toLowerCase();
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();

    final childType = _cleanText(
      data['childType'] ??
          data['enrollmentType'] ??
          data['type'] ??
          data['childStatus'],
    ).toLowerCase();

    final enrollmentType =
        _cleanText(data['enrollmentType']).toLowerCase();

    final isActiveValue = data['isActive'];

    final isActive = isActiveValue == null
        ? status != 'inactive' &&
            status != 'withdrawn' &&
            status != 'archived' &&
            childStatus != 'rejected_after_trial' &&
            childStatus != 'trial_pending_decision' &&
            accountStatus != 'archived' &&
            accountStatus != 'pending_decision'
        : isActiveValue == true;

    final isTrial = childType == 'trial' ||
        enrollmentType == 'trial' ||
        childStatus == 'trial' ||
        childStatus == 'trial_pending_decision' ||
        data['isTrialChild'] == true;

    final isTemporary = childType == 'temporary' ||
        enrollmentType == 'temporary' ||
        childType == 'temp' ||
        childType == 'temporary_child' ||
        childType == 'مؤقت' ||
        childStatus == 'temporary' ||
        data['isTemporaryChild'] == true;

    final excludedFromMonthly = data['excludeFromMonthlyInvoice'] == true ||
        data['isBillable'] == false;

    return isActive &&
        !isTrial &&
        !isTemporary &&
        !excludedFromMonthly;
  }

  Map<String, dynamic> _mapChild(
    String childId,
    Map<String, dynamic> data,
  ) {
    final childType = _cleanText(
      data['childType'] ??
          data['enrollmentType'] ??
          data['type'] ??
          data['childStatus'],
    ).toLowerCase();

    final childStatus =
        _cleanText(data['childStatus'] ?? data['status']).toLowerCase();

    return {
      'id': childId,
      'name': (data['name'] ??
              data['childName'] ??
              data['fullName'] ??
              'طفل بدون اسم')
          .toString(),
      'parentUid': _cleanText(data['parentUid']),
      'parentUsername': _cleanText(data['parentUsername']),
      'parentName': _cleanText(data['parentName']),
      'group': _cleanText(data['groupName'] ?? data['group']),
      'section': _cleanText(data['section']).isEmpty
          ? 'Nursery'
          : _cleanText(data['section']),
      'childType': childType,
      'enrollmentType': _cleanText(data['enrollmentType']).toLowerCase(),
      'childStatus': childStatus,
      'isTrialChild': data['isTrialChild'] == true,
      'isTemporaryChild': data['isTemporaryChild'] == true,
      'excludeFromMonthlyInvoice':
          data['excludeFromMonthlyInvoice'] == true,
      'isBillable': data['isBillable'],
      'isActive': data['isActive'] == true,
    };
  }

  Future<List<Map<String, dynamic>>> fetchChildren() async {
    final snapshot = await _firestore.collection('children').get();

    final children = snapshot.docs
        .where((doc) => _isEligibleForExtraHours(doc.data()))
        .map((doc) => _mapChild(doc.id, doc.data()))
        .where((child) {
      final name = _cleanText(child['name']);
      return name.isNotEmpty;
    }).toList();

    children.sort(
      (a, b) => _cleanText(a['name']).compareTo(_cleanText(b['name'])),
    );

    return children;
  }

  void _reloadChildren({bool clearSelection = false}) {
    setState(() {
      if (clearSelection) {
        selectedChild = null;
      }

      _childrenFuture = fetchChildren();
    });
  }

  Future<Map<String, String>> getCurrentUserInfo() async {
    final user = _auth.currentUser;

    if (user == null) {
      return {'uid': '', 'name': 'مستخدم', 'role': ''};
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    return {
      'uid': user.uid,
      'name': (data['displayName'] ??
              data['name'] ??
              data['fullName'] ??
              data['username'] ??
              'مستخدم')
          .toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  Future<void> pickDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(today) ? today : selectedDate,
      firstDate: DateTime(2024),
      lastDate: today,
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });
  }

  String formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  bool _isFutureDate(DateTime value) {
    final today = DateTime.now();

    final selectedDay = DateTime(value.year, value.month, value.day);
    final currentDay = DateTime(today.year, today.month, today.day);

    return selectedDay.isAfter(currentDay);
  }

  Future<void> saveExtraHours() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedChild == null) {
      _showSnack('اختر الطفل أولًا');
      return;
    }

    if (hours <= 0) {
      _showSnack('عدد الساعات يجب أن يكون أكبر من صفر');
      return;
    }

    if (_isFutureDate(selectedDate)) {
      _showSnack('لا يمكن تسجيل ساعات إضافية بتاريخ مستقبلي');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = await getCurrentUserInfo();

      if (currentUser['role'] != 'admin') {
        _showSnack('فقط الأدمن يستطيع تسجيل الساعات الإضافية');
        return;
      }

      final selectedChildId = _cleanText(selectedChild!['id']);

      if (selectedChildId.isEmpty) {
        _showSnack('بيانات الطفل غير مكتملة');
        return;
      }

      final freshChildDoc =
          await _firestore.collection('children').doc(selectedChildId).get();

      if (!freshChildDoc.exists || freshChildDoc.data() == null) {
        _showSnack('لم يعد سجل الطفل موجودًا');
        _reloadChildren(clearSelection: true);
        return;
      }

      final freshChildData = freshChildDoc.data()!;

      if (!_isEligibleForExtraHours(freshChildData)) {
        _showSnack(
          'لا يمكن تسجيل ساعات إضافية لطفل تجربة أو طفل زائر قبل اعتماده رسميًا',
        );
        _reloadChildren(clearSelection: true);
        return;
      }

      final freshChild = _mapChild(freshChildDoc.id, freshChildData);

      final now = DateTime.now();
      final docRef = _firestore.collection('extra_child_hours').doc();

      await docRef.set({
        'id': docRef.id,
        'childId': freshChild['id'] ?? '',
        'childName': freshChild['name'] ?? '',
        'parentUid': freshChild['parentUid'] ?? '',
        'parentUsername': freshChild['parentUsername'] ?? '',
        'parentName': freshChild['parentName'] ?? '',
        'group': freshChild['group'] ?? '',
        'section': freshChild['section'] ?? 'Nursery',
        'childType': freshChild['childType'] ?? '',
        'enrollmentType': freshChild['enrollmentType'] ?? '',
        'childStatus': freshChild['childStatus'] ?? '',
        'isTrialChild': false,
        'isTemporaryChild': false,
        'isBillable': true,
        'excludeFromMonthlyInvoice': false,
        'date': Timestamp.fromDate(selectedDate),
        'hours': hours,
        'hourlyPrice': hourlyPrice,
        'totalAmount': totalAmount,
        'status': 'pending_invoice',
        'invoiceId': '',
        'notes': notesCtrl.text.trim(),
        'createdByUid': currentUser['uid'] ?? '',
        'createdByName': currentUser['name'] ?? '',
        'createdByRole': currentUser['role'] ?? '',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final parentUid = _cleanText(freshChild['parentUid']);
      final parentUsername =
          _cleanText(freshChild['parentUsername']).toLowerCase();
      final parentName = _cleanText(freshChild['parentName']);
      final childId = _cleanText(freshChild['id']);
      final childName = _cleanText(freshChild['name']);

      if (parentUid.isNotEmpty ||
          parentUsername.isNotEmpty ||
          childId.isNotEmpty) {
        try {
          await AppNotificationService.instance.notifyChildParent(
            parentUid: parentUid,
            parentUsername: parentUsername,
            parentName: parentName,
            title: 'تم تسجيل ساعات إضافية',
            body:
                'تم تسجيل ${hours.toStringAsFixed(2)} ساعة إضافية للطفل $childName بقيمة ${totalAmount.toStringAsFixed(0)} شيكل، وسيتم إضافتها إلى الفاتورة.',
            type: 'extra_hours',
            childId: childId,
            childName: childName,
            section: (freshChild['section'] ?? 'Nursery').toString(),
            group: (freshChild['group'] ?? '').toString(),
            priority: 'normal',
            createdByUid: currentUser['uid'] ?? '',
            createdByName: currentUser['name'] ?? 'الإدارة',
            createdByRole: currentUser['role'] ?? 'admin',
            extraData: {
              'extraHoursId': docRef.id,
              'hours': hours,
              'hourlyPrice': hourlyPrice,
              'totalAmount': totalAmount,
              'date': Timestamp.fromDate(selectedDate),
              'status': 'pending_invoice',
              'category': 'extra_hours',
              'notificationType': 'extra_hours',
              'screen': 'invoices',
              'route': 'parent_invoices',
              'relatedCollection': 'extra_child_hours',
            },
          );
        } catch (e) {
          debugPrint(
            'AddExtraHoursPage: فشل إرسال إشعار الساعات الإضافية: $e',
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الساعات الإضافية بنجاح ✅')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('حدث خطأ أثناء الحفظ: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textLight),
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

  String childLabel(Map<String, dynamic> child) {
    final group = _cleanText(child['group']);
    final parent = _cleanText(child['parentName']);

    return [
      child['name'] ?? 'طفل بدون اسم',
      group.isEmpty ? 'بدون مجموعة' : group,
      if (parent.isNotEmpty) parent,
    ].join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إضافة ساعات إضافية',
      child: Form(
        key: _formKey,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _childrenFuture,
          builder: (context, snapshot) {
            final children = snapshot.data ?? [];

            if (snapshot.hasData &&
                selectedChild != null &&
                !children.any(
                  (child) => child['id'] == selectedChild!['id'],
                )) {
              selectedChild = null;
            }

            return ListView(
              children: [
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختيار الطفل',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                      ),
                      const SizedBox(height: 14),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (children.isEmpty)
                        const Text(
                          'لا يوجد أطفال مسجلون رسميًا متاحون لإضافة ساعات إضافية.',
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedChild?['id']?.toString(),
                          isExpanded: true,
                          menuMaxHeight: 360,
                          decoration: customDecoration(
                            label: 'الطفل',
                            icon: Icons.child_care_rounded,
                          ),
                          items: children.map((child) {
                            return DropdownMenuItem<String>(
                              value: child['id'].toString(),
                              child: Text(
                                childLabel(child),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (context) {
                            return children.map((child) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  (child['name'] ?? 'طفل بدون اسم').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              );
                            }).toList();
                          },
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedChild = children.firstWhere(
                                (child) => child['id'].toString() == value,
                              );
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'اختر الطفل';
                            }

                            return null;
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تفاصيل الساعات',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: customDecoration(
                          label: 'عدد الساعات',
                          icon: Icons.access_time_rounded,
                          hint: 'مثال: 2',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final val = double.tryParse(value?.trim() ?? '');

                          if (val == null || val <= 0) {
                            return 'أدخل عدد ساعات صحيح';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: const Text('تاريخ الساعات الإضافية'),
                        subtitle: Text(formatDate(selectedDate)),
                        onTap: pickDate,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: customDecoration(
                          label: 'ملاحظات',
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
                              'سعر الساعة: ${hourlyPrice.toStringAsFixed(0)} شيكل\n'
                              'عدد الساعات: ${hours.toStringAsFixed(2)}\n'
                              'المجموع: ${totalAmount.toStringAsFixed(2)} شيكل',
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
                          onPressed: isLoading ? null : saveExtraHours,
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
                            isLoading
                                ? 'جارٍ الحفظ...'
                                : 'حفظ الساعات الإضافية',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
