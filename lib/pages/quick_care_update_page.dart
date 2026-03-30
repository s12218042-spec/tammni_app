import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class QuickCareUpdatePage extends StatefulWidget {
  final ChildModel child;

  const QuickCareUpdatePage({
    super.key,
    required this.child,
  });

  @override
  State<QuickCareUpdatePage> createState() => _QuickCareUpdatePageState();
}

class _QuickCareUpdatePageState extends State<QuickCareUpdatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController();
  final TextEditingController _tempCtrl = TextEditingController();

  bool isSaving = false;
  String selectedType = 'وجبة';

  String mealStatus = 'أكمل الوجبة';
  String sleepStatus = 'نام جيدًا';
  String diaperStatus = 'تم التبديل';
  String healthStatus = 'مستقر';
  String activityStatus = 'شارك بالنشاط';
  String noteMood = 'هادئ';

  final List<String> careTypes = const [
    'وجبة',
    'نوم',
    'حفاض',
    'صحة',
    'نشاط',
    'ملاحظة',
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    _durationCtrl.dispose();
    _quantityCtrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {
        'uid': '',
        'name': 'مستخدم غير معروف',
        'role': '',
      };
    }

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data() ?? {};

    return {
      'uid': currentUser.uid,
      'name': (data['displayName'] ?? data['username'] ?? 'مستخدم').toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  IconData typeIcon(String value) {
    switch (value) {
      case 'وجبة':
        return Icons.restaurant_outlined;
      case 'نوم':
        return Icons.bedtime_outlined;
      case 'حفاض':
        return Icons.child_friendly_outlined;
      case 'صحة':
        return Icons.health_and_safety_outlined;
      case 'نشاط':
        return Icons.palette_outlined;
      default:
        return Icons.edit_note_outlined;
    }
  }

  Color typeColor(String value) {
    switch (value) {
      case 'وجبة':
        return const Color(0xFFFFB74D);
      case 'نوم':
        return const Color(0xFF9575CD);
      case 'حفاض':
        return const Color(0xFF4FC3F7);
      case 'صحة':
        return AppColors.success;
      case 'نشاط':
        return AppColors.primary;
      default:
        return AppColors.textLight;
    }
  }

  void applyQuickTemplate(String text) {
    setState(() {
      _noteCtrl.text = text;
    });
  }

  String buildSuggestedNote() {
    final extra = _noteCtrl.text.trim();

    switch (selectedType) {
      case 'وجبة':
        final quantity = _quantityCtrl.text.trim();
        final base = quantity.isNotEmpty
            ? 'الطفل $mealStatus، والكمية: $quantity.'
            : 'الطفل $mealStatus.';
        return extra.isEmpty ? base : '$base $extra';

      case 'نوم':
        final duration = _durationCtrl.text.trim();
        final base = duration.isNotEmpty
            ? 'الطفل $sleepStatus لمدة $duration.'
            : 'الطفل $sleepStatus.';
        return extra.isEmpty ? base : '$base $extra';

      case 'حفاض':
        final base = 'الحالة: $diaperStatus.';
        return extra.isEmpty ? base : '$base $extra';

      case 'صحة':
        final temp = _tempCtrl.text.trim();
        final base = temp.isNotEmpty
            ? 'الحالة الصحية: $healthStatus، والحرارة: $temp.'
            : 'الحالة الصحية: $healthStatus.';
        return extra.isEmpty ? base : '$base $extra';

      case 'نشاط':
        final base = 'الطفل $activityStatus.';
        return extra.isEmpty ? base : '$base $extra';

      default:
        final moodText = 'حالة الطفل العامة: $noteMood.';
        return extra.isEmpty ? moodText : '$moodText $extra';
    }
  }

  Future<void> saveQuickUpdate() async {
    final finalNote = buildSuggestedNote().trim();

    if (finalNote.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخلي تفاصيل التحديث أولاً'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();

      await _firestore.collection('updates').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'section': widget.child.section,
        'group': widget.child.group,
        'type': selectedType,
        'note': finalNote,
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'hasMedia': false,
        'mediaType': null,
        'mediaPath': null,
        'mediaUrl': null,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ تحديث الرعاية بنجاح'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ التحديث: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget buildTypeSelector() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نوع التحديث',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: careTypes.map((type) {
              final selected = selectedType == type;
              final color = typeColor(type);

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    selectedType = type;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.14) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? color : AppColors.border.withOpacity(0.9),
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        typeIcon(type),
                        size: 18,
                        color: selected ? color : AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? color : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildSmartFields() {
    switch (selectedType) {
      case 'وجبة':
        return _buildMealFields();
      case 'نوم':
        return _buildSleepFields();
      case 'حفاض':
        return _buildDiaperFields();
      case 'صحة':
        return _buildHealthFields();
      case 'نشاط':
        return _buildActivityFields();
      default:
        return _buildGeneralNoteFields();
    }
  }

  Widget _buildMealFields() {
    return _SmartSectionCard(
      title: 'تفاصيل الوجبة',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const ['أكمل الوجبة', 'أكل نصف الوجبة', 'رفض الوجبة', 'شرب الحليب'],
            selectedValue: mealStatus,
            onSelected: (value) {
              setState(() {
                mealStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityCtrl,
            decoration: const InputDecoration(
              labelText: 'الكمية أو الملاحظة السريعة',
              hintText: 'مثال: كاملة / نصف كوب / قليل',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'أكل جيدًا',
                onTap: () => applyQuickTemplate('أكل جيدًا وكان مرتاحًا.'),
              ),
              _QuickTextChip(
                label: 'احتاج مساعدة',
                onTap: () => applyQuickTemplate('احتاج مساعدة أثناء تناول الوجبة.'),
              ),
              _QuickTextChip(
                label: 'شهية منخفضة',
                onTap: () => applyQuickTemplate('شهيته كانت منخفضة اليوم.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepFields() {
    return _SmartSectionCard(
      title: 'تفاصيل النوم',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const ['نام جيدًا', 'نام بصعوبة', 'استيقظ أكثر من مرة', 'لم ينم'],
            selectedValue: sleepStatus,
            onSelected: (value) {
              setState(() {
                sleepStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationCtrl,
            decoration: const InputDecoration(
              labelText: 'مدة النوم',
              hintText: 'مثال: ساعة / ساعة ونصف / 30 دقيقة',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'نوم هادئ',
                onTap: () => applyQuickTemplate('نام بهدوء واستيقظ بحالة جيدة.'),
              ),
              _QuickTextChip(
                label: 'قلق أثناء النوم',
                onTap: () => applyQuickTemplate('كان قلقًا أثناء النوم واستيقظ أكثر من مرة.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiaperFields() {
    return _SmartSectionCard(
      title: 'تفاصيل الحفاض',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const ['تم التبديل', 'يحتاج متابعة', 'تم التنظيف', 'تم التبديل مع ملاحظة'],
            selectedValue: diaperStatus,
            onSelected: (value) {
              setState(() {
                diaperStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'كل شيء طبيعي',
                onTap: () => applyQuickTemplate('تم التبديل وكل شيء طبيعي.'),
              ),
              _QuickTextChip(
                label: 'احمرار بسيط',
                onTap: () => applyQuickTemplate('تمت ملاحظة احمرار بسيط ويحتاج متابعة.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthFields() {
    return _SmartSectionCard(
      title: 'تفاصيل الحالة الصحية',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const ['مستقر', 'حرارة خفيفة', 'كحة خفيفة', 'يحتاج متابعة'],
            selectedValue: healthStatus,
            onSelected: (value) {
              setState(() {
                healthStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tempCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'درجة الحرارة إن وجدت',
              hintText: 'مثال: 37.5',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'بحالة جيدة',
                onTap: () => applyQuickTemplate('الطفل بحالة جيدة وتمت متابعته.'),
              ),
              _QuickTextChip(
                label: 'إبلاغ ولي الأمر',
                onTap: () => applyQuickTemplate('تمت ملاحظة الحالة وإبلاغ ولي الأمر للمتابعة.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFields() {
    return _SmartSectionCard(
      title: 'تفاصيل النشاط',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const ['شارك بالنشاط', 'استمتع بالنشاط', 'احتاج تشجيع', 'لم يرغب بالمشاركة'],
            selectedValue: activityStatus,
            onSelected: (value) {
              setState(() {
                activityStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'رسم وتلوين',
                onTap: () => applyQuickTemplate('شارك في نشاط الرسم والتلوين بشكل جيد.'),
              ),
              _QuickTextChip(
                label: 'لعب جماعي',
                onTap: () => applyQuickTemplate('شارك في اللعب الجماعي مع الأطفال.'),
              ),
              _QuickTextChip(
                label: 'احتاج تشجيع',
                onTap: () => applyQuickTemplate('احتاج تشجيعًا بسيطًا للمشاركة في النشاط.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralNoteFields() {
    return _SmartSectionCard(
      title: 'ملاحظة عامة',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const ['هادئ', 'مرتاح', 'منزعج', 'يحتاج متابعة'],
            selectedValue: noteMood,
            onSelected: (value) {
              setState(() {
                noteMood = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'يوم جيد',
                onTap: () => applyQuickTemplate('قضى يومًا جيدًا وكان متفاعلًا.'),
              ),
              _QuickTextChip(
                label: 'يحتاج مراقبة',
                onTap: () => applyQuickTemplate('يحتاج مراقبة بسيطة خلال اليوم.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = typeColor(selectedType);
    final finalPreview = buildSuggestedNote();

    return AppPageScaffold(
      title: 'تحديث رعاية سريع',
      child: ListView(
        children: [
          Container(
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
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    typeIcon(selectedType),
                    color: currentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رعاية ${widget.child.name}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أضيفي تحديثًا سريعًا مع خيارات جاهزة لتسريع العمل اليومي.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          buildTypeSelector(),
          const SizedBox(height: 18),
          buildSmartFields(),
          const SizedBox(height: 18),
          _SmartSectionCard(
            title: 'تفاصيل إضافية',
            child: TextField(
              controller: _noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'أضيفي وصفًا إضافيًا عند الحاجة',
                hintText: 'مثال: كان سعيدًا، احتاج وقتًا إضافيًا، تم التواصل مع الأهل...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SmartSectionCard(
            title: 'معاينة النص النهائي',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                finalPreview.isEmpty ? 'سيظهر النص النهائي هنا' : finalPreview,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: isSaving ? null : saveQuickUpdate,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التحديث'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SmartSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SmartSectionCard({
    required this.title,
    required this.child,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _ChoiceWrap({
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = value == selectedValue;

        return ChoiceChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}

class _QuickTextChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickTextChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}