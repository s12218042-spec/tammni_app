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

  Color sectionColor(String section) {
    return section == 'Nursery'
        ? const Color(0xFFEFA7C8)
        : const Color(0xFF7BB6FF);
  }

  String senderLabel(String byRole) {
    if (byRole == 'nursery') return 'موظفة الحضانة';
    if (byRole == 'teacher') return 'المعلمة';
    if (byRole == 'admin') return 'الإدارة';
    return byRole.isEmpty ? 'غير محدد' : byRole;
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

  IconData typeIcon(String type) {
    switch (type) {
      case 'وجبة':
        return Icons.restaurant_outlined;
      case 'نوم':
        return Icons.bedtime_outlined;
      case 'حفاض':
        return Icons.child_care_outlined;
      case 'صحة':
        return Icons.health_and_safety_outlined;
      case 'نشاط':
        return Icons.toys_outlined;
      case 'واجب':
        return Icons.menu_book_outlined;
      case 'تقييم':
        return Icons.star_outline;
      case 'خطة اليوم':
        return Icons.event_note_outlined;
      case 'كاميرا':
        return Icons.camera_alt_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String timeText(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final t = timestamp.toDate();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String dateText(Timestamp? timestamp) {
    if (timestamp == null) return '--/--/----';
    final t = timestamp.toDate();
    return '${t.year}/${t.month}/${t.day}';
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1);
  }

  String childAgeText(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;

    if (now.day < birthDate.day) {
      months--;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years <= 0) {
      return '$months شهر';
    }

    if (months == 0) {
      return '$years سنة';
    }

    return '$years سنة و $months شهر';
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
    final child = widget.child;
    final badgeColor = sectionColor(child.section);

    return AppPageScaffold(
      title: 'تحديثات الطفل',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchUpdates(),
        builder: (context, updatesSnapshot) {
          if (updatesSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (updatesSnapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء تحميل التحديثات'),
            );
          }

          final updates = updatesSnapshot.data ?? [];

          return ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: Text(
                        firstLetter(child.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'متابعة آخر المستجدات الخاصة بالطفل',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoMiniCard(
                              icon: Icons.cake_outlined,
                              title: 'العمر',
                              value: childAgeText(child.birthDate),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoMiniCard(
                              icon: Icons.groups_outlined,
                              title: 'المجموعة',
                              value:
                                  child.group.isEmpty ? 'غير محدد' : child.group,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.apartment_outlined,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'القسم: ${sectionLabel(child.section)}',
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              if (child.section == 'Kindergarten')
                FutureBuilder<bool>(
                  future: fetchAttendance(),
                  builder: (context, attendanceSnapshot) {
                    final present = attendanceSnapshot.data ?? false;

                    return _StatusCard(
                      icon:
                          present ? Icons.check_circle : Icons.cancel_outlined,
                      color: present ? Colors.green : Colors.redAccent,
                      title: 'الحضور اليوم',
                      value: present ? 'حاضر' : 'غائب',
                    );
                  },
                )
              else
                const _StatusCard(
                  icon: Icons.info_outline,
                  color: AppColors.primary,
                  title: 'نظام المتابعة',
                  value: 'مرن حسب الزيارة والتحديثات',
                ),

              const SizedBox(height: 18),

              Text(
                'كل التحديثات',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),

              if (updates.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.12),
                          child: const Icon(
                            Icons.notifications_none,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد تحديثات مسجلة لهذا الطفل بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          child.section == 'Nursery'
                              ? 'ستظهر هنا تحديثات الزيارة، الأنشطة، الصور والملاحظات الخاصة بالحضانة.'
                              : 'ستظهر هنا تحديثات الحضور، الأنشطة، الواجبات والملاحظات الخاصة بالروضة.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                    icon: typeIcon(u['type'] ?? ''),
                    timeTextValue: timeText(u['time'] as Timestamp?),
                    dateTextValue: dateText(u['time'] as Timestamp?),
                    mediaUrl: u['mediaUrl'],
                    mediaType: u['mediaType'],
                    mediaPath: u['mediaPath'],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoMiniCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.14),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$title: $value',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color == AppColors.primary ? AppColors.textDark : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final String type;
  final String note;
  final String senderText;
  final Color badgeColor;
  final IconData icon;
  final String timeTextValue;
  final String dateTextValue;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaPath;

  const _UpdateCard({
    required this.type,
    required this.note,
    required this.senderText,
    required this.badgeColor,
    required this.icon,
    required this.timeTextValue,
    required this.dateTextValue,
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
                CircleAvatar(
                  backgroundColor: badgeColor.withOpacity(0.14),
                  child: Icon(
                    icon,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
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
                          type.isEmpty ? 'تحديث' : type,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          timeTextValue,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (note.trim().isNotEmpty)
              Text(
                note,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              )
            else
              Text(
                'لا توجد ملاحظة مضافة لهذا التحديث',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'بواسطة: $senderText',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'التاريخ: $dateTextValue',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            if (hasImageFile)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(mediaPath!),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (hasRemoteImage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    mediaUrl!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('تعذر تحميل الصورة'),
                      );
                    },
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
                          content:
                              Text('الفيديو محفوظ كرابط، سنربطه بالمشغل لاحقًا'),
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