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

  String childMood = 'طبيعي';
  String quantityLevel = 'متوسط';
  List<String> selectedSymptoms = [];

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

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      final data = userDoc.data() ?? <String, dynamic>{};

      return {
        'uid': currentUser.uid,
        'name': (data['displayName'] ??
                data['name'] ??
                data['username'] ??
                'مستخدم')
            .toString()
            .trim(),
        'role': (data['role'] ?? '').toString().trim(),
      };
    } catch (_) {
      return {
        'uid': currentUser.uid,
        'name': currentUser.displayName?.trim().isNotEmpty == true
            ? currentUser.displayName!.trim()
            : 'مستخدم',
        'role': '',
      };
    }
  }

  Future<Map<String, String>> fetchParentLinkInfo() async {
    String parentUid = widget.child.parentUid.trim();
    String parentUsername = widget.child.parentUsername.trim().toLowerCase();
    String parentName = widget.child.parentName.trim();

    try {
      final childDoc =
          await _firestore.collection('children').doc(widget.child.id).get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? <String, dynamic>{};

        final docParentUid = (data['parentUid'] ?? '').toString().trim();
        final docParentUsername =
            (data['parentUsername'] ?? '').toString().trim().toLowerCase();
        final docParentName = (data['parentName'] ?? '').toString().trim();

        if (docParentUid.isNotEmpty) {
          parentUid = docParentUid;
        }

        if (docParentUsername.isNotEmpty) {
          parentUsername = docParentUsername;
        }

        if (docParentName.isNotEmpty) {
          parentName = docParentName;
        }
      }
    } catch (_) {
      // fallback على بيانات child الحالية
    }

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
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

  String getCurrentTimeLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String getStatusLabel() {
    final joinedSymptoms = selectedSymptoms.join(' ');

    final hasRiskWords = mealStatus.contains('استفراغ') ||
        mealStatus.contains('حساسية') ||
        healthStatus.contains('يحتاج متابعة') ||
        joinedSymptoms.contains('حرارة') ||
        joinedSymptoms.contains('إسهال');

    final hasMediumWords = mealStatus.contains('رفض') ||
        mealStatus.contains('لا يأكل') ||
        mealStatus.contains('سوائل') ||
        sleepStatus.contains('بصعوبة') ||
        sleepStatus.contains('استيقظ') ||
        activityStatus.contains('احتاج تشجيع') ||
        activityStatus.contains('لم يرغب') ||
        childMood == 'متعب';

    if (hasRiskWords) return 'خطر';
    if (hasMediumWords) return 'يحتاج متابعة';
    return 'طبيعي';
  }

  Color getStatusColor() {
    switch (getStatusLabel()) {
      case 'خطر':
        return Colors.redAccent;
      case 'يحتاج متابعة':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData getStatusIcon() {
    switch (getStatusLabel()) {
      case 'خطر':
        return Icons.warning_amber_rounded;
      case 'يحتاج متابعة':
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  void applyQuickTemplate(String text) {
    setState(() {
      _noteCtrl.text = text;
    });
  }

  String buildSuggestedNote() {
    final extra = _noteCtrl.text.trim();

    final symptomsText = selectedSymptoms.isEmpty
        ? ''
        : ' الأعراض الملحوظة: ${selectedSymptoms.join('، ')}.';

    final moodText = ' الحالة العامة: $childMood.';

    final quantityText = _quantityCtrl.text.trim().isNotEmpty
        ? ' الكمية: ${_quantityCtrl.text.trim()}.'
        : ' مستوى الكمية: $quantityLevel.';

    switch (selectedType) {
      case 'وجبة':
        final base = 'الطفل $mealStatus.$quantityText$moodText$symptomsText';
        return extra.isEmpty ? base.trim() : '$base ${extra.trim()}';

      case 'نوم':
        final duration = _durationCtrl.text.trim();
        final base = duration.isNotEmpty
            ? 'الطفل $sleepStatus لمدة $duration.$moodText$symptomsText'
            : 'الطفل $sleepStatus.$moodText$symptomsText';
        return extra.isEmpty ? base.trim() : '$base ${extra.trim()}';

      case 'حفاض':
        final base = 'الحالة: $diaperStatus.$moodText$symptomsText';
        return extra.isEmpty ? base.trim() : '$base ${extra.trim()}';

      case 'صحة':
        final temp = _tempCtrl.text.trim();
        final base = temp.isNotEmpty
            ? 'الحالة الصحية: $healthStatus، ودرجة الحرارة: $temp.$moodText$symptomsText'
            : 'الحالة الصحية: $healthStatus.$moodText$symptomsText';
        return extra.isEmpty ? base.trim() : '$base ${extra.trim()}';

      case 'نشاط':
        final base = 'الطفل $activityStatus.$moodText$symptomsText';
        return extra.isEmpty ? base.trim() : '$base ${extra.trim()}';

      default:
        final base = 'حالة الطفل العامة: $noteMood.$moodText$symptomsText';
        return extra.isEmpty ? base.trim() : '$base ${extra.trim()}';
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحفظ'),
          content: const Text('هل أنتِ متأكدة من حفظ تحديث الرعاية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isSaving = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();
      final now = Timestamp.now();

      await _firestore.collection('updates').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUid': parentInfo['parentUid'],
        'parentUsername': parentInfo['parentUsername'],
        'parentName': parentInfo['parentName'],
        'section': widget.child.section,
        'group': widget.child.group,
        'type': selectedType,
        'updateType': selectedType,
        'category': selectedType,
        'title': 'تحديث رعاية سريع',
        'note': finalNote,
        'message': finalNote,
        'description': finalNote,
        'createdAt': now,
        'time': FieldValue.serverTimestamp(),
        'eventAt': now,
        'updatedAt': now,
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'hasMedia': false,
        'mediaType': '',
        'mediaPath': '',
        'mediaUrl': '',
        'storageProvider': '',
        'bucket': '',
        'mimeType': '',
        'sizeBytes': 0,
        'quickCareStatus': getStatusLabel(),
        'childMood': childMood,
        'quantityLevel': quantityLevel,
        'quantityText': _quantityCtrl.text.trim(),
        'durationText': _durationCtrl.text.trim(),
        'temperatureText': _tempCtrl.text.trim(),
        'symptoms': selectedSymptoms,
        'mealStatus': selectedType == 'وجبة' ? mealStatus : '',
        'sleepStatus': selectedType == 'نوم' ? sleepStatus : '',
        'diaperStatus': selectedType == 'حفاض' ? diaperStatus : '',
        'healthStatus': selectedType == 'صحة' ? healthStatus : '',
        'activityStatus': selectedType == 'نشاط' ? activityStatus : '',
        'noteMood': selectedType == 'ملاحظة' ? noteMood : '',
        'importance': getStatusLabel() == 'خطر'
            ? 'urgent'
            : getStatusLabel() == 'يحتاج متابعة'
                ? 'important'
                : 'normal',
        'notifyParent': false,
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
                      color:
                          selected ? color : AppColors.border.withOpacity(0.9),
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
            values: const [
              'أكمل الوجبة',
              'أكل نصف الوجبة',
              'رفض الوجبة',
              'شرب الحليب',
              'لا يأكل',
              'يشرب سوائل فقط',
              'استفراغ',
              'حساسية',
            ],
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
            values: const [
              'نام جيدًا',
              'نام بصعوبة',
              'استيقظ أكثر من مرة',
              'لم ينم'
            ],
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
                onTap: () => applyQuickTemplate(
                  'كان قلقًا أثناء النوم واستيقظ أكثر من مرة.',
                ),
              ),
              _QuickTextChip(
                label: 'احتاج تهدئة',
                onTap: () => applyQuickTemplate('احتاج تهدئة قبل النوم حتى ينام.'),
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
            values: const [
              'تم التبديل',
              'يحتاج متابعة',
              'تم التنظيف',
              'تم التبديل مع ملاحظة'
            ],
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
                onTap: () =>
                    applyQuickTemplate('تمت ملاحظة احمرار بسيط ويحتاج متابعة.'),
              ),
              _QuickTextChip(
                label: 'بحاجة لفحص',
                onTap: () => applyQuickTemplate('تمت الملاحظة وقد يحتاج متابعة إضافية.'),
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
                onTap: () => applyQuickTemplate(
                  'تمت ملاحظة الحالة وإبلاغ ولي الأمر للمتابعة.',
                ),
              ),
              _QuickTextChip(
                label: 'يحتاج راحة',
                onTap: () => applyQuickTemplate(
                  'يحتاج إلى الراحة والمتابعة خلال اليوم.',
                ),
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
            values: const [
              'شارك بالنشاط',
              'استمتع بالنشاط',
              'احتاج تشجيع',
              'لم يرغب بالمشاركة'
            ],
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
                onTap: () =>
                    applyQuickTemplate('شارك في نشاط الرسم والتلوين بشكل جيد.'),
              ),
              _QuickTextChip(
                label: 'لعب جماعي',
                onTap: () =>
                    applyQuickTemplate('شارك في اللعب الجماعي مع الأطفال.'),
              ),
              _QuickTextChip(
                label: 'احتاج تشجيع',
                onTap: () => applyQuickTemplate(
                  'احتاج تشجيعًا بسيطًا للمشاركة في النشاط.',
                ),
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
              _QuickTextChip(
                label: 'احتاج تهدئة',
                onTap: () => applyQuickTemplate('احتاج تهدئة واحتواء خلال اليوم.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildMoodCard() {
    return _SmartSectionCard(
      title: 'الحالة العامة للطفل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChoiceWrap(
            values: const ['سعيد', 'طبيعي', 'متعب'],
            selectedValue: childMood,
            onSelected: (value) {
              setState(() {
                childMood = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomsCard() {
    const symptomOptions = ['حرارة', 'سعال', 'إسهال', 'تعب'];

    return _SmartSectionCard(
      title: 'أعراض سريعة',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: symptomOptions.map((symptom) {
          final isSelected = selectedSymptoms.contains(symptom);

          return FilterChip(
            label: Text(symptom),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  if (!selectedSymptoms.contains(symptom)) {
                    selectedSymptoms.add(symptom);
                  }
                } else {
                  selectedSymptoms.remove(symptom);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = getStatusColor();
    final statusLabel = getStatusLabel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              getStatusIcon(),
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مؤشر الحالة',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              getCurrentTimeLabel(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
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
                      const SizedBox(height: 6),
                      Text(
                        'وقت التحديث: ${getCurrentTimeLabel()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildStatusCard(),
          const SizedBox(height: 18),
          buildTypeSelector(),
          const SizedBox(height: 18),
          buildSmartFields(),
          const SizedBox(height: 18),
          _buildChildMoodCard(),
          const SizedBox(height: 18),
          _buildSymptomsCard(),
          const SizedBox(height: 18),
          _SmartSectionCard(
            title: 'تفاصيل إضافية',
            child: TextField(
              controller: _noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'أضيفي وصفًا إضافيًا عند الحاجة',
                hintText:
                    'مثال: كان سعيدًا، احتاج وقتًا إضافيًا، تم التواصل مع الأهل...',
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
                border: Border.all(
                  color: AppColors.border.withOpacity(0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: currentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      finalPreview.isEmpty
                          ? 'سيظهر النص النهائي هنا'
                          : finalPreview,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
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