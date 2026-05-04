import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class IncidentReportPage extends StatefulWidget {
  final ChildModel child;

  const IncidentReportPage({
    super.key,
    required this.child,
  });

  @override
  State<IncidentReportPage> createState() => _IncidentReportPageState();
}

class _IncidentReportPageState extends State<IncidentReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  final GalleryService _galleryService = GalleryService();

  final TextEditingController detailsCtrl = TextEditingController();
  final TextEditingController actionCtrl = TextEditingController();
  final TextEditingController otherLocationCtrl = TextEditingController();

  String incidentType = 'سقوط بسيط';
  String priority = 'important';
  String incidentPlace = 'الصف';

  bool isSaving = false;

  XFile? selectedImage;
  Uint8List? selectedImageBytes;

  final List<String> placeOptions = const [
    'الصف',
    'ساحة اللعب',
    'غرفة النوم',
    'الحمام',
    'غرفة الطعام',
    'الممر',
    'المدخل',
    'الباص',
    'مكان آخر',
  ];

  final List<String> incidentTypes = const [
    'سقوط بسيط',
    'اصطدام',
    'جرح',
    'وعكة صحية',
    'حادث آخر',
  ];

  @override
  void dispose() {
    detailsCtrl.dispose();
    actionCtrl.dispose();
    otherLocationCtrl.dispose();
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

  String get finalIncidentPlace {
    if (incidentPlace == 'مكان آخر') {
      final text = otherLocationCtrl.text.trim();
      return text.isEmpty ? 'مكان آخر' : text;
    }

    return incidentPlace;
  }

  String autoAnalyzeRisk() {
    final text = detailsCtrl.text.trim();

    if (text.contains('دم') ||
        text.contains('كسر') ||
        text.contains('نزيف') ||
        text.contains('إغماء') ||
        text.contains('اختناق') ||
        text.contains('صعوبة تنفس')) {
      return 'urgent';
    }

    if (text.contains('بكاء') ||
        text.contains('سقوط') ||
        text.contains('اصطدام') ||
        text.contains('جرح') ||
        text.contains('تورم')) {
      return 'important';
    }

    return 'normal';
  }

  String riskLabel(String value) {
    switch (value) {
      case 'urgent':
        return 'عاجل';
      case 'important':
        return 'مهم';
      case 'normal':
      default:
        return 'عادي';
    }
  }

  Color riskColor(String value) {
    switch (value) {
      case 'urgent':
        return Colors.red;
      case 'important':
        return Colors.orange;
      case 'normal':
      default:
        return Colors.green;
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
        'role': _normalizeRole((data['role'] ?? 'nursery_staff').toString()),
      };
    } catch (_) {
      return {
        'uid': currentUser.uid,
        'name': currentUser.displayName?.trim().isNotEmpty == true
            ? currentUser.displayName!.trim()
            : 'مستخدم',
        'role': 'nursery_staff',
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

  Future<void> pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedImage = picked;
        selectedImageBytes = bytes;
      });
    } catch (e) {
      _showSnack('تعذر التقاط الصورة: $e');
    }
  }

  void removeImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
    });
  }



  Future<Map<String, dynamic>> _uploadIncidentImageIfNeeded() async {
    if (selectedImage == null) {
      return {
        'hasImage': false,
        'hasMedia': false,
        'imagePath': '',
        'imageUrl': '',
        'imageType': '',
        'mediaPath': '',
        'mediaUrl': '',
        'mediaType': '',
        'storageProvider': '',
        'bucket': '',
        'mimeType': '',
        'sizeBytes': 0,
      };
    }

    final uploaded = await _galleryService.uploadChildMediaDetailed(
      childId: widget.child.id,
      file: selectedImage!,
      mediaType: 'image',
    );

    if (uploaded == null) {
      throw Exception('فشل رفع صورة الحادث');
    }

    return {
      'hasImage': true,
      'hasMedia': true,
      'imagePath': uploaded.path,
      'imageUrl': uploaded.signedUrl,
      'imageType': 'image',
      'mediaPath': uploaded.path,
      'mediaUrl': uploaded.signedUrl,
      'mediaType': 'image',
      'storageProvider': uploaded.storageProvider,
      'bucket': uploaded.bucket,
      'mimeType': uploaded.mimeType,
      'sizeBytes': uploaded.sizeBytes,
    };
  }

 String _buildIncidentSummary({
  required String autoRisk,
}) {
  final details = detailsCtrl.text.trim();
  final action = actionCtrl.text.trim();

  final parts = <String>[
    'نوع الحادث: $incidentType',
    'المكان: $finalIncidentPlace',
    'درجة الخطورة: ${riskLabel(autoRisk)}',
    'الأولوية: ${riskLabel(priority)}',
    if (details.isNotEmpty) 'التفاصيل: $details',
    if (action.isNotEmpty) 'الإجراء المتخذ: $action',
  ];

  return parts.join(' | ');
}

  bool _validateIncident() {
    final details = detailsCtrl.text.trim();
    final action = actionCtrl.text.trim();

    if (details.isEmpty) {
      _showSnack('يرجى كتابة تفاصيل الحادث');
      return false;
    }

    if (details.length < 5) {
      _showSnack('تفاصيل الحادث قصيرة جدًا');
      return false;
    }

    if (action.isEmpty) {
      _showSnack('يرجى كتابة الإجراء المتخذ');
      return false;
    }

    if (incidentPlace == 'مكان آخر' && otherLocationCtrl.text.trim().isEmpty) {
      _showSnack('يرجى تحديد مكان الحادث');
      return false;
    }

    return true;
  }

  Future<void> saveIncident() async {
    if (!_validateIncident()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final autoRisk = autoAnalyzeRisk();
      final now = Timestamp.now();
      final finalSummary = _buildIncidentSummary(autoRisk: autoRisk);

      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();
      final imageData = await _uploadIncidentImageIfNeeded();

      final parentUid = (parentInfo['parentUid'] ?? '').trim();
      final parentUsername =
          (parentInfo['parentUsername'] ?? '').trim().toLowerCase();
      final parentName = (parentInfo['parentName'] ?? '').trim();

      final canNotifyParent = parentUid.isNotEmpty || parentUsername.isNotEmpty;

      final reportRef = _firestore.collection('incident_reports').doc();
      final notificationRef = _firestore.collection('notifications').doc();

      final batch = _firestore.batch();

      batch.set(reportRef, {
        'reportId': reportRef.id,
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUid': parentUid,
        'parentUsername': parentUsername,
        'parentName': parentName,
        'section': 'Nursery',
        'group': widget.child.group,
        'title': 'تقرير حادث',
        'type': 'incident_report',
        'reportType': 'incident_report',
        'category': 'incident_report',
        'incidentType': incidentType,
        'priority': priority,
        'importance': priority,
        'autoRisk': autoRisk,
        'status': 'new',
        'statusLabel': 'جديد',
        'incidentPlace': finalIncidentPlace,
        'locationLabel': finalIncidentPlace,
        'details': detailsCtrl.text.trim(),
        'note': finalSummary,
        'message': finalSummary,
        'description': finalSummary,
        'actionTaken': actionCtrl.text.trim(),
        'parentNotified': canNotifyParent,
        'notifyParent': canNotifyParent,
        ...imageData,
        'createdAt': now,
        'time': now,
        'eventAt': now,
        'updatedAt': now,
        'reviewedAt': null,
        'byRole': userInfo['role'],
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'senderUid': userInfo['uid'],
        'senderName': userInfo['name'],
        'senderRole': userInfo['role'],
      });

      if (canNotifyParent) {
        batch.set(notificationRef, {
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
          'title': autoRisk == 'urgent' || priority == 'urgent'
              ? 'تنبيه عاجل بخصوص حادث'
              : 'تقرير حادث جديد',
          'body': finalSummary,
          'message': finalSummary,
          'description': finalSummary,
          'type': 'incident_report',
          'notificationType': 'incident_report',
          'category': 'incident_report',
          'templateType': 'incident_report',
          'reportId': reportRef.id,
          'incidentReportId': reportRef.id,
          'incidentType': incidentType,
          'priority': priority,
          'importance': priority,
          'autoRisk': autoRisk,
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
          ...imageData,
        });
      }

      await batch.commit();

      if (!mounted) return;

      _showSnack(
        canNotifyParent
            ? 'تم حفظ التقرير وإشعار ولي الأمر'
            : 'تم حفظ التقرير، لكن لم يتم العثور على بيانات ولي الأمر للإشعار',
        backgroundColor: Colors.green,
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('حدث خطأ أثناء حفظ التقرير: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });
    }
  }

  InputDecoration _inputDecoration({
    String? label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _imagePreview() {
    if (selectedImageBytes == null) {
      return Container(
        height: 150,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 38,
          color: Colors.grey.shade500,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        selectedImageBytes!,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: Colors.grey.shade500,
            ),
          );
        },
      ),
    );
  }

  Widget _card(String title, IconData icon, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autoRisk = autoAnalyzeRisk();

    return AppPageScaffold(
      title: 'تقرير حادث',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: riskColor(autoRisk).withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: riskColor(autoRisk).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: riskColor(autoRisk)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'درجة الخطورة: ${riskLabel(autoRisk)}',
                    style: TextStyle(
                      color: riskColor(autoRisk),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _card(
            'مكان الحادث',
            Icons.location_on_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: incidentPlace,
                  decoration: _inputDecoration(
                    hint: 'اختاري مكان الحادث',
                  ),
                  items: placeOptions
                      .map(
                        (place) => DropdownMenuItem<String>(
                          value: place,
                          child: Text(place),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      incidentPlace = value;

                      if (incidentPlace != 'مكان آخر') {
                        otherLocationCtrl.clear();
                      }
                    });
                  },
                ),
                if (incidentPlace == 'مكان آخر') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otherLocationCtrl,
                    decoration: _inputDecoration(
                      label: 'تحديد المكان',
                      hint: 'اكتبي مكان الحادث',
                      icon: Icons.edit_location_alt_outlined,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _card(
            'صورة الحادث',
            Icons.camera_alt_outlined,
            child: Column(
              children: [
                _imagePreview(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : pickImage,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(
                          selectedImage == null ? 'التقاط صورة' : 'تغيير الصورة',
                        ),
                      ),
                    ),
                    if (selectedImage != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSaving ? null : removeImage,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف الصورة'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _card(
            'نوع الحادث',
            Icons.report_problem_outlined,
            child: DropdownButtonFormField<String>(
              value: incidentType,
              decoration: _inputDecoration(
                hint: 'اختاري نوع الحادث',
              ),
              items: incidentTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  incidentType = value;
                });
              },
            ),
          ),
          _card(
            'تفاصيل الحادث',
            Icons.description_outlined,
            child: TextField(
              controller: detailsCtrl,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint: 'اكتبي تفاصيل الحادث',
              ),
            ),
          ),
          _card(
            'الإجراء المتخذ',
            Icons.medical_services_outlined,
            child: TextField(
              controller: actionCtrl,
              maxLines: 3,
              decoration: _inputDecoration(
                hint: 'اكتبي الإجراء الذي تم اتخاذه',
              ),
            ),
          ),
         
          _card(
            'أولوية التقرير',
            Icons.priority_high_outlined,
            child: DropdownButtonFormField<String>(
              value: priority,
              decoration: _inputDecoration(
                hint: 'اختاري الأولوية',
              ),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('عادي')),
                DropdownMenuItem(value: 'important', child: Text('مهم')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  priority = value;
                });
              },
            ),
          ),
         
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: isSaving ? null : saveIncident,
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
            label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التقرير'),
            style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 54),
            ),
          ),
        ],
      ),
    );
  }
}