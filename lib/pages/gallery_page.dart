import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class GalleryPage extends StatefulWidget {
  final ChildModel child;

  const GalleryPage({
    super.key,
    required this.child,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedFilter = 'all';

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  Future<List<Map<String, dynamic>>> fetchMediaUpdates() async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .orderBy('time', descending: true)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'time': data['time'],
        'mediaPath': data['mediaPath'],
        'mediaType': data['mediaType'],
        'byRole': data['byRole'] ?? '',
      };
    }).where((item) {
      final mediaPath = item['mediaPath'];
      final mediaType = item['mediaType'];

      if (mediaPath == null || mediaPath.toString().trim().isEmpty) {
        return false;
      }

      if (mediaType == null || mediaType.toString().trim().isEmpty) {
        return false;
      }

      if (selectedFilter == 'image') {
        return mediaType == 'image';
      }

      if (selectedFilter == 'video') {
        return mediaType == 'video';
      }

      return true;
    }).toList();

    return items;
  }

  String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final difference = today.difference(target).inDays;

    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    if (difference == 0) {
      return 'اليوم، ${date.day} ${months[date.month]}';
    } else if (difference == 1) {
      return 'أمس، ${date.day} ${months[date.month]}';
    } else {
      return '${date.day} ${months[date.month]} ${date.year}';
    }
  }

  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  Widget buildFilterChip({
    required String label,
    required String value,
  }) {
    final isSelected = selectedFilter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMediaTile(Map<String, dynamic> item) {
    final mediaPath = item['mediaPath']?.toString() ?? '';
    final mediaType = item['mediaType']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';
    final time = item['time'] as Timestamp?;

    final isVideo = mediaType == 'video';
    final isNetwork = mediaPath.startsWith('http');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryPreviewPage(
              mediaPath: mediaPath,
              mediaType: mediaType,
              title: widget.child.name,
              subtitle: note.isNotEmpty ? note : type,
              timeText: formatTime(time),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: buildMediaContent(
                  mediaPath: mediaPath,
                  isNetwork: isNetwork,
                  isVideo: isVideo,
                ),
              ),
              if (isVideo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.18),
                    child: const Center(
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isVideo ? 'فيديو' : 'صورة',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (type.isNotEmpty)
                        Text(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textDark,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (time != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          formatTime(time),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMediaContent({
    required String mediaPath,
    required bool isNetwork,
    required bool isVideo,
  }) {
    if (isVideo) {
      return Container(
        color: AppColors.primary.withOpacity(0.08),
        child: const Center(
          child: Icon(
            Icons.videocam_rounded,
            size: 42,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (isNetwork) {
      return Image.network(
        mediaPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return buildBrokenMedia();
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: AppColors.primary.withOpacity(0.06),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    }

    if (kIsWeb) {
      return Container(
        color: AppColors.primary.withOpacity(0.06),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'معاينة الملفات المحلية غير مدعومة على الويب',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final file = File(mediaPath);
    if (!file.existsSync()) {
      return buildBrokenMedia();
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => buildBrokenMedia(),
    );
  }

  Widget buildBrokenMedia() {
    return Container(
      color: AppColors.primary.withOpacity(0.06),
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          size: 36,
          color: AppColors.textLight,
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupByDate(
    List<Map<String, dynamic>> items,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final item in items) {
      final timestamp = item['time'] as Timestamp?;
      if (timestamp == null) continue;

      final date = timestamp.toDate();
      final key = '${date.year}-${date.month}-${date.day}';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'معرض صور الطفل',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.secondary.withOpacity(0.14),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.child.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sectionLabel(widget.child.section)} • ${widget.child.group}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              buildFilterChip(label: 'الكل', value: 'all'),
              buildFilterChip(label: 'صور', value: 'image'),
              buildFilterChip(label: 'فيديو', value: 'video'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchMediaUpdates(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل المعرض',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 54,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'لا توجد وسائط بعد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'عند إضافة صور أو فيديوهات للطفل ستظهر هنا',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final grouped = groupByDate(items);
                final sortedKeys = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final key = sortedKeys[index];
                    final groupItems = grouped[key]!;
                    final timestamp = groupItems.first['time'] as Timestamp?;
                    final title = timestamp == null
                        ? key
                        : formatDateLabel(timestamp.toDate());

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 10,
                            right: 4,
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupItems.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          itemBuilder: (context, gridIndex) {
                            return buildMediaTile(groupItems[gridIndex]);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryPreviewPage extends StatelessWidget {
  final String mediaPath;
  final String mediaType;
  final String title;
  final String subtitle;
  final String timeText;

  const GalleryPreviewPage({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.title,
    required this.subtitle,
    required this.timeText,
  });

  bool get isVideo => mediaType == 'video';
  bool get isNetwork => mediaPath.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: isVideo
                    ? Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 72,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'معاينة الفيديو الكاملة ستُفعّل لاحقًا',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : buildImagePreview(),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildImagePreview() {
    if (isNetwork) {
      return InteractiveViewer(
        child: Image.network(
          mediaPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.broken_image_rounded,
              color: Colors.white54,
              size: 60,
            );
          },
        ),
      );
    }

    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'معاينة الصور المحلية غير مدعومة على الويب',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final file = File(mediaPath);
    if (!file.existsSync()) {
      return const Icon(
        Icons.broken_image_rounded,
        color: Colors.white54,
        size: 60,
      );
    }

    return InteractiveViewer(
      child: Image.file(
        file,
        fit: BoxFit.contain,
      ),
    );
  }
}
