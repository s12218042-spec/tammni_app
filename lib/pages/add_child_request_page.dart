import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
  final groupCtrl = TextEditingController();
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
    groupCtrl.dispose();
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
        ),
      ],
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

  String? _validatePalestinianId(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'رقم الهوية مطلوب';
    }

    if (!RegExp(r'^\d{9}$').hasMatch(clean)) {
      return 'رقم الهوية يجب أن يتكون من 9 أرقام';
    }

    return null;
  }

  bool _isValidPalestinianMobile(String value) {
    final clean = value.trim();
    return RegExp(r'^(059|056)\d{7}$').hasMatch(clean);
  }

  String? _validatePalestinianMobile(String value, {required String label}) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return '$label مطلوب';
    }

    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return '$label يجب أن يتكون من 10 أرقام';
    }

    if (!_isValidPalestinianMobile(clean)) {
      return '$label يجب أن يكون رقم جوال فلسطيني صحيحًا (059 أو 056)';
    }

    return null;
  }

  Color _sectionColor(String section) {
    switch (section) {
      case 'Nursery':
        return const Color(0xFFEFA7C8);
      case 'Kindergarten':
        return const Color(0xFF7BB6FF);
      case 'OutOfRange':
      default:
        return Colors.redAccent;
    }
  }

  Widget _buildSectionBadge(String section) {
    final color = _sectionColor(section);
    final label = ChildSectionUtils.sectionArabicLabel(section);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
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

      if (!ChildSectionUtils.shouldShowGroupField(resolvedSection)) {
        groupCtrl.clear();
      }
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

    if (sectionResult.section == 'OutOfRange') {
      _showSnack('عمر الطفل أكبر من نطاق الحضانة/الروضة في النظام الحالي');
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

      final requestData = <String, dynamic>{
        'requestType': 'add_child',
        'status': 'pending',
        'parentUid': parent['uid'],
        'parentName': parent['name'],
        'parentUsername': parent['username'],
        'parentEmail': parent['email'],
        'childInfo': {
          'fullName': childNameCtrl.text.trim(),
          'identityNumber': childIdentityCtrl.text.trim(),
          'birthDate': Timestamp.fromDate(selectedBirthDate!),
          'gender': selectedGender,
          'section': sectionResult.section,
          'group': ChildSectionUtils.shouldShowGroupField(sectionResult.section)
              ? groupCtrl.text.trim()
              : '',
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('add_child_requests').add(requestData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب إضافة الطفل بنجاح وسيتم مراجعته من الإدارة'),
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

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب إضافة طفل جديد',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'املئي بيانات الطفل بدقة، ثم أرسلي الطلب ليتم مراجعته من الإدارة قبل إضافته إلى الحساب.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذا الطلب لا يضيف الطفل مباشرة. بعد مراجعة الإدارة والموافقة عليه، سيتم إنشاء سجل الطفل وربطه بحساب ولي الأمر.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionStatusCard() {
    final color = _sectionColor(resolvedSection);
    final isOutOfRange = resolvedSection == 'OutOfRange';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.14),
            child: Icon(
              isOutOfRange ? Icons.warning_amber_rounded : Icons.apartment_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'القسم المتوقع',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                _buildSectionBadge(resolvedSection),
              ],
            ),
          ),
        ],
      ),
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
          _buildSectionStatusCard(),
          if (resolvedSection == 'OutOfRange') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عمر الطفل أكبر من نطاق الحضانة/الروضة في النظام الحالي، لذلك لا يمكن إرسال الطلب بهذه البيانات.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          if (ChildSectionUtils.shouldShowGroupField(resolvedSection)) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: groupCtrl,
              decoration: customDecoration(
                label: 'المجموعة / الصف',
                icon: Icons.groups_rounded,
                hint: 'مثال: KG1',
              ),
              validator: (value) {
                if (ChildSectionUtils.shouldShowGroupField(resolvedSection) &&
                    (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي المجموعة / الصف';
                }
                return null;
              },
            ),
          ],
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
                  const SizedBox(height: 6),
                  Text(
                    'سيُعتمد هذا الشخص ضمن قائمة المسموح لهم باستلام الطفل بعد الموافقة على الطلب.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textLight,
                          height: 1.35,
                        ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isOutOfRange
                    ? Colors.red.withOpacity(0.12)
                    : AppColors.primary.withOpacity(0.12),
                child: Icon(
                  isOutOfRange
                      ? Icons.warning_amber_rounded
                      : Icons.assignment_turned_in_rounded,
                  color: isOutOfRange ? Colors.redAccent : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOutOfRange
                      ? 'لا يمكن إرسال الطلب لأن عمر الطفل خارج نطاق النظام الحالي'
                      : 'سيتم إرسال الطلب إلى الإدارة لمراجعته قبل إضافة الطفل إلى الحساب',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
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
          ),
        ],
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
            buildHeaderCard(),
            const SizedBox(height: 16),
            buildInfoCard(),
            const SizedBox(height: 18),
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
    final isValidPhone = RegExp(r'^(059|056)\d{7}$').hasMatch(phone);

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