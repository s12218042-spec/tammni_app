import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../models/update_model.dart';
import 'dart:io';
import 'video_preview_page.dart';
import '../widgets/app_bar_widget.dart';

class ParentUpdatesPage extends StatefulWidget {
  final ChildModel child;
  const ParentUpdatesPage({super.key, required this.child});

  @override
  State<ParentUpdatesPage> createState() => _ParentUpdatesPageState();
}

class _ParentUpdatesPageState extends State<ParentUpdatesPage> {
  List<UpdateModel> get updates => DummyData.updatesForChild(widget.child.id);

  String timeText(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final present = DummyData.isPresentToday(widget.child.id);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  color: const Color(0xFFF6F6FF),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFF8E97FD)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الحضور اليوم: ${present ? "داخل المؤسسة ✅" : "غائب ❌"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (updates.isEmpty)
                const Text('لا يوجد تحديثات بعد.')
              else
                ...updates.map((u) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E97FD).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(timeText(u.time),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text(u.note),
                              if (u.mediaPath != null && u.mediaType == 'image')
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(u.mediaPath!),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    ),
  ),

if (u.mediaPath != null && u.mediaType == 'video')
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPreviewPage(path: u.mediaPath!),
            ),
          );
        },
        icon: const Icon(Icons.play_circle),
        label: const Text('تشغيل الفيديو'),
      ),
    ),
  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}