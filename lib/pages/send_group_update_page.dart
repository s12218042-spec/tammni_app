import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/child_model.dart';
import '../services/app_notification_service.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'camera_checkin_page.dart';

class SendGroupUpdatePage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<ChildModel> children;
  final String byRole;

  const SendGroupUpdatePage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.children,
    this.byRole = 'nursery_staff',
  });

  @override
  State<SendGroupUpdatePage> createState() => _SendGroupUpdatePageState();
}

class _SendGroupUpdatePageState extends State<SendGroupUpdatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GalleryService _galleryService = GalleryService();

  final TextEditingController noteCtrl = TextEditingController();
  final TextEditingController extraCtrl = TextEditingController();

  bool isLoading = false;

  String updateType = 'نشاط جماعي';
  String importance = 'عادي';
  String selectedLocation = 'داخل الحضانة';

  String? selectedMediaPath;
  String? selectedMediaType;
  XFile? selectedMediaFile;
  Uint8List? selectedImageBytes;

  final Set<String> selectedChildIds = {};
  String targetScope = 'my_group'; // my_group أو all_nursery
bool isLoadingAllChildren = false;
List<ChildModel> allNurseryChildren = [];

List<ChildModel> get targetChildren {
  if (targetScope == 'all_nursery') {
    return allNurseryChildren;
  }

  return widget.children;
}

String get targetScopeLabel {
  if (targetScope == 'all_nursery') {
    return 'كل أطفال الحضانة';
  }

  return 'مجموعتي فقط';
}

  final List<String> updateTypes = const [
    'نشاط جماعي',
    'وجبة جماعية',
    'فعالية',
    'صورة جماعية',
    'فيديو جماعي',
    'إعلان',
    'ملاحظة عامة',
  ];

  @override
  void initState() {
    super.initState();

    for (final child in widget.children) {
      selectedChildIds.add(child.id);
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

  Color _importanceColor(String value) {
    switch (value) {
      case 'مهم':
        return const Color(0xFFFF9800);
      case 'عاجل':
        return const Color(0xFFE53935);
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String value) {
    switch (value) {
      case 'وجبة جماعية':
        return Icons.restaurant_outlined;
      case 'فعالية':
        return Icons.celebration_outlined;
      case 'صورة جماعية':
        return Icons.photo_library_outlined;
      case 'فيديو جماعي':
        return Icons.video_library_outlined;
      case 'إعلان':
        return Icons.campaign_outlined;
      case 'ملاحظة عامة':
        return Icons.edit_note_outlined;
      default:
        return Icons.groups_2_outlined;
    }
  }

  String _autoTitle() {
    switch (updateType) {
      case 'وجبة جماعية':
        return 'تحديث وجبة جماعية';
      case 'فعالية':
        return 'فعالية في الحضانة';
      case 'صورة جماعية':
        return 'صورة جماعية جديدة';
      case 'فيديو جماعي':
        return 'فيديو جماعي جديد';
      case 'إعلان':
        return importance == 'عاجل' ? 'إعلان عاجل' : 'إعلان من الحضانة';
      case 'ملاحظة عامة':
        return importance == 'عاجل' ? 'ملاحظة عاجلة' : 'ملاحظة عامة';
      default:
        return 'تحديث نشاط جماعي';
    }
  }

  String _formatDate(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;

    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'م' : 'ص';

    return '$hour:$minute $period';
  }

  String _buildFinalNote() {
    final now = DateTime.now();

    final parts = <String>[
      updateType,
      if (noteCtrl.text.trim().isNotEmpty) noteCtrl.text.trim(),
      if (extraCtrl.text.trim().isNotEmpty) extraCtrl.text.trim(),
      'المجموعة: ${widget.groupName}',
      'المكان: $selectedLocation',
      'الأهمية: $importance',
      'الوقت: ${_formatDate(now)} - ${_formatTime(now)}',
    ];

    return parts.join(' | ');
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

  Future<Map<String, String>> _fetchCurrentUserInfo() async {
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
        'role': _normalizeRole((data['role'] ?? widget.byRole).toString()),
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

  Future<Map<String, dynamic>> _loadFreshChildData(ChildModel child) async {
    try {
      final doc = await _firestore.collection('children').doc(child.id).get();

      if (doc.exists) {
        return doc.data() ?? <String, dynamic>{};
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Future<void> _pickMedia() async {
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

  void _removeMedia() {
    setState(() {
      selectedMediaPath = null;
      selectedMediaType = null;
      selectedMediaFile = null;
      selectedImageBytes = null;
    });
  }

  bool _validateBeforeSave() {
    if (selectedChildIds.isEmpty) {
      _showSnack('اختاري طفلًا واحدًا على الأقل');
      return false;
    }

    final note = noteCtrl.text.trim();
    final extra = extraCtrl.text.trim();

    if (note.isEmpty && extra.isEmpty && selectedMediaFile == null) {
      _showSnack('اكتبي وصفًا أو أضيفي صورة/فيديو للتحديث');
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
      childId: 'group_${widget.groupId}',
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

  Future<void> _loadAllNurseryChildrenIfNeeded() async {
  if (allNurseryChildren.isNotEmpty) return;

  setState(() {
    isLoadingAllChildren = true;
  });

  try {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Nursery')
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      final fixedData = <String, dynamic>{
        ...data,
        'section': 'Nursery',
        'group': (data['groupName'] ?? data['group'] ?? '').toString(),
        'groupName': (data['groupName'] ?? data['group'] ?? '').toString(),
      };

      return ChildModel.fromMap(fixedData, docId: doc.id);
    }).toList();

    children.sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;

    setState(() {
      allNurseryChildren = children;
    });
  } catch (e) {
    if (!mounted) return;

    _showSnack('تعذر تحميل أطفال الحضانة: $e');
  } finally {
    if (!mounted) return;

    setState(() {
      isLoadingAllChildren = false;
    });
  }
}

Future<void> _changeTargetScope(String value) async {
  if (value == targetScope) return;

  if (value == 'all_nursery') {
    await _loadAllNurseryChildrenIfNeeded();

    if (!mounted) return;

    setState(() {
      targetScope = value;
      selectedChildIds
        ..clear()
        ..addAll(allNurseryChildren.map((child) => child.id));
    });

    return;
  }

  setState(() {
    targetScope = 'my_group';
    selectedChildIds
      ..clear()
      ..addAll(widget.children.map((child) => child.id));
  });
}

  Future<void> _save() async {
    if (!_validateBeforeSave()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final availableChildren = targetChildren;

      final selectedChildren = availableChildren
         .where((child) => selectedChildIds.contains(child.id))
         .toList();

      final nowDate = DateTime.now();
      final now = Timestamp.fromDate(nowDate);
      final priority = _priorityValue(importance);
      final finalNote = _buildFinalNote();

      final userInfo = await _fetchCurrentUserInfo();
      final mediaData = await _uploadMediaIfNeeded();

      final groupUpdateRef = _firestore.collection('group_updates').doc();

      final batch = _firestore.batch();
      final pendingParentNotifications = <Map<String, dynamic>>[];
      
      batch.set(groupUpdateRef, {
        'groupUpdateId': groupUpdateRef.id,
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'targetType': targetScope,
        'targetScopeLabel': targetScopeLabel,
        'targetChildIds': selectedChildren.map((e) => e.id).toList(),
        'targetChildNames': selectedChildren.map((e) => e.name).toList(),
        'childrenCount': selectedChildren.length,
        'section': 'Nursery',
        'title': _autoTitle(),
        'type': updateType,
        'updateType': updateType,
        'category': updateType,
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
        'importance': priority,
        'priority': priority,
        'importanceLabel': importance,
        'locationLabel': selectedLocation,
        'notifyParent': true,
        ...mediaData,
      });

      for (final child in selectedChildren) {
        final freshChildData = await _loadFreshChildData(child);
        final childGroupId =
        (freshChildData['groupId'] ?? '').toString().trim();

       final childGroupName =
       (freshChildData['groupName'] ?? child.group).toString().trim();

       final resolvedGroupId = childGroupId.isNotEmpty ? childGroupId : widget.groupId;

       final resolvedGroupName = childGroupName.isNotEmpty
       ? childGroupName
       : widget.groupName;

        final parentUid =
            (freshChildData['parentUid'] ?? child.parentUid).toString().trim();

        final parentUsername =
            (freshChildData['parentUsername'] ?? child.parentUsername)
                .toString()
                .trim()
                .toLowerCase();

        final parentName =
            (freshChildData['parentName'] ?? child.parentName).toString().trim();

        final canNotifyParent =
            parentUid.isNotEmpty || parentUsername.isNotEmpty;

        final updateRef = _firestore.collection('updates').doc();
        

        final updateData = {
          'updateId': updateRef.id,
          'groupUpdateId': groupUpdateRef.id,
          'isGroupUpdate': true,
          'childId': child.id,
          'childName': child.name,
          'parentUid': parentUid,
          'parentUsername': parentUsername,
          'parentName': parentName,
          'section': 'Nursery',
          'groupId': resolvedGroupId,
          'groupName': resolvedGroupName,
          'group': resolvedGroupName,
          'targetScope': targetScope,
          'targetScopeLabel': targetScopeLabel,
          'type': updateType,
          'updateType': updateType,
          'category': updateType,
          'title': _autoTitle(),
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
          'importance': priority,
          'priority': priority,
          'importanceLabel': importance,
          'locationLabel': selectedLocation,
          'notifyParent': canNotifyParent,
          ...mediaData,
        };

        batch.set(updateRef, updateData);

        if (canNotifyParent) {
  pendingParentNotifications.add({
    'parentUid': parentUid,
    'parentUsername': parentUsername,
    'parentName': parentName,
    'childId': child.id,
    'childName': child.name,
    'section': 'Nursery',
    'groupId': resolvedGroupId,
    'groupName': resolvedGroupName,
    'group': resolvedGroupName,
    'targetScope': targetScope,
    'targetScopeLabel': targetScopeLabel,
    'title': _autoTitle(),
    'body': finalNote,
    'type': 'group_update',
    'updateId': updateRef.id,
    'groupUpdateId': groupUpdateRef.id,
    'isGroupUpdate': true,
    'category': updateType,
    'templateType': updateType,
    'priority': priority,
    'importance': priority,
    'importanceLabel': importance,
    'createdByUid': userInfo['uid'] ?? '',
    'createdByName': userInfo['name'] ?? '',
    'createdByRole': userInfo['role'] ?? 'nursery_staff',
    'senderUid': userInfo['uid'] ?? '',
    'senderName': userInfo['name'] ?? '',
    'senderRole': userInfo['role'] ?? 'nursery_staff',
    ...mediaData,
  });
}
      }

      await batch.commit();

for (final item in pendingParentNotifications) {
  try {
    await AppNotificationService.instance.notifyParent(
      parentUid: (item['parentUid'] ?? '').toString(),
      parentUsername: (item['parentUsername'] ?? '').toString(),
      parentName: (item['parentName'] ?? '').toString(),
      title: (item['title'] ?? 'تحديث جماعي جديد').toString(),
      body: (item['body'] ?? '').toString(),
      type: 'group_update',
      childId: (item['childId'] ?? '').toString(),
      childName: (item['childName'] ?? '').toString(),
      section: (item['section'] ?? 'Nursery').toString(),
      group: (item['group'] ?? '').toString(),
      priority: (item['priority'] ?? 'normal').toString(),
      createdByUid: (item['createdByUid'] ?? '').toString(),
      createdByName: (item['createdByName'] ?? '').toString(),
      createdByRole: (item['createdByRole'] ?? 'nursery_staff').toString(),
      extraData: {
        'uid': (item['parentUid'] ?? '').toString(),
        'receiverUid': (item['parentUid'] ?? '').toString(),
        'receiverUsername': (item['parentUsername'] ?? '').toString(),
        'receiverRole': 'parent',
        'groupId': (item['groupId'] ?? '').toString(),
        'groupName': (item['groupName'] ?? '').toString(),
        'targetScope': (item['targetScope'] ?? '').toString(),
        'targetScopeLabel': (item['targetScopeLabel'] ?? '').toString(),
        'notificationType': 'group_update',
        'category': (item['category'] ?? '').toString(),
        'templateType': (item['templateType'] ?? '').toString(),
        'updateId': (item['updateId'] ?? '').toString(),
        'groupUpdateId': (item['groupUpdateId'] ?? '').toString(),
        'isGroupUpdate': true,
        'importance': (item['importance'] ?? 'normal').toString(),
        'importanceLabel': (item['importanceLabel'] ?? '').toString(),
        'senderUid': (item['senderUid'] ?? '').toString(),
        'senderName': (item['senderName'] ?? '').toString(),
        'senderRole': (item['senderRole'] ?? '').toString(),
        'screen': 'notifications',
      },
    );
  } catch (e) {
    debugPrint('SendGroupUpdatePage: فشل إرسال push للتحديث الجماعي: $e');
  }
}

if (!mounted) return;

      _showSnack(
        'تم إرسال التحديث الجماعي إلى ${selectedChildren.length} طفل/أطفال',
        backgroundColor: Colors.green,
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('حدث خطأ أثناء إرسال التحديث الجماعي: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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

  Widget _buildHeader() {
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
              _typeIcon(updateType),
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'تحديث جماعي - ${widget.groupName}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSection() {
    return _sectionCard(
      title: 'نوع التحديث',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: updateTypes.map((item) {
          final selected = updateType == item;

          return FilterChip(
            selected: selected,
            label: Text(item),
            avatar: Icon(
              _typeIcon(item),
              size: 18,
              color: selected ? AppColors.primary : AppColors.textLight,
            ),
            onSelected: (_) {
              setState(() {
                updateType = item;
              });
            },
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
          final color = _importanceColor(item);

          return FilterChip(
            selected: selected,
            label: Text(item),
            onSelected: (_) {
              setState(() {
                importance = item;
              });
            },
            selectedColor: color.withOpacity(0.14),
            checkmarkColor: color,
            labelStyle: TextStyle(
              color: selected ? color : AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected ? color : AppColors.border.withOpacity(0.9),
            ),
            backgroundColor: Colors.white,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTargetScopeSection() {
  return _sectionCard(
    title: 'نطاق الإرسال',
    child: Column(
      children: [
        RadioListTile<String>(
          value: 'my_group',
          groupValue: targetScope,
          onChanged: isLoading || isLoadingAllChildren
              ? null
              : (value) {
                  if (value != null) {
                    _changeTargetScope(value);
                  }
                },
          title: const Text(
            'مجموعتي فقط',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            widget.groupName,
            style: const TextStyle(color: AppColors.textLight),
          ),
        ),
        RadioListTile<String>(
          value: 'all_nursery',
          groupValue: targetScope,
          onChanged: isLoading || isLoadingAllChildren
              ? null
              : (value) {
                  if (value != null) {
                    _changeTargetScope(value);
                  }
                },
          title: const Text(
            'كل أطفال الحضانة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'سيصل التحديث لكل أولياء أمور الأطفال النشطين في الحضانة',
            style: TextStyle(color: AppColors.textLight),
          ),
        ),
        if (isLoadingAllChildren) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
      ],
    ),
  );
}

  Widget _buildChildrenSection() {
  final children = targetChildren;

  return _sectionCard(
    title: 'الأطفال المستهدفون',
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'تم اختيار ${selectedChildIds.length} من ${children.length} - $targetScopeLabel',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (selectedChildIds.length == children.length) {
                    selectedChildIds.clear();
                  } else {
                    selectedChildIds
                      ..clear()
                      ..addAll(children.map((e) => e.id));
                  }
                });
              },
              icon: const Icon(Icons.done_all_rounded),
              label: Text(
                selectedChildIds.length == children.length
                    ? 'إلغاء تحديد الكل'
                    : 'تحديد الكل',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'لا يوجد أطفال في هذا النطاق.',
              style: TextStyle(color: AppColors.textLight),
            ),
          )
        else
          ...children.map((child) {
            final selected = selectedChildIds.contains(child.id);

            return CheckboxListTile(
              value: selected,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                child.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  if (child.group.trim().isNotEmpty) child.group,
                  if (child.parentName.trim().isNotEmpty)
                    'ولي الأمر: ${child.parentName}',
                ].join(' • ').trim().isEmpty
                    ? 'ولي أمر غير محدد'
                    : [
                        if (child.group.trim().isNotEmpty) child.group,
                        if (child.parentName.trim().isNotEmpty)
                          'ولي الأمر: ${child.parentName}',
                      ].join(' • '),
              ),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    selectedChildIds.add(child.id);
                  } else {
                    selectedChildIds.remove(child.id);
                  }
                });
              },
            );
          }),
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
              hintText: 'مثال: شارك الأطفال اليوم في نشاط الرسم الجماعي',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
            onChanged: (_) => setState(() {}),
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
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final now = DateTime.now();

    return _sectionCard(
      title: 'الوقت والمكان',
      child: Row(
        children: [
          Expanded(
            child: _MiniInfoCard(
              icon: Icons.access_time_rounded,
              title: 'وقت التحديث',
              value: '${_formatDate(now)} - ${_formatTime(now)}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniInfoCard(
              icon: Icons.place_outlined,
              title: 'المكان',
              value: selectedLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    final hasMedia = selectedMediaPath != null && selectedMediaType != null;
    final isImage = selectedMediaType == 'image';
    final isVideo = selectedMediaType == 'video';

    return _sectionCard(
      title: 'صورة أو فيديو جماعي',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: isLoading ? null : _pickMedia,
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
                        onPressed: isLoading ? null : _removeMedia,
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

  Widget _buildPreviewSection() {
    final previewText = _buildFinalNote();

    return _sectionCard(
      title: 'معاينة التحديث',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _importanceColor(importance).withOpacity(0.20),
          ),
        ),
        child: Text(
          previewText,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            height: 1.7,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تحديث جماعي',
      child: ListView(
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildTypeSection(),
          const SizedBox(height: 18),
          _buildImportanceSection(),
          const SizedBox(height: 18),
          _buildTargetScopeSection(),
          const SizedBox(height: 18),
          _buildChildrenSection(),
          const SizedBox(height: 18),
          _buildLocationSection(),
          const SizedBox(height: 18),
          _buildNoteSection(),
          const SizedBox(height: 18),
          _buildMediaSection(),
          const SizedBox(height: 18),
          _buildPreviewSection(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _save,
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
            label: Text(isLoading ? 'جاري الإرسال...' : 'إرسال التحديث الجماعي'),
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
}

class _MiniInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MiniInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
}