import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ChildHandoffLogPage extends StatefulWidget {
  final ChildModel child;

  const ChildHandoffLogPage({
    super.key,
    required this.child,
  });

  @override
  State<ChildHandoffLogPage> createState() => _ChildHandoffLogPageState();
}

class _ChildHandoffLogPageState extends State<ChildHandoffLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController personNameCtrl = TextEditingController();
  final TextEditingController relationCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  String handoffType = 'dropoff'; // dropoff / pickup
  bool isSaving = false;

  @override
  void dispose() {
    personNameCtrl.dispose();
    relationCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {'uid': '', 'name': 'مستخدم', 'role': ''};
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

  Future<void> saveHandoff() async {
    if (personNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي اسم الشخص')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();

      await _firestore.collection('child_handoffs').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'section': widget.child.section,
        'group': widget.child.group,
        'handoffType': handoffType,
        'personName': personNameCtrl.text.trim(),
        'relation': relationCtrl.text.trim(),
        'note': noteCtrl.text.trim(),
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ سجل التسليم/الاستلام')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  String formatDateTime(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final d = rawTime.toDate();
      return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تسليم واستلام الطفل',
      child: Column(
        children: [
          Container(
            width: double.infinity,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجل تسليم واستلام ${widget.child.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'توثيق الشخص الذي سلّم الطفل أو استلمه من الحضانة.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: handoffType,
                    decoration: const InputDecoration(
                      labelText: 'نوع العملية',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'dropoff',
                        child: Text('تسليم للحضانة'),
                      ),
                      DropdownMenuItem(
                        value: 'pickup',
                        child: Text('استلام من الحضانة'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        handoffType = value ?? 'dropoff';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: personNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الشخص',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: relationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'صلة القرابة أو الصفة',
                      hintText: 'أم / أب / جد / سائق / قريب',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveHandoff,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ السجل'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('child_handoffs')
                  .where('childId', isEqualTo: widget.child.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد سجل تسليم/استلام بعد'),
                  );
                }

                final items = docs
                    .map((e) => e.data() as Map<String, dynamic>)
                    .toList();
                items.sort((a, b) {
                  final aTime =
                      (a['time'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
                  final bTime =
                      (b['time'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isDropoff = item['handoffType'] == 'dropoff';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDropoff ? 'تسليم للحضانة' : 'استلام من الحضانة',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isDropoff
                                    ? AppColors.success
                                    : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الاسم: ${item['personName'] ?? ''}',
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'الصفة: ${item['relation'] ?? ''}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                              ),
                            ),
                            Text(
                              'الوقت: ${formatDateTime(item['time'] ?? item['createdAt'])}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                              ),
                            ),
                            if ((item['note'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'ملاحظة: ${item['note']}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}