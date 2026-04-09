import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/child_model.dart';
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
  File? selectedImage;

  final List<String> placeOptions = [
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
      'name': (data['displayName'] ?? data['name'] ?? data['username'] ?? 'مستخدم')
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
      // fallback على بيانات widget.child
    }

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
    };
  }

  Future<void> pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  void addWitness() {
    if (witnessCtrl.text.trim().isEmpty) return;

    setState(() {
      witnesses.add(witnessCtrl.text.trim());
      witnessCtrl.clear();
    });
  }

  Future<void> saveIncident() async {
    if (detailsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي التفاصيل أولاً')),
      );
      return;
    }

    setState(() => isSaving = true);

    final autoRisk = autoAnalyzeRisk();

    try {
      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();

      await _firestore.collection('incident_reports').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUid': parentInfo['parentUid'],
        'parentUsername': parentInfo['parentUsername'],
        'section': widget.child.section,
        'group': widget.child.group,
        'incidentType': incidentType,
        'priority': priority,
        'autoRisk': autoRisk,
        'incidentPlace': finalIncidentPlace,
        'details': detailsCtrl.text.trim(),
        'actionTaken': actionCtrl.text.trim(),
        'parentNotified': parentNotified,
        'status': status,
        'witnesses': witnesses,
        'imagePath': selectedImage?.path,
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ بنجاح')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
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
              color: riskColor(autoRisk).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: riskColor(autoRisk)),
                const SizedBox(width: 8),
                Text(
                  'تحليل: ${riskLabel(autoRisk)}',
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
            Icons.location_on,
            child: Column(
              children: [
                DropdownButtonFormField(
                  value: incidentPlace,
                  items: placeOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => incidentPlace = v.toString()),
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
            Icons.camera_alt,
            child: Column(
              children: [
                if (selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      selectedImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(Icons.camera),
                  label: Text(
                    selectedImage == null ? 'التقاط صورة' : 'تغيير الصورة',
                  ),
                ),
              ],
            ),
          ),
          _card(
            'ماذا حدث؟',
            Icons.description,
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
            'الإجراء',
            Icons.medical_services,
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
          ),
          _card(
            'حالة التقرير',
            Icons.flag,
            child: DropdownButtonFormField(
              value: status,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'review', child: Text('قيد المراجعة')),
                DropdownMenuItem(value: 'done', child: Text('مكتمل')),
              ],
              onChanged: (v) => setState(() => status = v.toString()),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isSaving ? null : saveIncident,
            child: Text(isSaving ? 'جاري الحفظ...' : 'حفظ التقرير'),
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