import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  String timeText(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final t = timestamp.toDate();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dateKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<bool> fetchAttendance() async {
    final docId = '${widget.child.id}_$dateKey';
    final doc = await _firestore.collection('attendance').doc(docId).get();

    if (!doc.exists) return false;
    return doc.data()?['present'] == true;
  }

  Future<List<Map<String, dynamic>>> fetchUpdates() async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .orderBy('time', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'byRole': data['byRole'] ?? '',
        'time': data['time'] as Timestamp?,
        'mediaUrl': data['mediaUrl'],
        'mediaType': data['mediaType'],
        'mediaPath': data['mediaPath'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isNursery = widget.child.section == 'Nursery';

    return AppPageScaffold(
      title: 'تحديثات الطفل',
      child: FutureBuilder<bool>(
        future: isNursery ? Future.value(false) : fetchAttendance(),
        builder: (context, attendanceSnapshot) {
          final present = attendanceSnapshot.data ?? false;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchUpdates(),
            builder: (context, updatesSnapshot) {
              if (updatesSnapshot.connectionState == ConnectionState.waiting ||
                  (!isNursery &&
                      attendanceSnapshot.connectionState ==
                          ConnectionState.waiting)) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (updatesSnapshot.hasError) {
                return const Center(
                  child: Text('حدث خطأ أثناء تحميل التحديثات'),
                );
              }

              if (!isNursery && attendanceSnapshot.hasError) {
                return const Center(
                  child: Text('حدث خطأ أثناء تحميل الحضور'),
                );
              }

              final updates = updatesSnapshot.data ?? [];

              return ListView(
                children: [
                  Text(
                    'متابعة الطفل',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'شاهدي آخر التحديثات الخاصة بطفلك',
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
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.12),
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

                  if (isNursery)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.warning.withOpacity(0.12),
                              child: const Icon(
                                Icons.info_outline,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'نظام المتابعة في الحضانة مرن حسب الزيارة والتحديثات اليومية، ولا يعتمد على حضور أو غياب ثابت كل يوم.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
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
                                'الحضور اليوم: ${present ? "حاضر" : "غائب"}',
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
                        type: u['type'] ?? '',
                        note: u['note'] ?? '',
                        senderText: senderLabel(u['byRole'] ?? ''),
                        badgeColor: typeColor(u['type'] ?? ''),
                        timeTextValue: timeText(u['time'] as Timestamp?),
                        mediaUrl: u['mediaUrl'],
                        mediaType: u['mediaType'],
                        mediaPath: u['mediaPath'],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final String type;
  final String note;
  final String senderText;
  final Color badgeColor;
  final String timeTextValue;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaPath;

  const _UpdateCard({
    required this.type,
    required this.note,
    required this.senderText,
    required this.badgeColor,
    required this.timeTextValue,
    this.mediaUrl,
    this.mediaType,
    this.mediaPath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImageFile = mediaPath != null && mediaType == 'image';
    final hasVideoFile = mediaPath != null && mediaType == 'video';
    final hasRemoteImage = mediaUrl != null && mediaType == 'image';
    final hasRemoteVideo = mediaUrl != null && mediaType == 'video';

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
                    timeTextValue,
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
                    type,
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
              note,
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

            if (hasImageFile)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(mediaPath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (hasRemoteImage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    mediaUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (hasVideoFile)
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
                            path: mediaPath!,
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

            if (hasRemoteVideo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الفيديو محفوظ كرابط، سنربطه بالمشغل لاحقًا'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('عرض الفيديو'),
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