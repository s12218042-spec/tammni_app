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

  List<String> get types => widget.byRole == 'nursery' ? nurseryTypes : teacherTypes;

  String mealStatus = 'تناول الوجبة جيدًا';
  String sleepStatus = 'نام جيدًا';
  String diaperStatus = 'تم التبديل';
  String healthStatus = 'حالته مستقرة';
  String activityStatus = 'شارك بالنشاط';
  String noteStatus = 'ملاحظة عامة';

  String planStatus = 'تم تنفيذ الخطة';
  String evaluationStatus = 'أداء جيد';
  String homeworkStatus = 'تم تسليم الواجب';

  @override
  void initState() {
    super.initState();
    if (!types.contains(type)) {
      type = types.first;
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
      return 'أضيفي تحديثًا مرنًا عن الطفل مع وصف واضح، ويمكنكِ إرفاق صورة أو فيديو مع التحديث.';
    }
    return 'أضيفي تحديثًا تعليميًا أو ملاحظة عن الطفل مع إمكانية إرفاق صورة أو فيديو.';
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

  String buildSuggestedNote() {
    final note = noteCtrl.text.trim();
    final extra = extraCtrl.text.trim();

    if (widget.byRole == 'nursery') {
      switch (type) {
        case 'وجبة':
          final base = mealStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'نوم':
          final base = sleepStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'حفاض':
          final base = diaperStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'صحة':
          final base = healthStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'نشاط':
          final base = activityStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        default:
          final base = noteStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';
      }
    } else {
      switch (type) {
        case 'نشاط':
          final base = activityStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'خطة اليوم':
          final base = planStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'تقييم':
          final base = evaluationStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        case 'واجب':
          final base = homeworkStatus;
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';

        default:
          final base = 'ملاحظة عامة';
          if (note.isEmpty && extra.isEmpty) return base;
          if (note.isNotEmpty && extra.isEmpty) return '$base. $note';
          if (note.isEmpty && extra.isNotEmpty) return '$base. $extra';
          return '$base. $note $extra';
      }
    }
  }

  Future<void> save() async {
    final finalNote = buildSuggestedNote().trim();

    if (finalNote.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتبي وصفًا واضحًا للتحديث'),
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
        'createdAt': now,
        'time': FieldValue.serverTimestamp(),
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'mediaType': selectedMediaType,
        'mediaPath': selectedMediaPath,
        'mediaUrl': uploadedMediaUrl,
        'hasMedia': selectedMediaPath != null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التحديث بنجاح'),
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
                onTap: () => applyQuickTemplate('تناول الطعام ببطء لكنه أكمل معظم الوجبة.'),
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
                onTap: () => applyQuickTemplate('لوحظ احمرار بسيط ويحتاج متابعة.'),
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
                onTap: () => applyQuickTemplate('تمت ملاحظة الحالة وإبلاغ ولي الأمر للمتابعة.'),
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
                onTap: () => applyQuickTemplate('شارك في نشاط الرسم والتلوين وكان سعيدًا.'),
              ),
              _QuickTextChip(
                label: 'لعب جماعي',
                onTap: () => applyQuickTemplate('شارك في اللعب الجماعي مع الأطفال.'),
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
                onTap: () => applyQuickTemplate('كان هادئًا ومتعاونًا خلال اليوم.'),
              ),
              _QuickTextChip(
                label: 'متفاعل',
                onTap: () => applyQuickTemplate('كان متفاعلًا بشكل جميل مع المحيط.'),
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
                onTap: () => applyQuickTemplate('أظهر مشاركة ممتازة وتفاعلًا واضحًا.'),
              ),
              _QuickTextChip(
                label: 'احتاج دعم',
                onTap: () => applyQuickTemplate('احتاج دعمًا بسيطًا لإتمام النشاط.'),
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
                onTap: () => applyQuickTemplate('تم تنفيذ أنشطة اليوم بشكل منظم وواضح.'),
              ),
              _QuickTextChip(
                label: 'مشاركة جيدة',
                onTap: () => applyQuickTemplate('أظهر الطفل تفاعلًا جيدًا مع خطة اليوم.'),
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
                onTap: () => applyQuickTemplate('يحتاج بعض الدعم الإضافي لتحسين أدائه.'),
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
                onTap: () => applyQuickTemplate('تم تسليم الواجب بشكل ممتاز ومنظم.'),
              ),
              _QuickTextChip(
                label: 'بحاجة إكمال',
                onTap: () => applyQuickTemplate('الواجب يحتاج بعض الإكمال أو التصحيح.'),
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
                onTap: () => applyQuickTemplate('كان متفاعلًا ومشاركًا داخل الصف.'),
              ),
              _QuickTextChip(
                label: 'يحتاج متابعة',
                onTap: () => applyQuickTemplate('يحتاج متابعة إضافية في الفترة القادمة.'),
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
          const SizedBox(height: 20),
          _buildTypeSection(context),
          const SizedBox(height: 18),
          buildDynamicFields(),
          const SizedBox(height: 18),
          _buildNoteSection(context),
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
            label: Text(isLoading ? 'جاري الإرسال...' : 'إرسال التحديث'),
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
          'اختاري النوع المناسب بشكل سريع.',
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
              hintText: 'اكتبي الوصف الأساسي للتحديث...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: extraCtrl,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'تفاصيل إضافية اختيارية...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(String previewText) {
    return _sectionCard(
      title: 'معاينة النص النهائي',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          previewText.isEmpty ? 'سيظهر النص النهائي هنا' : previewText,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            height: 1.6,
          ),
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (isVideo && !kIsWeb)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
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
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('معاينة الفيديو'),
                    ),
                  ),
                if (isVideo && kIsWeb)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'تم اختيار فيديو.\nالمعاينة المحلية غير مدعومة على Flutter Web، لكن سيتم رفع الفيديو عند الإرسال.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ),
      ],
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