import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'camera_checkin_page.dart';
import 'video_preview_page.dart';

class AddUpdatePage extends StatefulWidget {
  final ChildModel child;
  final String byRole; // nursery / teacher

  const AddUpdatePage({
    super.key,
    required this.child,
    required this.byRole,
  });

  @override
  State<AddUpdatePage> createState() => _AddUpdatePageState();
}

class _AddUpdatePageState extends State<AddUpdatePage> {
  final TextEditingController noteCtrl = TextEditingController();
  final TextEditingController extraCtrl = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GalleryService _galleryService = GalleryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String type = 'ملاحظة';
  bool isLoading = false;
  String? selectedMediaPath;
  String? selectedMediaType; // image / video

  final List<String> nurseryTypes = const [
    'وجبة',
    'نوم',
    'حفاض',
    'صحة',
    'نشاط',
    'ملاحظة',
  ];

  final List<String> teacherTypes = const [
    'نشاط',
    'خطة اليوم',
    'تقييم',
    'واجب',
    'ملاحظة',
  ];

  List<String> get types =>
      widget.byRole == 'nursery' ? nurseryTypes : teacherTypes;

  String mealStatus = 'تناول الوجبة جيدًا';
  String sleepStatus = 'نام جيدًا';
  String diaperStatus = 'تم التبديل';
  String healthStatus = 'حالته مستقرة';
  String activityStatus = 'شارك بالنشاط';
  String noteStatus = 'ملاحظة عامة';

  String planStatus = 'تم تنفيذ الخطة';
  String evaluationStatus = 'أداء جيد';
  String homeworkStatus = 'تم تسليم الواجب';

  String importance = 'عادي';
  String selectedMood = '😊';
  String selectedEnergy = 'متوسط';
  bool notifyParent = true;
  bool saveAsDraftPreview = true;
  DateTime selectedDateTime = DateTime.now();
  bool useNowTime = true;
  String selectedLocation = 'داخل الصف';
  final List<String> selectedTags = [];

  final List<String> nurseryTags = const [
    'أكل',
    'نوم',
    'سلوك',
    'صحة',
    'نشاط',
    'عناية',
    'مهم',
  ];

  final List<String> teacherTags = const [
    'نشاط',
    'تعلم',
    'واجب',
    'مشاركة',
    'سلوك',
    'تقييم',
    'مهم',
  ];

  List<String> get availableTags =>
      widget.byRole == 'nursery' ? nurseryTags : teacherTags;

  final List<String> nurseryLocations = const [
    'داخل الصف',
    'ساحة اللعب',
    'غرفة النوم',
    'منطقة الطعام',
    'الحمام',
    'مكان آخر',
  ];

  final List<String> teacherLocations = const [
    'داخل الصف',
    'ركن النشاط',
    'ساحة اللعب',
    'قاعة التعليم',
    'مكان آخر',
  ];

  List<String> get availableLocations =>
      widget.byRole == 'nursery' ? nurseryLocations : teacherLocations;

  @override
  void initState() {
    super.initState();
    if (!types.contains(type)) {
      type = types.first;
    }
    if (!availableTags.contains(type)) {
      _syncTagsWithType();
    }
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    extraCtrl.dispose();
    super.dispose();
  }

  String sectionLabel(String s) {
    if (s == 'Nursery') return 'حضانة';
    if (s == 'Kindergarten') return 'روضة';
    return s;
  }

  String roleLabel() {
    return widget.byRole == 'nursery' ? 'موظفة الحضانة' : 'المعلمة';
  }

  String pageHint() {
    if (widget.byRole == 'nursery') {
      return 'أضيفي تحديثًا واضحًا ومهنيًا عن الطفل، مع إمكانية تحديد الأهمية، الوقت، الحالة، وإرفاق صورة أو فيديو.';
    }
    return 'أضيفي تحديثًا تعليميًا أو ملاحظة منظمة عن الطفل، مع تفاصيل أوضح قبل الحفظ والإرسال.';
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
      case 'خطة اليوم':
        return Icons.event_note_outlined;
      case 'تقييم':
        return Icons.assessment_outlined;
      case 'واجب':
        return Icons.menu_book_outlined;
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
      case 'خطة اليوم':
        return AppColors.secondary;
      case 'تقييم':
        return const Color(0xFFFF8A65);
      case 'واجب':
        return const Color(0xFF7986CB);
      default:
        return AppColors.textLight;
    }
  }

  Color importanceColor(String value) {
    switch (value) {
      case 'مهم':
        return const Color(0xFFFF9800);
      case 'عاجل':
        return const Color(0xFFE53935);
      default:
        return AppColors.primary;
    }
  }

  IconData importanceIcon(String value) {
    switch (value) {
      case 'مهم':
        return Icons.priority_high_rounded;
      case 'عاجل':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
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

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data() ?? {};

    return {
      'uid': currentUser.uid,
      'name': (data['displayName'] ?? data['username'] ?? 'مستخدم').toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  Future<void> pickMedia() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraCheckinPage(),
      ),
    );

    if (res is Map) {
      final path = res['path'] as String?;
      final mediaType = res['type'] as String?;

      if (path == null || mediaType == null) return;

      setState(() {
        selectedMediaPath = path;
        selectedMediaType = mediaType;
      });
    }
  }

  void removeMedia() {
    setState(() {
      selectedMediaPath = null;
      selectedMediaType = null;
    });
  }

  void applyQuickTemplate(String text) {
    setState(() {
      noteCtrl.text = text;
    });
  }

  void _syncTagsWithType() {
    final map = {
      'وجبة': 'أكل',
      'نوم': 'نوم',
      'حفاض': 'عناية',
      'صحة': 'صحة',
      'نشاط': 'نشاط',
      'خطة اليوم': 'تعلم',
      'تقييم': 'تقييم',
      'واجب': 'واجب',
      'ملاحظة': 'مهم',
    };

    final mapped = map[type];
    if (mapped != null && availableTags.contains(mapped)) {
      if (!selectedTags.contains(mapped)) {
        selectedTags.add(mapped);
      }
    }
  }

  void toggleTag(String tag) {
    setState(() {
      if (selectedTags.contains(tag)) {
        selectedTags.remove(tag);
      } else {
        selectedTags.add(tag);
      }
    });
  }

  String formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  String formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }

  Future<void> pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (pickedTime == null) return;

    setState(() {
      selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      useNowTime = false;
    });
  }

  String autoTitle() {
    if (widget.byRole == 'nursery') {
      switch (type) {
        case 'وجبة':
          return importance == 'عاجل' ? 'تنبيه بخصوص الوجبة' : 'تحديث وجبة';
        case 'نوم':
          return importance == 'عاجل' ? 'تنبيه بخصوص النوم' : 'تحديث نوم';
        case 'حفاض':
          return 'تحديث عناية';
        case 'صحة':
          return importance == 'عاجل' ? 'تنبيه صحي' : 'تحديث صحي';
        case 'نشاط':
          return 'تحديث نشاط';
        default:
          return importance == 'عاجل' ? 'ملاحظة عاجلة' : 'ملاحظة عامة';
      }
    } else {
      switch (type) {
        case 'نشاط':
          return 'تحديث نشاط';
        case 'خطة اليوم':
          return 'خطة اليوم';
        case 'تقييم':
          return importance == 'عاجل' ? 'ملاحظة تقييم مهمة' : 'تحديث تقييم';
        case 'واجب':
          return 'تحديث واجب';
        default:
          return importance == 'عاجل' ? 'ملاحظة عاجلة' : 'ملاحظة عامة';
      }
    }
  }

  String buildSuggestedNote() {
    final note = noteCtrl.text.trim();
    final extra = extraCtrl.text.trim();

    String baseText;

    if (widget.byRole == 'nursery') {
      switch (type) {
        case 'وجبة':
          baseText = mealStatus;
          break;
        case 'نوم':
          baseText = sleepStatus;
          break;
        case 'حفاض':
          baseText = diaperStatus;
          break;
        case 'صحة':
          baseText = healthStatus;
          break;
        case 'نشاط':
          baseText = activityStatus;
          break;
        default:
          baseText = noteStatus;
      }
    } else {
      switch (type) {
        case 'نشاط':
          baseText = activityStatus;
          break;
        case 'خطة اليوم':
          baseText = planStatus;
          break;
        case 'تقييم':
          baseText = evaluationStatus;
          break;
        case 'واجب':
          baseText = homeworkStatus;
          break;
        default:
          baseText = 'ملاحظة عامة';
      }
    }

    final parts = <String>[];

    parts.add(baseText);

    if (note.isNotEmpty) {
      parts.add(note);
    }

    if (extra.isNotEmpty) {
      parts.add(extra);
    }

    final tagText =
        selectedTags.isEmpty ? '' : 'التصنيفات: ${selectedTags.join('، ')}';
    final moodText = 'المزاج: $selectedMood';
    final energyText = 'النشاط: $selectedEnergy';
    final locationText = selectedLocation.isNotEmpty ? 'المكان: $selectedLocation' : '';
    final importanceText = 'الأهمية: $importance';
    final timeText =
        'الوقت: ${formatDate(selectedDateTime)} - ${formatTime(selectedDateTime)}';

    final summaryParts = [
      parts.join('. '),
      moodText,
      energyText,
      if (tagText.isNotEmpty) tagText,
      if (locationText.isNotEmpty) locationText,
      importanceText,
      timeText,
    ];

    return summaryParts.join(' | ');
  }

  Future<void> save() async {
    final finalNote = buildSuggestedNote().trim();

    if (noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتبي وصفًا واضحًا للتحديث أولًا'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final now = Timestamp.now();
      String? uploadedMediaUrl;

      if (selectedMediaPath != null && selectedMediaType != null) {
        uploadedMediaUrl = await _galleryService.uploadChildMedia(
          childId: widget.child.id,
          localPath: selectedMediaPath!,
          mediaType: selectedMediaType!,
        );
      }

      final userInfo = await fetchCurrentUserInfo();

      await _firestore.collection('updates').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'section': widget.child.section,
        'group': widget.child.group,
        'type': type,
        'note': finalNote,
        'title': autoTitle(),
        'createdAt': now,
        'time': FieldValue.serverTimestamp(),
        'eventAt': Timestamp.fromDate(selectedDateTime),
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'mediaType': selectedMediaType,
        'mediaPath': selectedMediaPath,
        'mediaUrl': uploadedMediaUrl,
        'hasMedia': uploadedMediaUrl != null,
        'importance': importance,
        'tags': selectedTags,
        'mood': selectedMood,
        'energy': selectedEnergy,
        'locationLabel': selectedLocation,
        'notifyParent': notifyParent,
      });

      if (notifyParent) {
        await _firestore.collection('notifications').add({
          'childId': widget.child.id,
          'childName': widget.child.name,
          'parentUsername': widget.child.parentUsername.trim().toLowerCase(),
          'section': widget.child.section,
          'group': widget.child.group,
          'title': autoTitle(),
          'body': finalNote,
          'message': finalNote,
          'type': 'update_notification',
          'isRead': false,
          'createdAt': now,
          'time': FieldValue.serverTimestamp(),
          'createdByUid': userInfo['uid'],
          'createdByName': userInfo['name'],
          'createdByRole': userInfo['role'],
          'importance': importance,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة التحديث بنجاح'),
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
        isLoading = false;
      });
    }
  }

  Widget buildDynamicFields() {
    if (widget.byRole == 'nursery') {
      switch (type) {
        case 'وجبة':
          return _buildNurseryMealFields();
        case 'نوم':
          return _buildNurserySleepFields();
        case 'حفاض':
          return _buildNurseryDiaperFields();
        case 'صحة':
          return _buildNurseryHealthFields();
        case 'نشاط':
          return _buildNurseryActivityFields();
        default:
          return _buildNurseryNoteFields();
      }
    } else {
      switch (type) {
        case 'نشاط':
          return _buildTeacherActivityFields();
        case 'خطة اليوم':
          return _buildTeacherPlanFields();
        case 'تقييم':
          return _buildTeacherEvaluationFields();
        case 'واجب':
          return _buildTeacherHomeworkFields();
        default:
          return _buildTeacherNoteFields();
      }
    }
  }

  Widget _buildNurseryMealFields() {
    return _sectionCard(
      title: 'تفاصيل الوجبة',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'تناول الوجبة جيدًا',
              'تناول جزءًا من الوجبة',
              'رفض الوجبة',
              'شرب الحليب',
            ],
            selectedValue: mealStatus,
            onSelected: (value) {
              setState(() {
                mealStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'شهية جيدة',
                onTap: () => applyQuickTemplate('كانت شهيته جيدة اليوم.'),
              ),
              _QuickTextChip(
                label: 'احتاج مساعدة',
                onTap: () => applyQuickTemplate('احتاج مساعدة أثناء الوجبة.'),
              ),
              _QuickTextChip(
                label: 'أكل ببطء',
                onTap: () => applyQuickTemplate(
                  'تناول الطعام ببطء لكنه أكمل معظم الوجبة.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNurserySleepFields() {
    return _sectionCard(
      title: 'تفاصيل النوم',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'نام جيدًا',
              'نام بصعوبة',
              'استيقظ أكثر من مرة',
              'لم ينم اليوم',
            ],
            selectedValue: sleepStatus,
            onSelected: (value) {
              setState(() {
                sleepStatus = value;
              });
            },
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
                onTap: () => applyQuickTemplate('كان قلقًا قليلًا أثناء النوم.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNurseryDiaperFields() {
    return _sectionCard(
      title: 'تفاصيل الحفاض',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'تم التبديل',
              'تم التنظيف',
              'يحتاج متابعة',
              'تم التبديل مع ملاحظة',
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
                    applyQuickTemplate('لوحظ احمرار بسيط ويحتاج متابعة.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNurseryHealthFields() {
    return _sectionCard(
      title: 'تفاصيل الحالة الصحية',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'حالته مستقرة',
              'حرارة خفيفة',
              'كحة خفيفة',
              'يحتاج متابعة',
            ],
            selectedValue: healthStatus,
            onSelected: (value) {
              setState(() {
                healthStatus = value;
              });
            },
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
                label: 'تم إبلاغ الأهل',
                onTap: () => applyQuickTemplate(
                  'تمت ملاحظة الحالة وإبلاغ ولي الأمر للمتابعة.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNurseryActivityFields() {
    return _sectionCard(
      title: 'تفاصيل النشاط',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'شارك بالنشاط',
              'استمتع بالنشاط',
              'احتاج تشجيعًا',
              'لم يرغب بالمشاركة',
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
                onTap: () => applyQuickTemplate(
                  'شارك في نشاط الرسم والتلوين وكان سعيدًا.',
                ),
              ),
              _QuickTextChip(
                label: 'لعب جماعي',
                onTap: () =>
                    applyQuickTemplate('شارك في اللعب الجماعي مع الأطفال.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNurseryNoteFields() {
    return _sectionCard(
      title: 'ملاحظة عامة',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'ملاحظة عامة',
              'يوم جيد',
              'يحتاج متابعة',
              'ملاحظة مهمة',
            ],
            selectedValue: noteStatus,
            onSelected: (value) {
              setState(() {
                noteStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'كان هادئًا',
                onTap: () => applyQuickTemplate(
                  'كان هادئًا ومتعاونًا خلال اليوم.',
                ),
              ),
              _QuickTextChip(
                label: 'متفاعل',
                onTap: () =>
                    applyQuickTemplate('كان متفاعلًا بشكل جميل مع المحيط.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherActivityFields() {
    return _sectionCard(
      title: 'تفاصيل النشاط',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'شارك بالنشاط',
              'أبدع في النشاط',
              'احتاج مساعدة',
              'لم يُكمل النشاط',
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
                label: 'مشاركة ممتازة',
                onTap: () =>
                    applyQuickTemplate('أظهر مشاركة ممتازة وتفاعلًا واضحًا.'),
              ),
              _QuickTextChip(
                label: 'احتاج دعم',
                onTap: () =>
                    applyQuickTemplate('احتاج دعمًا بسيطًا لإتمام النشاط.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherPlanFields() {
    return _sectionCard(
      title: 'خطة اليوم',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'تم تنفيذ الخطة',
              'تم تنفيذ جزء من الخطة',
              'الخطة كانت ناجحة',
              'يحتاج متابعة بالخطة',
            ],
            selectedValue: planStatus,
            onSelected: (value) {
              setState(() {
                planStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'نشاطات اليوم',
                onTap: () => applyQuickTemplate(
                  'تم تنفيذ أنشطة اليوم بشكل منظم وواضح.',
                ),
              ),
              _QuickTextChip(
                label: 'مشاركة جيدة',
                onTap: () => applyQuickTemplate(
                  'أظهر الطفل تفاعلًا جيدًا مع خطة اليوم.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherEvaluationFields() {
    return _sectionCard(
      title: 'التقييم',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'أداء جيد',
              'أداء ممتاز',
              'يحتاج تحسين',
              'يحتاج متابعة',
            ],
            selectedValue: evaluationStatus,
            onSelected: (value) {
              setState(() {
                evaluationStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'ممتاز',
                onTap: () => applyQuickTemplate('قدّم أداءً ممتازًا اليوم.'),
              ),
              _QuickTextChip(
                label: 'بحاجة دعم',
                onTap: () => applyQuickTemplate(
                  'يحتاج بعض الدعم الإضافي لتحسين أدائه.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherHomeworkFields() {
    return _sectionCard(
      title: 'الواجب',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'تم تسليم الواجب',
              'الواجب مكتمل',
              'الواجب غير مكتمل',
              'لم يتم تسليم الواجب',
            ],
            selectedValue: homeworkStatus,
            onSelected: (value) {
              setState(() {
                homeworkStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'تسليم ممتاز',
                onTap: () => applyQuickTemplate(
                  'تم تسليم الواجب بشكل ممتاز ومنظم.',
                ),
              ),
              _QuickTextChip(
                label: 'بحاجة إكمال',
                onTap: () => applyQuickTemplate(
                  'الواجب يحتاج بعض الإكمال أو التصحيح.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherNoteFields() {
    return _sectionCard(
      title: 'ملاحظة عامة',
      child: Column(
        children: [
          _ChoiceWrap(
            values: const [
              'ملاحظة عامة',
              'ملاحظة إيجابية',
              'يحتاج متابعة',
              'ملاحظة مهمة',
            ],
            selectedValue: noteStatus,
            onSelected: (value) {
              setState(() {
                noteStatus = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTextChip(
                label: 'متفاعل',
                onTap: () =>
                    applyQuickTemplate('كان متفاعلًا ومشاركًا داخل الصف.'),
              ),
              _QuickTextChip(
                label: 'يحتاج متابعة',
                onTap: () => applyQuickTemplate(
                  'يحتاج متابعة إضافية في الفترة القادمة.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = selectedMediaPath != null && selectedMediaType != null;
    final previewText = buildSuggestedNote();

    return AppPageScaffold(
      title: 'إضافة تحديث',
      child: ListView(
        children: [
          _buildHeader(context),
          const SizedBox(height: 18),
          _buildChildInfoCard(),
          const SizedBox(height: 18),
          _buildImportanceSection(),
          const SizedBox(height: 18),
          _buildTypeSection(context),
          const SizedBox(height: 18),
          _buildTagsSection(),
          const SizedBox(height: 18),
          _buildTimeAndLocationSection(),
          const SizedBox(height: 18),
          _buildStatusSection(),
          const SizedBox(height: 18),
          buildDynamicFields(),
          const SizedBox(height: 18),
          _buildNoteSection(context),
          const SizedBox(height: 18),
          _buildOptionsSection(),
          const SizedBox(height: 18),
          _buildPreviewSection(previewText),
          const SizedBox(height: 20),
          _buildMediaSection(context, hasMedia),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isLoading ? null : save,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(isLoading ? 'جاري الإرسال...' : 'إضافة التحديث'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.12),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.10),
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
              typeIcon(type),
              color: typeColor(type),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة تحديث جديد',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  pageHint(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.75),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.child.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(
            icon: Icons.apartment_outlined,
            label: 'القسم',
            value: sectionLabel(widget.child.section),
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.groups_outlined,
            label: 'المجموعة',
            value: widget.child.group.isEmpty ? 'غير محددة' : widget.child.group,
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.badge_outlined,
            label: 'بواسطة',
            value: roleLabel(),
          ),
        ],
      ),
    );
  }

  Widget _buildImportanceSection() {
    return _sectionCard(
      title: 'مستوى الأهمية',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: ['عادي', 'مهم', 'عاجل'].map((item) {
          final selected = importance == item;
          final color = importanceColor(item);

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                importance = item;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? color : AppColors.border.withOpacity(0.9),
                  width: selected ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    importanceIcon(item),
                    size: 18,
                    color: selected ? color : AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item,
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
    );
  }

  Widget _buildTypeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع التحديث',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'اختاري النوع المناسب بشكل سريع وواضح.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: types.map((t) {
            final selected = type == t;
            final color = typeColor(t);

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  type = t;
                  _syncTagsWithType();
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
                      typeIcon(t),
                      size: 18,
                      color: selected ? color : AppColors.textLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t,
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
    );
  }

  Widget _buildTagsSection() {
    return _sectionCard(
      title: 'التصنيفات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'يمكنك اختيار أكثر من تصنيف لنفس التحديث.',
            style: TextStyle(
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTags.map((tag) {
              final selected = selectedTags.contains(tag);
              return FilterChip(
                selected: selected,
                label: Text(tag),
                onSelected: (_) => toggleTag(tag),
                selectedColor: AppColors.primary.withOpacity(0.12),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : AppColors.border.withOpacity(0.9),
                ),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndLocationSection() {
    return _sectionCard(
      title: 'الوقت والمكان',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _miniInfoCard(
                  icon: Icons.access_time_rounded,
                  title: 'وقت التحديث',
                  value:
                      '${formatDate(selectedDateTime)} - ${formatTime(selectedDateTime)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfoCard(
                  icon: Icons.place_outlined,
                  title: 'المكان',
                  value: selectedLocation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: useNowTime,
            onChanged: (value) {
              setState(() {
                useNowTime = value;
                if (value) {
                  selectedDateTime = DateTime.now();
                }
              });
            },
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            title: const Text(
              'استخدام الوقت الحالي',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('فعّليها لاختيار "الآن" مباشرة'),
          ),
          if (!useNowTime) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: pickDateTime,
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('اختيار التاريخ والوقت'),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedLocation,
            decoration: const InputDecoration(
              labelText: 'المكان (اختياري)',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: availableLocations
                .map(
                  (location) => DropdownMenuItem<String>(
                    value: location,
                    child: Text(location),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedLocation = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return _sectionCard(
      title: 'تقييم الحالة',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _smallLabel('المزاج'),
              ),
              Expanded(
                child: _smallLabel('مستوى النشاط'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['😊', '😐', '😢', '😴', '🤒'].map((mood) {
                    final selected = selectedMood == mood;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          selectedMood = mood;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border.withOpacity(0.9),
                          ),
                        ),
                        child: Text(
                          mood,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['منخفض', 'متوسط', 'عالي'].map((energy) {
                    final selected = selectedEnergy == energy;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          selectedEnergy = energy;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.secondary.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.secondary
                                : AppColors.border.withOpacity(0.9),
                          ),
                        ),
                        child: Text(
                          energy,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.secondary
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(BuildContext context) {
    return _sectionCard(
      title: 'وصف التحديث',
      child: Column(
        children: [
          TextField(
            controller: noteCtrl,
            maxLines: 4,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'اكتبي ماذا حدث مع الطفل بالتفصيل...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
            onChanged: (_) {
              if (saveAsDraftPreview) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: extraCtrl,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'تفاصيل إضافية اختيارية مثل الملاحظات أو التوصيات...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            onChanged: (_) {
              if (saveAsDraftPreview) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return _sectionCard(
      title: 'خيارات إضافية',
      child: Column(
        children: [
          CheckboxListTile(
            value: notifyParent,
            onChanged: (value) {
              setState(() {
                notifyParent = value ?? false;
              });
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'إرسال إشعار لولي الأمر',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('سيتم إنشاء إشعار مع التحديث'),
          ),
          CheckboxListTile(
            value: saveAsDraftPreview,
            onChanged: (value) {
              setState(() {
                saveAsDraftPreview = value ?? true;
              });
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'تحديث المعاينة مباشرة',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('معاينة فورية للنص النهائي قبل الحفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(String previewText) {
    return _sectionCard(
      title: 'معاينة التحديث',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: importanceColor(importance).withOpacity(0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _previewBadge(
                  icon: importanceIcon(importance),
                  label: importance,
                  color: importanceColor(importance),
                ),
                _previewBadge(
                  icon: typeIcon(type),
                  label: type,
                  color: typeColor(type),
                ),
                _previewBadge(
                  icon: Icons.mood_outlined,
                  label: selectedMood,
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              previewText.isEmpty ? 'سيظهر النص النهائي هنا' : previewText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, bool hasMedia) {
    final isImage = selectedMediaType == 'image';
    final isVideo = selectedMediaType == 'video';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مرفق اختياري',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'يمكنكِ إرفاق صورة أو فيديو مع التحديث.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickMedia,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(hasMedia ? 'تغيير المرفق' : 'إضافة صورة أو فيديو'),
              ),
            ),
          ],
        ),
        if (hasMedia) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border.withOpacity(0.85),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isImage
                          ? Icons.image_outlined
                          : Icons.video_library_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isImage ? 'تم إرفاق صورة' : 'تم إرفاق فيديو',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: removeMedia,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (isImage && !kIsWeb)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(selectedMediaPath!),
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (isImage && kIsWeb)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'تم اختيار صورة.\nالمعاينة المحلية غير مدعومة على Flutter Web، لكن سيتم رفع الصورة عند الإرسال.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        height: 1.5,
                      ),
                    ),
                  ),
                if (isVideo)
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'تم اختيار فيديو بنجاح.',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoPreviewPage(
                                path: selectedMediaPath!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('معاينة الفيديو'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.textLight,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textLight,
      ),
    );
  }

  Widget _previewBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
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
        final selected = selectedValue == value;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(value),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color:
                  selected ? AppColors.primary.withOpacity(0.10) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border.withOpacity(0.9),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
      onPressed: onTap,
      backgroundColor: AppColors.background,
      side: BorderSide(
        color: AppColors.border.withOpacity(0.85),
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      avatar: const Icon(
        Icons.auto_awesome_outlined,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}
