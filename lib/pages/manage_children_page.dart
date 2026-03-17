import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ManageChildrenPage extends StatefulWidget {
  const ManageChildrenPage({super.key});

  @override
  State<ManageChildrenPage> createState() => _ManageChildrenPageState();
}

class _ManageChildrenPageState extends State<ManageChildrenPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedView = 'active'; // active / archived / all

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  Color sectionColor(String section) {
    if (section == 'Nursery') return const Color(0xFFEFA7C8);
    if (section == 'Kindergarten') return const Color(0xFF7BB6FF);
    return AppColors.primary;
  }

  Future<List<Map<String, dynamic>>> fetchChildren() async {
    final snapshot = await _firestore.collection('children').get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'section': data['section'] ?? 'Nursery',
        'group': data['group'] ?? '',
        'parentName': data['parentName'] ?? '',
        'parentUsername': data['parentUsername'] ?? '',
        'parentUid': data['parentUid'] ?? '',
        'birthDate': data['birthDate'],
        'isActive': data['isActive'] ?? true,
        'status': data['status'] ?? 'active',
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'history': (data['history'] as List?) ?? [],
      };
    }).toList();

    final filtered = items.where((child) {
      final isActive = child['isActive'] == true;

      if (selectedView == 'active') return isActive;
      if (selectedView == 'archived') return !isActive;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return filtered;
  }

  String formatBirthDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  Future<void> showChildForm({
    Map<String, dynamic>? child,
  }) async {
    final nameCtrl = TextEditingController(text: child?['name'] ?? '');
    final parentNameCtrl =
        TextEditingController(text: child?['parentName'] ?? '');
    final parentUsernameCtrl =
        TextEditingController(text: child?['parentUsername'] ?? '');
    final groupCtrl = TextEditingController(text: child?['group'] ?? '');

    String selectedSection = child?['section'] ?? 'Nursery';
    DateTime selectedBirthDate = child?['birthDate'] is Timestamp
        ? (child!['birthDate'] as Timestamp).toDate()
        : DateTime(2023, 1, 1);

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(child == null ? 'إضافة طفل جديد' : 'تعديل بيانات الطفل'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الطفل',
                            prefixIcon: Icon(Icons.child_care_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'اكتب اسم الطفل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: parentNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم ولي الأمر',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'اكتب اسم ولي الأمر';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: parentUsernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم مستخدم ولي الأمر',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'اكتب اسم مستخدم ولي الأمر';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedSection,
                          decoration: const InputDecoration(
                            labelText: 'القسم الحالي',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Nursery',
                              child: Text('حضانة'),
                            ),
                            DropdownMenuItem(
                              value: 'Kindergarten',
                              child: Text('روضة'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() {
                              selectedSection = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: groupCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المجموعة / الصف',
                            prefixIcon: Icon(Icons.groups_2_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'اكتب اسم المجموعة أو الصف';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedBirthDate,
                              firstDate: DateTime(2018),
                              lastDate: DateTime.now(),
                            );

                            if (picked != null) {
                              setLocalState(() {
                                selectedBirthDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ الميلاد',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              '${selectedBirthDate.year}/${selectedBirthDate.month}/${selectedBirthDate.day}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final nowTs = Timestamp.now();

                    final cleanName = nameCtrl.text.trim();
                    final cleanParentName = parentNameCtrl.text.trim();
                    final cleanParentUsername =
                        parentUsernameCtrl.text.trim().toLowerCase();
                    final cleanGroup = groupCtrl.text.trim();

                    final parentQuery = await _firestore
                        .collection('users')
                        .where('username', isEqualTo: cleanParentUsername)
                        .limit(1)
                        .get();

                    if (parentQuery.docs.isEmpty) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لم يتم العثور على حساب ولي الأمر بهذا الاسم'),
                        ),
                      );
                      return;
                    }

                    final parentData = parentQuery.docs.first.data();
                    final parentUid = parentData['uid'] ?? parentQuery.docs.first.id;

                    if (child == null) {
                      await _firestore.collection('children').add({
                        'name': cleanName,
                        'section': selectedSection,
                        'group': cleanGroup,
                        'parentName': cleanParentName,
                        'parentUsername': cleanParentUsername,
                        'parentUid': parentUid,
                        'birthDate': Timestamp.fromDate(selectedBirthDate),
                        'isActive': true,
                        'status': 'active',
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'history': [
                          {
                            'section': selectedSection,
                            'group': cleanGroup,
                            'from': nowTs,
                            'to': null,
                          }
                        ],
                      });
                    } else {
                      final oldSection = (child['section'] ?? '').toString();
                      final oldGroup = (child['group'] ?? '').toString();
                      final oldHistory = List<Map<String, dynamic>>.from(
                        (child['history'] as List?) ?? [],
                      );

                      List<Map<String, dynamic>> newHistory = oldHistory;

                      final sectionChanged = oldSection != selectedSection;
                      final groupChanged = oldGroup != cleanGroup;

                      if (sectionChanged || groupChanged) {
                        newHistory = oldHistory.map((item) {
                          final updated = Map<String, dynamic>.from(item);
                          if (updated['to'] == null) {
                            updated['to'] = nowTs;
                          }
                          return updated;
                        }).toList();

                        newHistory.add({
                          'section': selectedSection,
                          'group': cleanGroup,
                          'from': nowTs,
                          'to': null,
                        });
                      }

                      await _firestore
                          .collection('children')
                          .doc(child['id'])
                          .update({
                        'name': cleanName,
                        'section': selectedSection,
                        'group': cleanGroup,
                        'parentName': cleanParentName,
                        'parentUsername': cleanParentUsername,
                        'parentUid': parentUid,
                        'birthDate': Timestamp.fromDate(selectedBirthDate),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'history': newHistory,
                      });
                    }

                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    setState(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          child == null
                              ? 'تمت إضافة الطفل بنجاح'
                              : 'تم تحديث بيانات الطفل بنجاح',
                        ),
                      ),
                    );
                  },
                  child: Text(child == null ? 'إضافة' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> archiveChild(Map<String, dynamic> child) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('أرشفة الطفل'),
            content: Text(
              'هل تريد أرشفة الطفل "${child['name']}"؟\n\nلن يتم حذفه من قاعدة البيانات، لكن سيختفي من الأطفال النشطين.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('أرشفة'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await _firestore.collection('children').doc(child['id']).update({
      'isActive': false,
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت أرشفة الطفل')),
    );
  }

  Future<void> restoreChild(Map<String, dynamic> child) async {
    await _firestore.collection('children').doc(child['id']).update({
      'isActive': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت استعادة الطفل إلى القائمة النشطة')),
    );
  }

  Widget buildTopFilter({
    required String label,
    required String value,
  }) {
    final isSelected = selectedView == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedView = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.14),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChildCard(Map<String, dynamic> child) {
    final name = (child['name'] ?? '').toString();
    final section = (child['section'] ?? '').toString();
    final group = (child['group'] ?? '').toString();
    final parentName = (child['parentName'] ?? '').toString();
    final parentUsername = (child['parentUsername'] ?? '').toString();
    final parentUid = (child['parentUid'] ?? '').toString();
    final isActive = child['isActive'] == true;
    final color = sectionColor(section);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  name.isEmpty ? 'ط' : name.substring(0, 1),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'بدون اسم' : name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sectionLabel(section)} • $group',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  isActive ? 'نشط' : 'مؤرشف',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.person_outline, 'ولي الأمر', parentName),
          const SizedBox(height: 8),
          _infoRow(Icons.alternate_email, 'اسم المستخدم', parentUsername),
          const SizedBox(height: 8),
          _infoRow(Icons.badge_outlined, 'Parent UID', parentUid),
          const SizedBox(height: 8),
          _infoRow(
            Icons.calendar_today_outlined,
            'تاريخ الميلاد',
            formatBirthDate(child['birthDate']),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showChildForm(child: child),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isActive) {
                      archiveChild(child);
                    } else {
                      restoreChild(child);
                    }
                  },
                  icon: Icon(
                    isActive
                        ? Icons.archive_outlined
                        : Icons.restore_outlined,
                  ),
                  label: Text(isActive ? 'أرشفة' : 'استعادة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
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
      title: 'إدارة الأطفال',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'إضافة طفل',
          onPressed: () => showChildForm(),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              buildTopFilter(label: 'النشطون', value: 'active'),
              const SizedBox(width: 10),
              buildTopFilter(label: 'المؤرشفون', value: 'archived'),
              const SizedBox(width: 10),
              buildTopFilter(label: 'الكل', value: 'all'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchChildren(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل الأطفال',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final children = snapshot.data ?? [];

                if (children.isEmpty) {
                  return Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.child_care_outlined,
                            size: 52,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'لا يوجد أطفال في هذا القسم',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedView == 'active'
                                ? 'ابدأ بإضافة طفل جديد'
                                : selectedView == 'archived'
                                    ? 'لا يوجد أطفال مؤرشفون حاليًا'
                                    : 'لا توجد بيانات بعد',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => showChildForm(),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة طفل'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      return buildChildCard(children[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}