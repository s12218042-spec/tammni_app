import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  final TextEditingController witnessCtrl = TextEditingController();
  final TextEditingController otherLocationCtrl = TextEditingController();

  String incidentType = 'سقوط بسيط';
  String priority = 'important';
  String status = 'new';
  String incidentPlace = 'الصف';

  bool parentNotified = false;
  bool isSaving = false;

  List<String> witnesses = [];
  XFile? selectedImage;

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

  @override
  void dispose() {
    detailsCtrl.dispose();
    actionCtrl.dispose();
    witnessCtrl.dispose();
    otherLocationCtrl.dispose();
    super.dispose();
  }

  String autoAnalyzeRisk() {
    final text = detailsCtrl.text.trim();

    if (text.contains('دم') || text.contains('كسر')) {
      return 'urgent';
    }
    if (text.contains('بكاء') || text.contains('سقوط')) {
      return 'important';
    }
    return 'normal';
  }

  String riskLabel(String p) {
    if (p == 'urgent') return 'عاجل';
    if (p == 'important') return 'مهم';
    return 'عادي';
  }

  Color riskColor(String p) {
    if (p == 'urgent') return Colors.red;
    if (p == 'important') return Colors.orange;
    return Colors.green;
  }

  String get finalIncidentPlace {
    if (incidentPlace == 'مكان آخر') {
      final text = otherLocationCtrl.text.trim();
      return text.isEmpty ? 'مكان آخر' : text;
    }
    return incidentPlace;
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
      'name': (data['displayName'] ??
              data['name'] ??
              data['username'] ??
              'مستخدم')
          .toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  Future<Map<String, String>> fetchParentLinkInfo() async {
    String parentUid = '';
    String parentUsername = widget.child.parentUsername.trim().toLowerCase();

    try {
      final childDoc =
          await _firestore.collection('children').doc(widget.child.id).get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? <String, dynamic>{};

        parentUid = (data['parentUid'] ?? '').toString().trim();

        final docParentUsername =
            (data['parentUsername'] ?? '').toString().trim().toLowerCase();

        if (docParentUsername.isNotEmpty) {
          parentUsername = docParentUsername;
        }
      }
    } catch (_) {
      // fallback
    }

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
    };
  }

  Future<void> pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );

      if (picked != null) {
        setState(() {
          selectedImage = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التقاط الصورة: $e')),
      );
    }
  }

  void addWitness() {
    final value = witnessCtrl.text.trim();
    if (value.isEmpty) return;

    setState(() {
      if (!witnesses.contains(value)) {
        witnesses.add(value);
      }
      witnessCtrl.clear();
    });
  }

  Future<Map<String, dynamic>> _uploadIncidentImageIfNeeded() async {
    if (selectedImage == null) {
      return {
        'hasImage': false,
        'imagePath': '',
        'imageUrl': null,
        'imageType': null,
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
      'imagePath': uploaded.path,
      'imageUrl': uploaded.signedUrl,
      'imageType': 'image',
      'storageProvider': uploaded.storageProvider,
      'bucket': uploaded.bucket,
      'mimeType': uploaded.mimeType,
      'sizeBytes': uploaded.sizeBytes,
    };
  }

  Future<void> saveIncident() async {
    if (detailsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي التفاصيل أولاً')),
      );
      return;
    }

    if (incidentPlace == 'مكان آخر' &&
        otherLocationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حددي المكان بالتفصيل')),
      );
      return;
    }

    setState(() => isSaving = true);

    final autoRisk = autoAnalyzeRisk();
    final now = Timestamp.now();

    try {
      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();
      final imageData = await _uploadIncidentImageIfNeeded();

      await _firestore.collection('incident_reports').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUid': parentInfo['parentUid'],
        'parentUsername': parentInfo['parentUsername'],
        'parentName': widget.child.parentName,
        'section': widget.child.section,
        'group': widget.child.group,

        'title': 'تقرير حادث',
        'type': 'incident_report',
        'incidentType': incidentType,
        'priority': priority,
        'autoRisk': autoRisk,
        'status': status,
        'incidentPlace': finalIncidentPlace,

        'details': detailsCtrl.text.trim(),
        'note': detailsCtrl.text.trim(),
        'actionTaken': actionCtrl.text.trim(),
        'witnesses': witnesses,

        'parentNotified': parentNotified,

        ...imageData,

        'createdAt': now,
        'time': FieldValue.serverTimestamp(),
        'eventAt': now,
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,

        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التقرير بنجاح')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ التقرير: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoRisk = autoAnalyzeRisk();

    return AppPageScaffold(
      title: 'تقرير حادث',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor(autoRisk).withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: riskColor(autoRisk).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: riskColor(autoRisk)),
                const SizedBox(width: 8),
                Text(
                  'تحليل تلقائي: ${riskLabel(autoRisk)}',
                  style: TextStyle(
                    color: riskColor(autoRisk),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _card(
            'مكان الحادث',
            Icons.location_on_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: incidentPlace,
                  decoration: const InputDecoration(
                    hintText: 'اختاري مكان الحادث',
                  ),
                  items: placeOptions
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => incidentPlace = v);
                  },
                ),
                if (incidentPlace == 'مكان آخر') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otherLocationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'حددي المكان',
                      hintText: 'اكتبي المكان بالتفصيل',
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
                if (selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            selectedImage!.path,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 36,
                                  color: AppColors.textLight,
                                ),
                              );
                            },
                          )
                        : Image.network(
                            selectedImage!.path,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 36,
                                  color: AppColors.textLight,
                                ),
                              );
                            },
                          ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickImage,
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
                          onPressed: () {
                            setState(() {
                              selectedImage = null;
                            });
                          },
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
              items: const [
                DropdownMenuItem(value: 'سقوط بسيط', child: Text('سقوط بسيط')),
                DropdownMenuItem(value: 'اصطدام', child: Text('اصطدام')),
                DropdownMenuItem(value: 'جرح', child: Text('جرح')),
                DropdownMenuItem(value: 'وعكة صحية', child: Text('وعكة صحية')),
                DropdownMenuItem(value: 'حادث آخر', child: Text('حادث آخر')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => incidentType = v);
              },
            ),
          ),

          _card(
            'ماذا حدث؟',
            Icons.description_outlined,
            child: TextField(
              controller: detailsCtrl,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'اكتبي تفاصيل الحادث أو الملاحظة المهمة',
              ),
            ),
          ),

          _card(
            'الإجراء المتخذ',
            Icons.medical_services_outlined,
            child: TextField(
              controller: actionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'ما الإجراء الذي تم اتخاذه؟',
              ),
            ),
          ),

          _card(
            'شهود الحادث',
            Icons.groups_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: witnessCtrl,
                        decoration: const InputDecoration(
                          hintText: 'أضيفي اسم شاهد',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: addWitness,
                      child: const Text('إضافة'),
                    ),
                  ],
                ),
                if (witnesses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: witnesses.map((witness) {
                      return Chip(
                        label: Text(witness),
                        onDeleted: () {
                          setState(() {
                            witnesses.remove(witness);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          SwitchListTile(
            value: parentNotified,
            onChanged: (v) => setState(() => parentNotified = v),
            title: const Text('إشعار ولي الأمر'),
            subtitle: const Text('حددي إن كان تم إشعار ولي الأمر بخصوص الحادث'),
          ),

          _card(
            'أولوية التقرير',
            Icons.priority_high_outlined,
            child: DropdownButtonFormField<String>(
              value: priority,
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('عادي')),
                DropdownMenuItem(value: 'important', child: Text('مهم')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => priority = v);
              },
            ),
          ),

          _card(
            'حالة التقرير',
            Icons.flag_outlined,
            child: DropdownButtonFormField<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'review', child: Text('قيد المراجعة')),
                DropdownMenuItem(value: 'done', child: Text('مكتمل')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => status = v);
              },
            ),
          ),

          const SizedBox(height: 20),
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
              minimumSize: const Size(double.infinity, 54),
            ),
          ),
        ],
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
              Icon(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}