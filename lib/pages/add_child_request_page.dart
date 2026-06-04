import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../services/app_notification_service.dart';
import '../utils/child_section_utils.dart';
import '../widgets/app_page_scaffold.dart';

class AddChildRequestPage extends StatefulWidget {
  const AddChildRequestPage({super.key});

  @override
  State<AddChildRequestPage> createState() => _AddChildRequestPageState();
}

class _AddChildRequestPageState extends State<AddChildRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final childNameCtrl = TextEditingController();
  final childIdentityCtrl = TextEditingController();
  final birthDateCtrl = TextEditingController();
  final healthNotesCtrl = TextEditingController();

  String selectedGender = 'female';
  String resolvedSection = 'Nursery';
  bool isSubmitting = false;

  DateTime? selectedBirthDate;

  bool hasChronicDiseases = false;
  bool hasAllergies = false;
  bool takesMedications = false;
  bool hasDietaryRestrictions = false;
  bool hasSpecialNeeds = false;

  final chronicDiseasesCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final medicationsCtrl = TextEditingController();
  final dietaryRestrictionsCtrl = TextEditingController();
  final specialNeedsCtrl = TextEditingController();

  final List<_PickupContactDraft> pickupContacts = [_PickupContactDraft()];

  @override
  void dispose() {
    childNameCtrl.dispose();
    childIdentityCtrl.dispose();
    birthDateCtrl.dispose();
    healthNotesCtrl.dispose();
    chronicDiseasesCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    dietaryRestrictionsCtrl.dispose();
    specialNeedsCtrl.dispose();

    for (final pickup in pickupContacts) {
      pickup.dispose();
    }

    super.dispose();
  }

  InputDecoration customDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textLight),
      suffixIcon: suffixIcon,
    );
  }

  Widget buildSectionTitle(String title, String subtitle) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
    );
  }

  Widget buildMainCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  bool _isValidPalestinianIdChecksum(String id) {
    if (!RegExp(r'^\d{9}$').hasMatch(id)) return false;

    int sum = 0;

    for (int i = 0; i < id.length; i++) {
      final digit = int.parse(id[i]);
      final factor = i.isEven ? 1 : 2;
      int result = digit * factor;

      if (result > 9) {
        result -= 9;
      }

      sum += result;
    }

    return sum % 10 == 0;
  }

  String? _validatePalestinianId(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'رقم الهوية مطلوب';
    }

    if (!RegExp(r'^\d{9}$').hasMatch(clean)) {
      return 'رقم الهوية يجب أن يتكون من 9 أرقام';
    }

    if (RegExp(r'^(\d)\1{8}$').hasMatch(clean)) {
      return 'رقم الهوية غير صالح';
    }

    if (!_isValidPalestinianIdChecksum(clean)) {
      return 'رقم الهوية غير صالح';
    }

    return null;
  }

  bool _isValidPalestinianMobile(String value) {
    final clean = value.trim();
    return RegExp(r'^(059|056|052)\d{7}$').hasMatch(clean);
  }

  String? _validatePalestinianMobile(String value, {required String label}) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return '$label مطلوب';
    }

    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return '$label يجب أن يتكون من 10 أرقام';
    }

    if (RegExp(r'^(\d)\1{9}$').hasMatch(clean)) {
      return '$label غير صالح';
    }

    if (!_isValidPalestinianMobile(clean)) {
      return '$label يجب أن يكون رقم جوال صحيحًا يبدأ بـ 059 أو 056 أو 052';
    }

    return null;
  }


  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 4),
      firstDate: DateTime(2015),
      lastDate: now,
    );

    if (picked == null) return;

    final sectionResult = ChildSectionUtils.resolveSectionAndGroup(picked);

    setState(() {
      selectedBirthDate = picked;
      birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      resolvedSection = sectionResult.section;
    });
  }

  void addPickupContact() {
    setState(() {
      pickupContacts.add(_PickupContactDraft());
    });
  }

  void removePickupContact(int index) {
    if (pickupContacts.length == 1) return;

    setState(() {
      pickupContacts[index].dispose();
      pickupContacts.removeAt(index);
    });
  }

  Future<Map<String, dynamic>> _getParentInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();

    if (!userDoc.exists) {
      throw Exception('تعذر العثور على بيانات ولي الأمر');
    }

    final data = userDoc.data() ?? {};

    return {
      'uid': currentUser.uid,
      'name': (data['name'] ??
              data['displayName'] ??
              data['fullName'] ??
              data['username'] ??
              '')
          .toString()
          .trim(),
      'username': (data['username'] ?? '').toString().trim().toLowerCase(),
      'email': (data['email'] ?? '').toString().trim().toLowerCase(),
    };
  }

  Future<bool> _hasPendingDuplicateRequest({
    required String parentUid,
    required String childName,
    required DateTime birthDate,
  }) async {
    final snapshot = await _firestore
        .collection('add_child_requests')
        .where('parentUid', isEqualTo: parentUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final childInfo =
          (data['childInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final existingName =
          (childInfo['fullName'] ?? childInfo['name'] ?? '').toString().trim();
      final existingBirthDate = childInfo['birthDate'];

      DateTime? existingDate;

      if (existingBirthDate is Timestamp) {
        existingDate = existingBirthDate.toDate();
      } else if (existingBirthDate is String) {
        existingDate = DateTime.tryParse(existingBirthDate);
      }

      if (existingName == childName.trim() &&
          existingDate != null &&
          existingDate.year == birthDate.year &&
          existingDate.month == birthDate.month &&
          existingDate.day == birthDate.day) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _childAlreadyExists({
    required String parentUid,
    required String childName,
    required DateTime birthDate,
  }) async {
    final snapshot = await _firestore
        .collection('children')
        .where('parentUid', isEqualTo: parentUid)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final existingName =
          (data['fullName'] ?? data['name'] ?? '').toString().trim();
      final existingBirthDate = data['birthDate'];

      DateTime? existingDate;

      if (existingBirthDate is Timestamp) {
        existingDate = existingBirthDate.toDate();
      }

      if (existingName == childName.trim() &&
          existingDate != null &&
          existingDate.year == birthDate.year &&
          existingDate.month == birthDate.month &&
          existingDate.day == birthDate.day) {
        return true;
      }
    }

    return false;
  }

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedBirthDate == null) {
      _showSnack('اختاري تاريخ ميلاد الطفل');
      return;
    }

    final sectionResult =
        ChildSectionUtils.resolveSectionAndGroup(selectedBirthDate!);

    if (sectionResult.section != 'Nursery') {
      _showSnack('عمر الطفل خارج نطاق الحضانة في النظام الحالي');
      return;
    }

    for (final pickup in pickupContacts) {
      if (!pickup.isValid()) {
        _showSnack('تأكدي من تعبئة بيانات جميع المخولين بالاستلام');
        return;
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final parent = await _getParentInfo();

      final duplicatePending = await _hasPendingDuplicateRequest(
        parentUid: parent['uid'],
        childName: childNameCtrl.text.trim(),
        birthDate: selectedBirthDate!,
      );

      if (duplicatePending) {
        throw Exception('يوجد طلب إضافة طفل مشابه قيد المراجعة بالفعل');
      }

      final alreadyExists = await _childAlreadyExists(
        parentUid: parent['uid'],
        childName: childNameCtrl.text.trim(),
        birthDate: selectedBirthDate!,
      );

      if (alreadyExists) {
        throw Exception('هذا الطفل مرتبط بالفعل بحساب ولي الأمر');
      }

      final childFullName = childNameCtrl.text.trim();
      final now = FieldValue.serverTimestamp();

      final requestData = <String, dynamic>{
        'requestType': 'add_child',
        'status': 'pending',
        'parentUid': parent['uid'],
        'parentName': parent['name'],
        'parentUsername': parent['username'],
        'parentEmail': parent['email'],
        'childName': childFullName,
        'childInfo': {
          'fullName': childFullName,
          'name': childFullName,
          'identityNumber': childIdentityCtrl.text.trim(),
          'birthDate': Timestamp.fromDate(selectedBirthDate!),
          'gender': selectedGender,
          'section': 'Nursery',
          'group': '',
          'status': 'active',
          'hasChronicDiseases': hasChronicDiseases,
          'chronicDiseases':
              hasChronicDiseases ? chronicDiseasesCtrl.text.trim() : '',
          'hasAllergies': hasAllergies,
          'allergies': hasAllergies ? allergiesCtrl.text.trim() : '',
          'takesMedications': takesMedications,
          'medications': takesMedications ? medicationsCtrl.text.trim() : '',
          'hasDietaryRestrictions': hasDietaryRestrictions,
          'dietaryRestrictions':
              hasDietaryRestrictions ? dietaryRestrictionsCtrl.text.trim() : '',
          'hasSpecialNeeds': hasSpecialNeeds,
          'specialNeeds': hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
          'healthNotes': healthNotesCtrl.text.trim(),
          'bloodType': '',
          'dietInstructions':
              hasDietaryRestrictions ? dietaryRestrictionsCtrl.text.trim() : '',
          'specialInstructions':
              hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
          'authorizedPickupContacts':
              pickupContacts.map((e) => e.toMap()).toList(),
        },
        'reviewNote': '',
        'reviewedByUid': '',
        'reviewedByName': '',
        'reviewedAt': null,
        'createdAt': now,
        'updatedAt': now,
      };

      final requestRef =
          await _firestore.collection('add_child_requests').add(requestData);

      await AppNotificationService.instance.notifyAdmin(
  title: 'طلب إضافة طفل جديد',
  body:
      'أرسل ولي الأمر ${parent['name']} طلب إضافة الطفل $childFullName ويحتاج مراجعة الإدارة.',
  type: 'add_child_request',
  priority: 'important',
  parentUid: parent['uid'],
  parentUsername: parent['username'],
  parentName: parent['name'],
  childId: '',
  childName: childFullName,
  section: 'Nursery',
  group: '',
  createdByUid: parent['uid'],
  createdByName: parent['name'],
  createdByRole: 'parent',
  extraData: {
    'notificationType': 'add_child_request',
    'category': 'requests',
    'requestType': 'add_child',
    'requestId': requestRef.id,
    'status': 'pending',
    'importance': 'important',
    'parentEmail': parent['email'],
    'senderUid': parent['uid'],
    'senderName': parent['name'],
    'senderRole': 'parent',
    'screen': 'add_child_requests',
    'route': 'admin_add_child_requests',
    'relatedCollection': 'add_child_requests',
  },
);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب إضافة الطفل بنجاح وسيتم مراجعته من الإدارة',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
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

  Widget buildChildSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'بيانات الطفل',
            'أدخلي بيانات الطفل الأساسية.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: childNameCtrl,
            decoration: customDecoration(
              label: 'الاسم الكامل للطفل',
              icon: Icons.child_care_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'أدخلي اسم الطفل';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: childIdentityCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: customDecoration(
              label: 'رقم هوية الطفل',
              icon: Icons.badge_outlined,
            ),
            validator: (value) => _validatePalestinianId(value ?? ''),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: birthDateCtrl,
            readOnly: true,
            onTap: _pickBirthDate,
            decoration: customDecoration(
              label: 'تاريخ الميلاد',
              icon: Icons.calendar_month_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'اختاري تاريخ الميلاد';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedGender,
            decoration: customDecoration(
              label: 'الجنس',
              icon: Icons.wc_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'female', child: Text('أنثى')),
              DropdownMenuItem(value: 'male', child: Text('ذكر')),
            ],
            onChanged: (value) {
              setState(() {
                selectedGender = value ?? 'female';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildHealthSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'البيانات الصحية',
            'المعلومات الصحية المهمة الخاصة بالطفل.',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: hasChronicDiseases,
            onChanged: (value) {
              setState(() {
                hasChronicDiseases = value;
                if (!value) chronicDiseasesCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل أمراض مزمنة؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasChronicDiseases) ...[
            TextFormField(
              controller: chronicDiseasesCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الأمراض المزمنة',
                icon: Icons.monitor_heart_outlined,
              ),
              validator: (value) {
                if (hasChronicDiseases && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الأمراض المزمنة';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: hasAllergies,
            onChanged: (value) {
              setState(() {
                hasAllergies = value;
                if (!value) allergiesCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل حساسية؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasAllergies) ...[
            TextFormField(
              controller: allergiesCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الحساسية',
                icon: Icons.warning_amber_rounded,
              ),
              validator: (value) {
                if (hasAllergies && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الحساسية';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: takesMedications,
            onChanged: (value) {
              setState(() {
                takesMedications = value;
                if (!value) medicationsCtrl.clear();
              });
            },
            title: const Text('هل يتناول الطفل أدوية بشكل مستمر؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (takesMedications) ...[
            TextFormField(
              controller: medicationsCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الأدوية',
                icon: Icons.medication_outlined,
              ),
              validator: (value) {
                if (takesMedications && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الأدوية';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: hasDietaryRestrictions,
            onChanged: (value) {
              setState(() {
                hasDietaryRestrictions = value;
                if (!value) dietaryRestrictionsCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل قيود غذائية؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasDietaryRestrictions) ...[
            TextFormField(
              controller: dietaryRestrictionsCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل القيود الغذائية',
                icon: Icons.restaurant_menu_rounded,
              ),
              validator: (value) {
                if (hasDietaryRestrictions && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل القيود الغذائية';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: hasSpecialNeeds,
            onChanged: (value) {
              setState(() {
                hasSpecialNeeds = value;
                if (!value) specialNeedsCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل احتياجات خاصة؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasSpecialNeeds) ...[
            TextFormField(
              controller: specialNeedsCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الاحتياجات الخاصة',
                icon: Icons.accessible_rounded,
              ),
              validator: (value) {
                if (hasSpecialNeeds && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الاحتياجات الخاصة';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: healthNotesCtrl,
            maxLines: 3,
            decoration: customDecoration(
              label: 'ملاحظات صحية عامة',
              icon: Icons.health_and_safety_rounded,
              hint: 'اختياري',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPickupSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'المخولون بالاستلام',
            'أضيفي الأشخاص المخولين باستلام الطفل.',
          ),
          const SizedBox(height: 10),
          ...List.generate(pickupContacts.length, (index) {
            final pickup = pickupContacts[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الشخص ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (pickupContacts.length > 1)
                        IconButton(
                          onPressed: () => removePickupContact(index),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.redAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: pickup.nameCtrl,
                    decoration: customDecoration(
                      label: 'الاسم',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'أدخلي الاسم';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pickup.relationCtrl,
                    decoration: customDecoration(
                      label: 'صلة القرابة',
                      icon: Icons.family_restroom_rounded,
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'أدخلي صلة القرابة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pickup.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: customDecoration(
                      label: 'رقم الجوال',
                      icon: Icons.phone_rounded,
                    ),
                    validator: (value) {
                      final clean = (value ?? '').trim();

                      if (clean.isEmpty) {
                        return 'أدخلي رقم الجوال';
                      }

                      return _validatePalestinianMobile(
                        clean,
                        label: 'رقم الجوال',
                      );
                    },
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: addPickupContact,
              icon: const Icon(Icons.add),
              label: const Text('إضافة شخص مخوّل آخر'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubmitSection() {
    final isOutOfRange = resolvedSection == 'OutOfRange';

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (isSubmitting || isOutOfRange) ? null : submitRequest,
        icon: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.3),
              )
            : const Icon(Icons.send_rounded),
        label: Text(
          isSubmitting ? 'جارٍ إرسال الطلب...' : 'إرسال طلب إضافة الطفل',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'طلب إضافة طفل',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          children: [
            buildChildSection(),
            const SizedBox(height: 14),
            buildHealthSection(),
            const SizedBox(height: 14),
            buildPickupSection(),
            const SizedBox(height: 18),
            buildSubmitSection(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PickupContactDraft {
  final nameCtrl = TextEditingController();
  final relationCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  bool isValid() {
    final phone = phoneCtrl.text.trim();
    final isValidPhone = RegExp(r'^(059|056|052)\d{7}$').hasMatch(phone);

    return nameCtrl.text.trim().isNotEmpty &&
        relationCtrl.text.trim().isNotEmpty &&
        phone.isNotEmpty &&
        isValidPhone;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameCtrl.text.trim(),
      'relation': relationCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
    };
  }

  void dispose() {
    nameCtrl.dispose();
    relationCtrl.dispose();
    phoneCtrl.dispose();
  }
}