import 'dart:io';
import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../models/update_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'video_preview_page.dart';

class ParentUpdatesPage extends StatefulWidget {
  final ChildModel child;

  const ParentUpdatesPage({
    super.key,
    required this.child,
  });

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

  String sectionLabel(String s) {
    if (s == 'Nursery') return 'حضانة';
    if (s == 'Kindergarten') return 'روضة';
    return s;
  }

  String senderLabel(String byRole) {
    if (byRole == 'nursery') return 'موظفة الحضانة';
    if (byRole == 'teacher') return 'المعلمة';
    return byRole;
  }

  Color typeColor(String type) {
    switch (type) {
      case 'وجبة':
        return Colors.orange;
      case 'نوم':
        return Colors.indigo;
      case 'حفاض':
        return Colors.brown;
      case 'صحة':
        return Colors.redAccent;
      case 'نشاط':
        return Colors.green;
      case 'واجب':
        return Colors.deepPurple;
      case 'تقييم':
        return Colors.teal;
      case 'خطة اليوم':
        return Colors.blue;
      case 'كاميرا':
        return Colors.pink;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = DummyData.isPresentToday(widget.child.id);

    return AppPageScaffold(
      title: 'تحديثات الطفل',
      child: ListView(
        children: [
          Text(
            'متابعة الطفل',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'شاهدي آخر التحديثات اليومية الخاصة بطفلك',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.child_care,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.child.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'القسم: ${sectionLabel(widget.child.section)}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الصف / المجموعة: ${widget.child.group}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: present
                        ? Colors.green.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                    child: Icon(
                      present ? Icons.check_circle : Icons.cancel,
                      color: present ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الحضور اليوم: ${present ? "داخل المؤسسة ✅" : "غائب ❌"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'آخر التحديثات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),

          if (updates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'لا يوجد تحديثات بعد.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            ...updates.map(
              (u) => _UpdateCard(
                update: u,
                timeText: timeText(u.time),
                senderText: senderLabel(u.byRole),
                badgeColor: typeColor(u.type),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final UpdateModel update;
  final String timeText;
  final String senderText;
  final Color badgeColor;

  const _UpdateCard({
    required this.update,
    required this.timeText,
    required this.senderText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    timeText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    update.type,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              update.note,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'بواسطة: $senderText',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
            if (update.mediaPath != null && update.mediaType == 'image')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(update.mediaPath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (update.mediaPath != null && update.mediaType == 'video')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPreviewPage(
                            path: update.mediaPath!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('تشغيل الفيديو'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}