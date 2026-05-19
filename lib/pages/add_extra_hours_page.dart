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

  Map<String, dynamic>? selectedChild;
  DateTime selectedDate = DateTime.now();

  bool isLoading = false;

  static const double hourlyPrice = 10;

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

  Future<List<Map<String, dynamic>>> fetchChildren() async {
    final snapshot = await _firestore.collection('children').get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      final status = (data['status'] ?? data['childStatus'] ?? '')
          .toString()
          .toLowerCase();

      final isActiveValue = data['isActive'];
      final isActive = isActiveValue == null
          ? status != 'inactive' &&
              status != 'withdrawn' &&
              status != 'rejected_after_trial'
          : isActiveValue == true;

      return {
        'id': doc.id,
        'name': (data['name'] ??
                data['childName'] ??
                data['fullName'] ??
                'طفل بدون اسم')
            .toString(),
        'parentUid': (data['parentUid'] ?? '').toString(),
        'parentUsername': (data['parentUsername'] ?? '').toString(),
        'parentName': (data['parentName'] ?? '').toString(),
        'group': (data['groupName'] ?? data['group'] ?? '').toString(),
        'section': (data['section'] ?? 'Nursery').toString(),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });
  }

  String formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveExtraHours() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedChild == null) {
      _showSnack('اختاري الطفل أولًا');
      return;
    }

    if (hours <= 0) {
      _showSnack('عدد الساعات يجب أن يكون أكبر من صفر');
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

      final now = DateTime.now();
      final docRef = _firestore.collection('extra_child_hours').doc();

      await docRef.set({
        'id': docRef.id,
        'childId': selectedChild!['id'] ?? '',
        'childName': selectedChild!['name'] ?? '',
        'parentUid': selectedChild!['parentUid'] ?? '',
        'parentUsername': selectedChild!['parentUsername'] ?? '',
        'parentName': selectedChild!['parentName'] ?? '',
        'group': selectedChild!['group'] ?? '',
        'section': selectedChild!['section'] ?? 'Nursery',
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

    final parentUid = (selectedChild!['parentUid'] ?? '').toString().trim();
final parentUsername =
    (selectedChild!['parentUsername'] ?? '').toString().trim().toLowerCase();
final parentName = (selectedChild!['parentName'] ?? '').toString().trim();
final childId = (selectedChild!['id'] ?? '').toString().trim();
final childName = (selectedChild!['name'] ?? '').toString().trim();

if (parentUid.isNotEmpty || parentUsername.isNotEmpty) {
  await AppNotificationService.instance.notifyParent(
    parentUid: parentUid,
    parentUsername: parentUsername,
    parentName: parentName,
    title: 'تم تسجيل ساعات إضافية',
    body:
        'تم تسجيل ${hours.toStringAsFixed(2)} ساعة إضافية للطفل $childName بقيمة ${totalAmount.toStringAsFixed(0)} شيكل، وسيتم إضافتها إلى الفاتورة.',
    type: 'extra_hours',
    childId: childId,
    childName: childName,
    section: selectedChild!['section'] ?? 'Nursery',
    group: selectedChild!['group'] ?? '',
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
    final group = (child['group'] ?? '').toString();
    final parent = (child['parentName'] ?? '').toString();

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
          future: fetchChildren(),
          builder: (context, snapshot) {
            final children = snapshot.data ?? [];

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
                        const Text('لا يوجد أطفال حاليًا.')
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
                            return 'أدخلي عدد ساعات صحيح';
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
