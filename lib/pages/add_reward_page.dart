import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AddRewardPage extends StatefulWidget {
  const AddRewardPage({super.key});

  @override
  State<AddRewardPage> createState() => _AddRewardPageState();
}

class _AddRewardPageState extends State<AddRewardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool isLoading = false;

  List<ChildModel> children = [];
  ChildModel? selectedChild;

  final List<String> rewardTypes = [
    'نجمة',
    'شارة',
    'تشجيع',
    'إنجاز',
  ];

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
    _titleCtrl.dispose();
    _noteCtrl.dispose();
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
    final assignedGroups = await fetchAssignedGroups();

    if (assignedGroups.isEmpty) {
      if (!mounted) return;
      setState(() {
        children = [];
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
    loadedChildren.sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
    setState(() {
      children = loadedChildren;
    });
  }

  Future<void> saveReward() async {
    

    if (!_formKey.currentState!.validate()) return;

    if (selectedChild == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الطفل')),
      );
      return;
    }

    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نوع التعزيز')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      await _firestore.collection('rewards').add({
        'childId': selectedChild!.id,
        'childName': selectedChild!.name,
        'parentUsername': selectedChild!.parentUsername,
        'section': selectedChild!.section,
        'group': selectedChild!.group,
        'title': _titleCtrl.text.trim(),
        'type': selectedType,
        'note': _noteCtrl.text.trim(),
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعزيز بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ التعزيز: $e')),
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
      title: 'إضافة تعزيز',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildChildDropdown(),
            const SizedBox(height: 14),
            _buildTypeDropdown(),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _titleCtrl,
              label: 'عنوان التعزيز',
              hint: 'مثال: نجمة للتعاون داخل الصف',
            ),
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
                onPressed: isLoading ? null : saveReward,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isLoading ? 'جاري الحفظ...' : 'حفظ التعزيز'),
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
            'إضافة تعزيز جديد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'أضيفي نجمة أو شارة أو عبارة تشجيعية إيجابية للطفل.',
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

  Widget _buildChildDropdown() {
    return _FieldCard(
      child: DropdownButtonFormField<ChildModel>(
        value: selectedChild,
        decoration: const InputDecoration(
          labelText: 'الطفل',
          border: InputBorder.none,
        ),
        items: children.map((child) {
          return DropdownMenuItem<ChildModel>(
            value: child,
            child: Text(
              child.group.isEmpty
                  ? child.name
                  : '${child.name} - ${child.group}',
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedChild = value;
          });
        },
        validator: (value) {
          if (value == null) return 'يرجى اختيار الطفل';
          return null;
        },
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return _FieldCard(
      child: DropdownButtonFormField<String>(
        value: selectedType,
        decoration: const InputDecoration(
          labelText: 'نوع التعزيز',
          border: InputBorder.none,
        ),
        items: rewardTypes.map((type) {
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يرجى اختيار نوع التعزيز';
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