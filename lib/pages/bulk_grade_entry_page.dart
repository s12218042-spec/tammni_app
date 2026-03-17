import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class BulkGradeEntryPage extends StatefulWidget {
  const BulkGradeEntryPage({super.key});

  @override
  State<BulkGradeEntryPage> createState() => _BulkGradeEntryPageState();
}

class _BulkGradeEntryPageState extends State<BulkGradeEntryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _totalCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  List<ChildModel> children = [];
  final Map<String, TextEditingController> gradeControllers = {};

  final List<String> subjects = [
    'العربية',
    'الإنجليزية',
    'الرياضيات',
    'النشاط',
    'العلوم',
  ];

  final List<String> gradeTypes = [
    'امتحان',
    'يومي',
    'مشاركة',
    'واجب',
    'نشاط',
  ];

  String? selectedSubject;
  String? selectedType;

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

  @override
  void initState() {
    super.initState();
    loadChildren();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _noteCtrl.dispose();
    for (final controller in gradeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<String>> fetchAssignedGroups() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();

    if (!userDoc.exists) return [];

    final data = userDoc.data() ?? {};
    final rawGroups = data['assignedGroups'];

    if (rawGroups is List) {
      return rawGroups
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> loadChildren() async {
    try {
      final assignedGroups = await fetchAssignedGroups();

      if (assignedGroups.isEmpty) {
        if (!mounted) return;
        setState(() {
          children = [];
          isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('children')
          .where('section', isEqualTo: 'Kindergarten')
          .where('isActive', isEqualTo: true)
          .get();

      final loadedChildren = snapshot.docs.map((doc) {
        final data = doc.data();

        return ChildModel(
          id: doc.id,
          name: data['name'] ?? '',
          section: data['section'] ?? 'Kindergarten',
          group: data['group'] ?? '',
          parentName: data['parentName'] ?? '',
          parentUsername: data['parentUsername'] ?? '',
          birthDate: data['birthDate'] is Timestamp
              ? (data['birthDate'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).where((child) {
        return assignedGroups.contains(child.group.trim());
      }).toList();

      loadedChildren.sort((a, b) => a.name.compareTo(b.name));

      gradeControllers.clear();
      for (final child in loadedChildren) {
        gradeControllers[child.id] = TextEditingController();
      }

      if (!mounted) return;
      setState(() {
        children = loadedChildren;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveBulkGrades() async {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد أطفال لإدخال الدرجات')),
      );
      return;
    }

    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المادة')),
      );
      return;
    }

    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نوع التقييم')),
      );
      return;
    }

    if (_totalCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الدرجة الكلية')),
      );
      return;
    }

    final totalValue = double.tryParse(_totalCtrl.text.trim());
    if (totalValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الدرجة الكلية غير صحيحة')),
      );
      return;
    }

    final validEntries = children.where((child) {
      final text = gradeControllers[child.id]?.text.trim() ?? '';
      return text.isNotEmpty;
    }).toList();

    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخلي درجة لطفل واحد على الأقل')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      final batch = _firestore.batch();

      for (final child in validEntries) {
        final gradeText = gradeControllers[child.id]!.text.trim();
        final gradeValue = double.tryParse(gradeText);

        if (gradeValue == null) continue;

        final docRef = _firestore.collection('grades').doc();

        batch.set(docRef, {
          'childId': child.id,
          'childName': child.name,
          'parentUsername': child.parentUsername,
          'section': child.section,
          'group': child.group,
          'subject': selectedSubject,
          'type': selectedType,
          'grade': gradeValue,
          'total': totalValue,
          'note': _noteCtrl.text.trim(),
          'createdAt': Timestamp.now(),
          'time': FieldValue.serverTimestamp(),
          'byRole': userInfo['role'],
          'createdByUid': userInfo['uid'],
          'createdByName': userInfo['name'],
          'createdByRole': userInfo['role'],
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الدرجات الجماعية بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الدرجات: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدخال درجات جماعي',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildSubjectDropdown(),
                const SizedBox(height: 14),
                _buildTypeDropdown(),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _totalCtrl,
                  label: 'الدرجة الكلية',
                  hint: 'مثال: 10',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _noteCtrl,
                  label: 'ملاحظة عامة',
                  hint: 'أدخلي ملاحظة عامة إن وجدت',
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                Text(
                  'إدخال الدرجات للأطفال',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 12),
                if (children.isEmpty)
                  _buildEmptyState()
                else
                  ...children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BulkGradeCard(
                        childName: child.name,
                        group: child.group,
                        controller: gradeControllers[child.id]!,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : saveBulkGrades,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الدرجات'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدخال درجات جماعي',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'اختاري المادة ونوع التقييم ثم أدخلي درجات أطفال مجموعاتك دفعة واحدة.',
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

  Widget _buildSubjectDropdown() {
    return _FieldCard(
      child: DropdownButtonFormField<String>(
        value: selectedSubject,
        decoration: const InputDecoration(
          labelText: 'المادة',
          border: InputBorder.none,
        ),
        items: subjects.map((subject) {
          return DropdownMenuItem<String>(
            value: subject,
            child: Text(subject),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedSubject = value;
          });
        },
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return _FieldCard(
      child: DropdownButtonFormField<String>(
        value: selectedType,
        decoration: const InputDecoration(
          labelText: 'نوع التقييم',
          border: InputBorder.none,
        ),
        items: gradeTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedType = value;
          });
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return _FieldCard(
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
        ),
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
            Icons.inbox_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد أطفال مخصصون لهذه المعلمة حالياً',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند ربط المعلمة بمجموعاتها سيظهر الأطفال هنا لإدخال الدرجات.',
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

class _FieldCard extends StatelessWidget {
  final Widget child;

  const _FieldCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BulkGradeCard extends StatelessWidget {
  final String childName;
  final String group;
  final TextEditingController controller;

  const _BulkGradeCard({
    required this.childName,
    required this.group,
    required this.controller,
  });

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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.isEmpty ? 'بدون مجموعة' : group,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'درجة الطفل',
              hintText: 'مثال: 8',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}