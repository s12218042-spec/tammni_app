import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> _refreshPage() async {
    if (!mounted) return;
    setState(() {});
  }

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
    final role = byRole.trim().toLowerCase();

    if (role == 'nursery' || role == 'nursery_staff') {
      return 'موظفة الحضانة';
    }
    if (role == 'teacher') return 'المعلمة';
    if (role == 'admin') return 'الإدارة';
    if (role == 'parent') return 'ولي الأمر';

    return byRole.trim().isEmpty ? 'غير محدد' : byRole;
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
    final y = t.year.toString();
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1);
  }

  String childAgeText(DateTime? birthDate) {
    if (birthDate == null) return 'غير محدد';

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
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<bool> fetchAttendance() async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('childId', isEqualTo: widget.child.id)
        .where('dateKey', isEqualTo: dateKey)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;
    return snapshot.docs.first.data()['present'] == true;
  }

  String _resolveNote(Map<String, dynamic> data) {
    final candidates = [
      data['note'],
      data['message'],
      data['body'],
      data['description'],
      data['details'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveRole(Map<String, dynamic> data) {
    final candidates = [
      data['byRole'],
      data['createdByRole'],
      data['senderRole'],
      data['role'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveCreatorName(Map<String, dynamic> data) {
    final candidates = [
      data['createdByName'],
      data['senderName'],
      data['byName'],
      data['staffName'],
      data['teacherName'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['time'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  bool _isUsableRemoteUrl(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

String _resolveMediaUrl(Map<String, dynamic> data) {
  final directUrl = (data['mediaUrl'] ?? '').toString().trim();
  if (_isUsableRemoteUrl(directUrl)) return directUrl;

  final mediaUrls = data['mediaUrls'];
  if (mediaUrls is List && mediaUrls.isNotEmpty) {
    for (final item in mediaUrls) {
      final candidate = item?.toString().trim() ?? '';
      if (_isUsableRemoteUrl(candidate)) return candidate;
    }
  }

  return '';
}

String _resolveMediaPath(Map<String, dynamic> data) {
  final path = (data['mediaPath'] ?? '').toString().trim();
  if (path.startsWith('blob:')) return '';
  return path;
}

String _resolveMediaType(Map<String, dynamic> data) {
  final mediaType = (data['mediaType'] ?? '').toString().trim().toLowerCase();
  if (mediaType.isNotEmpty) return mediaType;

  final mediaUrl = _resolveMediaUrl(data).toLowerCase();
  final mediaPath = _resolveMediaPath(data).toLowerCase();
  final source = mediaUrl.isNotEmpty ? mediaUrl : mediaPath;

  if (source.endsWith('.mp4') ||
      source.endsWith('.mov') ||
      source.endsWith('.avi') ||
      source.endsWith('.mkv') ||
      source.contains('video')) {
    return 'video';
  }

  if (source.endsWith('.jpg') ||
      source.endsWith('.jpeg') ||
      source.endsWith('.png') ||
      source.endsWith('.webp') ||
      source.contains('image')) {
    return 'image';
  }

  return '';
}

  Future<List<Map<String, dynamic>>> fetchUpdates() async {
  final snapshot = await _firestore
      .collection('updates')
      .where('childId', isEqualTo: widget.child.id)
      .get();

  final items = snapshot.docs.map((doc) {
    final data = doc.data();

    final mediaUrl = _resolveMediaUrl(data);
    final mediaPath = _resolveMediaPath(data);
    final mediaType = _resolveMediaType(data);
    final resolvedSource = mediaUrl.isNotEmpty ? mediaUrl : mediaPath;

    return {
      'id': doc.id,
      'type': (data['type'] ?? data['updateType'] ?? '').toString(),
      'note': _resolveNote(data),
      'byRole': _resolveRole(data),
      'createdByName': _resolveCreatorName(data),
      'displayTime': _resolveTimestamp(data),
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'mediaPath': mediaPath,
      'resolvedSource': resolvedSource,
      'hasMedia': resolvedSource.isNotEmpty && mediaType.isNotEmpty,
    };
  }).toList();

  items.sort((a, b) {
    final aTime = a['displayTime'] as Timestamp?;
    final bTime = b['displayTime'] as Timestamp?;

    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;

    return bTime.compareTo(aTime);
  });

  return items;
}

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final badgeColor = sectionColor(child.section);

    return AppPageScaffold(
      title: 'تحديثات الطفل',
      child: RefreshIndicator(
        onRefresh: _refreshPage,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchUpdates(),
          builder: (context, updatesSnapshot) {
            if (updatesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (updatesSnapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل التحديثات: ${updatesSnapshot.error}',
                    ),
                  ),
                ],
              );
            }

            final updates = updatesSnapshot.data ?? [];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                                value: child.section == 'Nursery'
                                    ? 'غير مطبق'
                                    : (child.group.isEmpty ? 'غير محدد' : child.group),
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
                        icon: present ? Icons.check_circle : Icons.cancel_outlined,
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
                    value: 'مرن حسب الزيارة والتحديثات، والدخول والخروج يوثّق من الإدارة',
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
                            backgroundColor: AppColors.primary.withOpacity(0.12),
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
                                ? 'ستظهر هنا تحديثات الزيارة، الأنشطة، الصور، الملاحظات، ومتابعة الرعاية الخاصة بالحضانة.'
                                : 'ستظهر هنا تحديثات الحضور، الأنشطة، الواجبات والملاحظات الخاصة بالروضة.',
                            style: const TextStyle(
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
                    (u) {
                      final Timestamp? displayTime = u['displayTime'] as Timestamp?;

                      return _UpdateCard(
                        type: u['type'] ?? '',
                        note: u['note'] ?? '',
                        senderText: senderLabel(u['byRole'] ?? ''),
                        creatorName: u['createdByName'] ?? '',
                        badgeColor: typeColor(u['type'] ?? ''),
                        icon: typeIcon(u['type'] ?? ''),
                        timeTextValue: timeText(displayTime),
                        dateTextValue: dateText(displayTime),
                        mediaUrl: u['mediaUrl']?.toString(),
                        mediaType: u['mediaType']?.toString(),
                        mediaPath: u['mediaPath']?.toString(),
                        hasMedia: u['hasMedia'] == true,
                      );
                    },
                  ),
              ],
            );
          },
        ),
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
            style: const TextStyle(
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
  final String creatorName;
  final Color badgeColor;
  final IconData icon;
  final String timeTextValue;
  final String dateTextValue;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaPath;
  final bool hasMedia;

  const _UpdateCard({
    required this.type,
    required this.note,
    required this.senderText,
    required this.creatorName,
    required this.badgeColor,
    required this.icon,
    required this.timeTextValue,
    required this.dateTextValue,
    this.mediaUrl,
    this.mediaType,
    this.mediaPath,
    required this.hasMedia,
  });

  bool get _hasRemoteUrl {
  final value = (mediaUrl ?? '').trim().toLowerCase();
  return value.startsWith('http://') || value.startsWith('https://');
}

bool get _hasLocalPath {
  final value = (mediaPath ?? '').trim();
  if (value.isEmpty) return false;
  if (value.startsWith('blob:')) return false;
  return true;
}

String get _normalizedMediaType => (mediaType ?? '').trim().toLowerCase();

String get _resolvedSource {
  if (_hasRemoteUrl) return mediaUrl!.trim();
  if (_hasLocalPath) return mediaPath!.trim();
  return '';
}

bool get _hasRemoteImage => _hasRemoteUrl && _normalizedMediaType == 'image';
bool get _hasRemoteVideo => _hasRemoteUrl && _normalizedMediaType == 'video';
bool get _hasLocalImage => !kIsWeb && _hasLocalPath && _normalizedMediaType == 'image';
bool get _hasLocalVideo => !kIsWeb && _hasLocalPath && _normalizedMediaType == 'video';

  String get _senderDisplay {
    if (creatorName.trim().isNotEmpty) {
      return '$creatorName - $senderText';
    }
    return senderText;
  }

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
                CircleAvatar(
                  backgroundColor: badgeColor.withOpacity(0.14),
                  child: Icon(icon, color: badgeColor),
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
                      if (hasMedia)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _normalizedMediaType == 'video' ? 'فيديو' : 'صورة',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.trim().isNotEmpty
                  ? note
                  : 'لا توجد ملاحظة مضافة لهذا التحديث',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: note.trim().isNotEmpty
                    ? AppColors.textDark
                    : AppColors.textLight,
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
                    'بواسطة: $_senderDisplay',
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
            if (_hasRemoteImage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    mediaUrl!.trim(),
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
            if (!_hasRemoteImage && _hasLocalImage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(mediaPath!.trim()),
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
                        child: const Text('تعذر فتح الصورة المحلية'),
                      );
                    },
                  ),
                ),
              ),
            if (_hasRemoteVideo || _hasLocalVideo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_resolvedSource.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لا يوجد مصدر صالح للفيديو'),
                          ),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPreviewPage(
                            path: _resolvedSource,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(
                    _hasRemoteVideo ? 'عرض الفيديو' : 'تشغيل الفيديو',
                 ),
                  ),
                ),
              ),
            if (kIsWeb && !_hasRemoteUrl && _hasLocalPath)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'تم حفظ مرفق محلي، لكن Flutter Web لا يعرض الملفات المحلية مباشرة.\nسيظهر المرفق عند نجاح رفعه كرابط.',
                    style: TextStyle(
                      color: Colors.orange,
                      height: 1.5,
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