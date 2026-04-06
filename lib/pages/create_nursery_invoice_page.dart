import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class CreateNurseryInvoicePage extends StatefulWidget {
  const CreateNurseryInvoicePage({super.key});

  @override
  State<CreateNurseryInvoicePage> createState() =>
      _CreateNurseryInvoicePageState();
}

class _CreateNurseryInvoicePageState extends State<CreateNurseryInvoicePage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final titleCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  final baseAmountCtrl = TextEditingController();
  final transportFeeCtrl = TextEditingController();
  final mealsFeeCtrl = TextEditingController();
  final registrationFeeCtrl = TextEditingController();
  final lateFeeCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedBillingType = 'monthly';
  Map<String, dynamic>? selectedChild;

  DateTime? startDate;
  DateTime? endDate;
  DateTime? dueDate;

  bool isLoading = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    descriptionCtrl.dispose();
    baseAmountCtrl.dispose();
    transportFeeCtrl.dispose();
    mealsFeeCtrl.dispose();
    registrationFeeCtrl.dispose();
    lateFeeCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  bool get isRegistrationInvoice => selectedBillingType == 'registration';
  bool get isLateFeeInvoice => selectedBillingType == 'late_fee';

  String get invoiceCategory {
    switch (selectedBillingType) {
      case 'registration':
        return 'registration_fee';
      case 'late_fee':
        return 'late_fee';
      default:
        return 'nursery_fee';
    }
  }

  double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double get baseAmount => _parseAmount(baseAmountCtrl);
  double get transportFee => _parseAmount(transportFeeCtrl);
  double get mealsFee => _parseAmount(mealsFeeCtrl);
  double get registrationFee => _parseAmount(registrationFeeCtrl);
  double get lateFee => _parseAmount(lateFeeCtrl);

  double get totalAmount {
    return baseAmount + transportFee + mealsFee + registrationFee + lateFee;
  }

  Future<List<Map<String, dynamic>>> fetchNurseryChildren() async {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Nursery')
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': (data['name'] ?? '').toString(),
        'section': (data['section'] ?? 'Nursery').toString(),
        'group': (data['group'] ?? '').toString(),
        'parentName': (data['parentName'] ?? '').toString(),
        'parentUsername': (data['parentUsername'] ?? '').toString(),
        'parentUid': (data['parentUid'] ?? '').toString(),
        'isActive': (data['isActive'] ?? true) == true,
      };
    }).toList();

    children.sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      ),
    );

    return children;
  }

  Future<void> pickDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;
    onPicked(picked);
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'uid': '', 'name': 'مستخدم', 'role': ''};
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      return {
        'uid': user.uid,
        'name':
            (data['displayName'] ??
                    data['name'] ??
                    data['fullName'] ??
                    data['username'] ??
                    'مستخدم')
                .toString(),
        'role': (data['role'] ?? '').toString(),
      };
    } catch (_) {
      return {'uid': user.uid, 'name': 'مستخدم', 'role': ''};
    }
  }

  Future<void> saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedChild == null) {
      _showSnack('اختاري الطفل أولًا');
      return;
    }

    if (dueDate == null) {
      _showSnack('حددي تاريخ الاستحقاق');
      return;
    }

    if (!isRegistrationInvoice && !isLateFeeInvoice) {
      if (startDate == null || endDate == null) {
        _showSnack('حددي تاريخ البداية والنهاية');
        return;
      }

      if (endDate!.isBefore(startDate!)) {
        _showSnack('تاريخ النهاية يجب أن يكون بعد تاريخ البداية');
        return;
      }
    }

    if (totalAmount <= 0) {
      _showSnack('المبلغ الإجمالي يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = await getCurrentUserInfo();

      if (currentUser['role'] != 'admin') {
        _showSnack('فقط الأدمن يستطيع إنشاء الفواتير');
        return;
      }

      final now = DateTime.now();
      final docRef = _firestore.collection('invoices').doc();

      await docRef.set({
        'id': docRef.id,
        'childId': selectedChild!['id'] ?? '',
        'childName': selectedChild!['name'] ?? '',
        'parentName': selectedChild!['parentName'] ?? '',
        'parentUsername': selectedChild!['parentUsername'] ?? '',
        'parentUid': selectedChild!['parentUid'] ?? '',
        'section': selectedChild!['section'] ?? 'Nursery',
        'group': selectedChild!['group'] ?? '',
        'invoiceCategory': invoiceCategory,
        'billingType': selectedBillingType,
        'title': titleCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
        'dueDate': Timestamp.fromDate(dueDate!),
        'paidAt': null,
        'baseAmount': baseAmount,
        'transportFee': transportFee,
        'mealsFee': mealsFee,
        'registrationFee': registrationFee,
        'lateFee': lateFee,
        'totalAmount': totalAmount,
        'status': 'pending',
        'paymentMethod': '',
        'notes': notesCtrl.text.trim(),
        'createdByUid': currentUser['uid'] ?? '',
        'createdByName': currentUser['name'] ?? 'مستخدم',
        'createdByRole': currentUser['role'] ?? '',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الفاتورة بنجاح ✅')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('حدث خطأ أثناء حفظ الفاتورة: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Widget sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget mainCard({required Widget child}) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إنشاء فاتورة حضانة',
      child: Form(
        key: _formKey,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchNurseryChildren(),
          builder: (context, snapshot) {
            final children = snapshot.data ?? [];

            return ListView(
              children: [
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        'اختيار الطفل',
                        'اختاري الطفل الذي سيتم إنشاء الفاتورة له من طرف الأدمن.',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedChild?['id'],
                        decoration: customDecoration(
                          label: 'الطفل',
                          icon: Icons.child_care_rounded,
                        ),
                        items: children.map((child) {
                          final group = (child['group'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: child['id'] as String,
                            child: Text(
                              '${child['name']} • ${group.isEmpty ? 'بدون مجموعة' : group}',
                            ),
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
                      if (selectedChild != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ولي الأمر: ${(selectedChild!['parentName'] ?? '').toString().isEmpty ? 'غير محدد' : selectedChild!['parentName']}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'اسم المستخدم: ${(selectedChild!['parentUsername'] ?? '').toString().isEmpty ? 'غير محدد' : selectedChild!['parentUsername']}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'المجموعة: ${(selectedChild!['group'] ?? '').toString().isEmpty ? 'غير محدد' : selectedChild!['group']}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        'نوع الفاتورة',
                        'اختاري نوع الرسوم المناسبة.',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedBillingType,
                        decoration: customDecoration(
                          label: 'نوع الفاتورة',
                          icon: Icons.receipt_long_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('يومي')),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('أسبوعي'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('شهري'),
                          ),
                          DropdownMenuItem(
                            value: 'registration',
                            child: Text('رسوم تسجيل'),
                          ),
                          DropdownMenuItem(
                            value: 'late_fee',
                            child: Text('رسوم تأخير'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedBillingType = value ?? 'monthly';

                            baseAmountCtrl.clear();
                            transportFeeCtrl.clear();
                            mealsFeeCtrl.clear();
                            registrationFeeCtrl.clear();
                            lateFeeCtrl.clear();

                            if (isRegistrationInvoice || isLateFeeInvoice) {
                              startDate = null;
                              endDate = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: customDecoration(
                          label: 'عنوان الفاتورة',
                          icon: Icons.title_rounded,
                          hint: 'مثال: رسوم حضانة شهرية',
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'أدخلي عنوان الفاتورة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: customDecoration(
                          label: 'وصف الفاتورة',
                          icon: Icons.description_outlined,
                          hint: 'تفاصيل إضافية عن الفاتورة',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!isRegistrationInvoice && !isLateFeeInvoice)
                  mainCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionTitle(
                          'فترة الفاتورة',
                          'حددي تاريخ البداية والنهاية.',
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_rounded),
                          title: const Text('تاريخ البداية'),
                          subtitle: Text(formatDate(startDate)),
                          onTap: () => pickDate(
                            initialDate: startDate,
                            onPicked: (date) {
                              setState(() {
                                startDate = date;
                              });
                            },
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded),
                          title: const Text('تاريخ النهاية'),
                          subtitle: Text(formatDate(endDate)),
                          onTap: () => pickDate(
                            initialDate: endDate,
                            onPicked: (date) {
                              setState(() {
                                endDate = date;
                              });
                            },
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
                      sectionTitle(
                        'تفاصيل الرسوم',
                        'أدخلي الرسوم المطلوبة حسب نوع الفاتورة.',
                      ),
                      const SizedBox(height: 14),
                      if (!isRegistrationInvoice && !isLateFeeInvoice) ...[
                        TextFormField(
                          controller: baseAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'الرسوم الأساسية',
                            icon: Icons.payments_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: transportFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم المواصلات',
                            icon: Icons.directions_bus_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: mealsFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم الوجبات',
                            icon: Icons.restaurant_outlined,
                          ),
                        ),
                      ],
                      if (isRegistrationInvoice)
                        TextFormField(
                          controller: registrationFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم التسجيل',
                            icon: Icons.app_registration_rounded,
                          ),
                        ),
                      if (isLateFeeInvoice)
                        TextFormField(
                          controller: lateFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم التأخير',
                            icon: Icons.warning_amber_rounded,
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
                      sectionTitle(
                        'الاستحقاق والملاحظات',
                        'حددي موعد الدفع وأضيفي أي ملاحظات.',
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('تاريخ الاستحقاق'),
                        subtitle: Text(formatDate(dueDate)),
                        onTap: () => pickDate(
                          initialDate: dueDate,
                          onPicked: (date) {
                            setState(() {
                              dueDate = date;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 4,
                        decoration: customDecoration(
                          label: 'ملاحظات',
                          icon: Icons.notes_rounded,
                          hint: 'أي تفاصيل إضافية...',
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
                              'الإجمالي النهائي: ${totalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium
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
                          onPressed: isLoading ? null : saveInvoice,
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
                            isLoading ? 'جارٍ حفظ الفاتورة...' : 'حفظ الفاتورة',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }
}
