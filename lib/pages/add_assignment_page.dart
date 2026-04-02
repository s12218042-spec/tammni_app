import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AddAssignmentPage extends StatefulWidget {
  const AddAssignmentPage({super.key});

  @override
  State<AddAssignmentPage> createState() => _AddAssignmentPageState();
}

class _AddAssignmentPageState extends State<AddAssignmentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _dueDateCtrl = TextEditingController();

  bool isLoading = false;

  List<ChildModel> children = [];
  List<String> groups = [];

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

  final List<String> subjects = [
    'العربية',
    'الإنجليزية',
    'الرياضيات',
    'النشاط',
    'العلوم',
  ];

  String? selectedSubject;
  String? selectedGroup;
  DateTime? selectedDueDate;

  @override
  void initState() {
    super.initState();
    loadChildrenAndGroups();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _noteCtrl.dispose();
    _dueDateCtrl.dispose();
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

  Future<void> loadChildrenAndGroups() async {
    final assignedGroups = await fetchAssignedGroups();

    if (assignedGroups.isEmpty) {
      if (!mounted) return;
      setState(() {
        children = [];
        groups = [];
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
  return ChildModel.fromMap(data, docId: doc.id);
}).where((child) {
  return assignedGroups.contains(child.group.trim());
}).toList();

    final extractedGroups = loadedChildren
        .map((child) => child.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (!mounted) return;
    setState(() {
      children = loadedChildren;
      groups = extractedGroups;
    });
  }

  Future<void> pickDueDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );

    if (picked != null) {
      setState(() {
        selectedDueDate = picked;
        _dueDateCtrl.text = '${picked.year}/${picked.month}/${picked.day}';
      });
    }
  }

  Future<void> saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المادة')),
      );
      return;
    }

    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المجموعة')),
      );
      return;
    }

    if (selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار موعد التسليم')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      await _firestore.collection('assignments').add({
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'subject': selectedSubject,
        'group': selectedGroup,
        'section': 'Kindergarten',
        'status': 'نشط',
        'dueDate': Timestamp.fromDate(selectedDueDate!),
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الواجب بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الواجب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إضافة واجب',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _titleCtrl,
              label: 'عنوان الواجب',
              hint: 'مثال: كتابة الحروف من أ إلى د',
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _descriptionCtrl,
              label: 'وصف الواجب',
              hint: 'أدخلي وصف الواجب بالتفصيل',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _buildSubjectDropdown(),
            const SizedBox(height: 14),
            _buildGroupDropdown(),
            const SizedBox(height: 14),
            _buildDueDateField(),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _noteCtrl,
              label: 'ملاحظة',
              hint: 'أدخلي ملاحظة إضافية إن وجدت',
              maxLines: 3,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : saveAssignment,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isLoading ? 'جاري الحفظ...' : 'حفظ الواجب'),
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
            'إضافة واجب جديد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'أضيفي واجب جديد مع المادة والمجموعة وموعد التسليم.',
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
        validator: (value) {
          if (value == null || value.isEmpty) return 'يرجى اختيار المادة';
          return null;
        },
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return _FieldCard(
      child: DropdownButtonFormField<String>(
        value: selectedGroup,
        decoration: const InputDecoration(
          labelText: 'المجموعة',
          border: InputBorder.none,
        ),
        items: groups.map((group) {
          return DropdownMenuItem<String>(
            value: group,
            child: Text(group),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedGroup = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) return 'يرجى اختيار المجموعة';
          return null;
        },
      ),
    );
  }

  Widget _buildDueDateField() {
    return _FieldCard(
      child: TextFormField(
        controller: _dueDateCtrl,
        readOnly: true,
        onTap: pickDueDate,
        decoration: const InputDecoration(
          labelText: 'موعد التسليم',
          hintText: 'اختاري التاريخ',
          border: InputBorder.none,
          suffixIcon: Icon(Icons.calendar_month_outlined),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'يرجى اختيار موعد التسليم';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return _FieldCard(
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
        ),
        validator: (value) {
          if (label == 'ملاحظة') return null;
          if (value == null || value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
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