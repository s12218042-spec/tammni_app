import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'camera_checkin_page.dart';

class AddUpdatePage extends StatefulWidget {
  final ChildModel child;
  final String byRole;

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GalleryService _galleryService = GalleryService();

  String type = 'ملاحظة';
  bool isLoading = false;

  String? selectedMediaPath;
  String? selectedMediaType;
  XFile? selectedMediaFile;
  Uint8List? selectedImageBytes;

  String mealStatus = 'تناول الوجبة جيدًا';
  String sleepStatus = 'نام جيدًا';
  String diaperStatus = 'تم التبديل';
  String healthStatus = 'حالته مستقرة';
  String activityStatus = 'شارك بالنشاط';

  String importance = 'عادي';
  String selectedMood = '😊';
  String selectedEnergy = 'متوسط';
  String selectedLocation = 'داخل الحضانة';

  final Set<String> selectedActivityDetails = {};

  final List<String> nurseryTypes = const [
    'وجبة',
    'نوم',
    'حفاض',
    'صحة',
    'نشاط',
    'ملاحظة',
  ];

  final List<String> activityDetailsOptions = const [
    'رسم',
    'تلوين',
    'لعب جماعي',
    'قصة',
    'موسيقى',
    'تركيب مكعبات',
    'نشاط حركي',
  ];

  @override
  void initState() {
    super.initState();

    if (!nurseryTypes.contains(type)) {
      type = nurseryTypes.first;
    }
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    extraCtrl.dispose();
    super.dispose();
  }

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    if (role == 'admin') return 'admin';
    if (role == 'parent') return 'parent';

    return role.isEmpty ? 'nursery_staff' : role;
  }

  String _priorityValue(String value) {
    switch (value.trim()) {
      case 'عاجل':
        return 'urgent';
      case 'مهم':
        return 'important';
      default:
        return 'normal';
    }
  }

  String sectionLabel(String section) {
    return 'حضانة';
  }

  String roleLabel() {
    return 'موظفة الحضانة';
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

  void _showSnack(
    String message, {
    Color backgroundColor = Colors.redAccent,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {
        'uid': '',
        'name': 'مستخدم غير معروف',
        'role': 'nursery_staff',
      };
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      final data = userDoc.data() ?? <String, dynamic>{};

      final roleFromUser = (data['role'] ?? widget.byRole).toString();

      return {
        'uid': currentUser.uid,
        'name': (data['displayName'] ??
                data['name'] ??
                data['fullName'] ??
                data['username'] ??
                currentUser.displayName ??
                'مستخدم')
            .toString()
            .trim(),
        'role': _normalizeRole(roleFromUser),
      };
    } catch (_) {
      return {
        'uid': currentUser.uid,
        'name': currentUser.displayName?.trim().isNotEmpty == true
            ? currentUser.displayName!.trim()
            : 'مستخدم',
        'role': _normalizeRole(widget.byRole),
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

        if (docParentUid.isNotEmpty) parentUid = docParentUid;
        if (docParentUsername.isNotEmpty) parentUsername = docParentUsername;
        if (docParentName.isNotEmpty) parentName = docParentName;
      }
    } catch (_) {}

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
    };
  }

  Future<void> pickMedia() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraCheckinPage(),
      ),
    );

    if (res is! Map) return;

    final path = res['path'] as String?;
    final mediaType = res['type'] as String?;
    final file = res['file'] as XFile?;
    final description = (res['description'] ?? '').toString().trim();

    if (path == null || path.trim().isEmpty || mediaType == null) return;

    Uint8List? bytes;

    if (mediaType == 'image' && file != null) {
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }

    if (!mounted) return;

    setState(() {
      selectedMediaPath = path;
      selectedMediaType = mediaType;
      selectedMediaFile = file;
      selectedImageBytes = bytes;

      if (description.isNotEmpty && noteCtrl.text.trim().isEmpty) {
        noteCtrl.text = description;
      }
    });
  }

  void removeMedia() {
    setState(() {
      selectedMediaPath = null;
      selectedMediaType = null;
      selectedMediaFile = null;
      selectedImageBytes = null;
    });
  }

  void toggleActivityDetail(String value) {
    setState(() {
      if (selectedActivityDetails.contains(value)) {
        selectedActivityDetails.remove(value);
      } else {
        selectedActivityDetails.add(value);
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
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String autoTitle() {
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
        return importance == 'عاجل' ? 'ملاحظة عاجلة' : 'ملاحظة';
    }
  }

  String _baseStatusText() {
    switch (type) {
      case 'وجبة':
        return mealStatus;
      case 'نوم':
        return sleepStatus;
      case 'حفاض':
        return diaperStatus;
      case 'صحة':
        return healthStatus;
      case 'نشاط':
        final details = selectedActivityDetails.isEmpty
            ? ''
            : 'تفاصيل النشاط: ${selectedActivityDetails.join('، ')}';
        return [
          activityStatus,
          if (details.isNotEmpty) details,
        ].join(' - ');
      default:
        return '';
    }
  }

  String buildFinalNote() {
    final base = _baseStatusText();
    final note = noteCtrl.text.trim();
    final extra = extraCtrl.text.trim();

    final now = DateTime.now();

    final parts = <String>[
      if (base.isNotEmpty) base,
      if (note.isNotEmpty) note,
      if (extra.isNotEmpty) extra,
      'المزاج: $selectedMood',
      'النشاط: $selectedEnergy',
      'المكان: $selectedLocation',
      'الأهمية: $importance',
      'الوقت: ${formatDate(now)} - ${formatTime(now)}',
    ];

    return parts.join(' | ');
  }

  bool _validateBeforeSave() {
    final note = noteCtrl.text.trim();
    final extra = extraCtrl.text.trim();
    final hasStructuredType = type != 'ملاحظة';

    if (!hasStructuredType && note.isEmpty && extra.isEmpty) {
      _showSnack('يرجى كتابة وصف للتحديث');
      return false;
    }

    if (type == 'نشاط' && selectedActivityDetails.isEmpty) {
      _showSnack('يرجى اختيار تفاصيل النشاط');
      return false;
    }

    if (note.isNotEmpty && note.length < 3) {
      _showSnack('وصف التحديث قصير جدًا');
      return false;
    }

    return true;
  }

  Future<Map<String, dynamic>> _uploadMediaIfNeeded() async {
    if (selectedMediaType == null ||
        selectedMediaType!.trim().isEmpty ||
        selectedMediaFile == null) {
      return {
        'mediaType': '',
        'mediaPath': '',
        'mediaUrl': '',
        'mediaUrlExpiresAt': '',
        'storageProvider': '',
        'bucket': '',
        'mimeType': '',
        'sizeBytes': 0,
        'hasMedia': false,
      };
    }

    final uploaded = await _galleryService.uploadChildMediaDetailed(
      childId: widget.child.id,
      file: selectedMediaFile!,
      mediaType: selectedMediaType!,
    );

    if (uploaded == null) {
      throw Exception('فشل رفع الوسائط');
    }

    return {
      ...uploaded.toMap(),
      'hasMedia': true,
    };
  }

  Future<void> save() async {
    if (!_validateBeforeSave()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final nowDate = DateTime.now();
      final now = Timestamp.fromDate(nowDate);
      final priority = _priorityValue(importance);
      final finalNote = buildFinalNote();

      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();
      final mediaData = await _uploadMediaIfNeeded();

      final parentUid = (parentInfo['parentUid'] ?? '').trim();
      final parentUsername =
          (parentInfo['parentUsername'] ?? '').trim().toLowerCase();
      final parentName = (parentInfo['parentName'] ?? '').trim();

      final canNotifyParent = parentUid.isNotEmpty || parentUsername.isNotEmpty;

      final updateRef = _firestore.collection('updates').doc();
      final notificationRef = _firestore.collection('notifications').doc();

      final updateData = {
        'updateId': updateRef.id,
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUid': parentUid,
        'parentUsername': parentUsername,
        'parentName': parentName,
        'section': 'Nursery',
        'group': widget.child.group,
        'type': type,
        'updateType': type,
        'category': type,
        'title': autoTitle(),
        'note': finalNote,
        'message': finalNote,
        'description': finalNote,
        'createdAt': now,
        'time': now,
        'eventAt': now,
        'updatedAt': now,
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'senderUid': userInfo['uid'],
        'senderName': userInfo['name'],
        'senderRole': userInfo['role'],
        ...mediaData,
        'importance': priority,
        'priority': priority,
        'importanceLabel': importance,
        'mood': selectedMood,
        'energy': selectedEnergy,
        'locationLabel': selectedLocation,
        'activityStatus': activityStatus,
        'activityDetails': selectedActivityDetails.toList(),
        'mealStatus': mealStatus,
        'sleepStatus': sleepStatus,
        'diaperStatus': diaperStatus,
        'healthStatus': healthStatus,
        'notifyParent': canNotifyParent,
      };

      final notificationData = {
        'notificationId': notificationRef.id,
        'uid': parentUid,
        'targetUid': parentUid,
        'targetUsername': parentUsername,
        'targetRole': 'parent',
        'receiverUid': parentUid,
        'receiverUsername': parentUsername,
        'receiverRole': 'parent',
        'parentUid': parentUid,
        'parentUsername': parentUsername,
        'parentName': parentName,
        'childId': widget.child.id,
        'childName': widget.child.name,
        'section': 'Nursery',
        'group': widget.child.group,
        'title': autoTitle(),
        'body': finalNote,
        'message': finalNote,
        'description': finalNote,
        'type': 'update_notification',
        'notificationType': 'update_notification',
        'category': type,
        'templateType': type,
        'updateId': updateRef.id,
        'isRead': false,
        'read': false,
        'seen': false,
        'createdAt': now,
        'time': now,
        'eventAt': now,
        'updatedAt': now,
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'byRole': userInfo['role'],
        'senderUid': userInfo['uid'],
        'senderName': userInfo['name'],
        'senderRole': userInfo['role'],
        'priority': priority,
        'importance': priority,
        'importanceLabel': importance,
        ...mediaData,
      };

      final batch = _firestore.batch();

      batch.set(updateRef, updateData);

      if (canNotifyParent) {
        batch.set(notificationRef, notificationData);
      }

      await batch.commit();

      if (!mounted) return;

      _showSnack(
        canNotifyParent
            ? 'تم إضافة التحديث وإشعار ولي الأمر'
            : 'تم إضافة التحديث، لكن لم يتم العثور على بيانات ولي الأمر للإشعار',
        backgroundColor: Colors.green,
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('حدث خطأ أثناء حفظ التحديث: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildDynamicFields() {
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
        return const SizedBox.shrink();
    }
  }

  Widget _buildNurseryMealFields() {
    return _sectionCard(
      title: 'تفاصيل الوجبة',
      child: _ChoiceWrap(
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
    );
  }

  Widget _buildNurserySleepFields() {
    return _sectionCard(
      title: 'تفاصيل النوم',
      child: _ChoiceWrap(
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
    );
  }

  Widget _buildNurseryDiaperFields() {
    return _sectionCard(
      title: 'تفاصيل الحفاض',
      child: _ChoiceWrap(
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
    );
  }

  Widget _buildNurseryHealthFields() {
    return _sectionCard(
      title: 'تفاصيل الحالة الصحية',
      child: _ChoiceWrap(
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
    );
  }

  Widget _buildNurseryActivityFields() {
    return _sectionCard(
      title: 'تفاصيل النشاط',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activityDetailsOptions.map((item) {
              final selected = selectedActivityDetails.contains(item);

              return FilterChip(
                selected: selected,
                label: Text(item),
                onSelected: (_) => toggleActivityDetail(item),
                selectedColor: AppColors.primary.withOpacity(0.14),
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

  @override
  Widget build(BuildContext context) {
    final hasMedia = selectedMediaPath != null && selectedMediaType != null;
    final previewText = buildFinalNote();

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
          _buildTimeAndLocationSection(),
          const SizedBox(height: 18),
          _buildStatusSection(),
          const SizedBox(height: 18),
          buildDynamicFields(),
          const SizedBox(height: 18),
          _buildNoteSection(),
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
            child: Text(
              'إضافة تحديث جديد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
    return _sectionCard(
      title: 'نوع التحديث',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: nurseryTypes.map((item) {
          final selected = type == item;
          final color = typeColor(item);

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                type = item;

                if (type != 'نشاط') {
                  selectedActivityDetails.clear();
                }
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
                    typeIcon(item),
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

  Widget _buildTimeAndLocationSection() {
    final now = DateTime.now();

    return _sectionCard(
      title: 'الوقت والمكان',
      child: Row(
        children: [
          Expanded(
            child: _miniInfoCard(
              icon: Icons.access_time_rounded,
              title: 'وقت التحديث',
              value: '${formatDate(now)} - ${formatTime(now)}',
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

  Widget _buildNoteSection() {
    return _sectionCard(
      title: 'وصف التحديث',
      child: Column(
        children: [
          TextField(
            controller: noteCtrl,
            maxLines: 4,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'اكتبي تفاصيل التحديث',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: extraCtrl,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'تفاصيل إضافية اختيارية',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            onChanged: (_) {
              setState(() {});
            },
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
              previewText,
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

    return _sectionCard(
      title: 'مرفق',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: isLoading ? null : pickMedia,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(hasMedia ? 'تغيير المرفق' : 'إضافة صورة أو فيديو'),
          ),
          if (hasMedia) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
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
                        onPressed: isLoading ? null : removeMedia,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (isImage && selectedImageBytes != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        selectedImageBytes!,
                        width: double.infinity,
                        height: 190,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if (isVideo) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'الفيديو جاهز للإرسال',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
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

        return FilterChip(
          selected: selected,
          label: Text(value),
          onSelected: (_) => onSelected(value),
          selectedColor: AppColors.primary.withOpacity(0.14),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(
            color:
                selected ? AppColors.primary : AppColors.border.withOpacity(0.9),
          ),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }
}