import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    if (witnessCtrl.text.isEmpty) return;

    setState(() {
      witnesses.add(witnessCtrl.text);
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
      await _firestore.collection('incident_reports').add({
        'childId': widget.child.id,
        'incidentType': incidentType,
        'priority': priority,
        'autoRisk': autoRisk,
        'incidentPlace': finalIncidentPlace,
        'details': detailsCtrl.text,
        'actionTaken': actionCtrl.text,
        'parentNotified': parentNotified,
        'status': status,
        'witnesses': witnesses,
        'imagePath': selectedImage?.path,
        'createdAt': Timestamp.now(),
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
          /// 🔥 تحليل
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

          /// 📍 المكان
          _card(
            'مكان الحادث',
            Icons.location_on,
            child: DropdownButtonFormField(
              value: incidentPlace,
              items: placeOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => incidentPlace = v.toString()),
            ),
          ),

          /// 📸 الصورة
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
                  label: const Text('التقاط صورة'),
                ),
              ],
            ),
          ),

         
          /// 📝 التفاصيل
          _card(
            'ماذا حدث؟',
            Icons.description,
            child: TextField(
              controller: detailsCtrl,
              maxLines: 4,
            ),
          ),

          /// ⚕️ الإجراء
          _card(
            'الإجراء',
            Icons.medical_services,
            child: TextField(
              controller: actionCtrl,
              maxLines: 3,
            ),
          ),

          /// 🔔 إشعار
          SwitchListTile(
            value: parentNotified,
            onChanged: (v) =>
                setState(() => parentNotified = v),
            title: const Text('إشعار ولي الأمر'),
          ),

          /// 📊 الحالة
          _card(
            'حالة التقرير',
            Icons.flag,
            child: DropdownButtonFormField(
              value: status,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(
                    value: 'review', child: Text('قيد المراجعة')),
                DropdownMenuItem(value: 'done', child: Text('مكتمل')),
              ],
              onChanged: (v) =>
                  setState(() => status = v.toString()),
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
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

