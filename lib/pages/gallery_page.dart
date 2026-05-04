import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'video_preview_page.dart';

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
    return 'حضانة';
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _resolveDateTime(Map<String, dynamic> data) {
    final candidates = [
      data['eventAt'],
      data['time'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      final date = _dateFromDynamic(value);
      if (date != null) return date;
    }

    return null;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveNote(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['note'],
      data['message'],
      data['body'],
      data['description'],
      data['details'],
    ]);
  }

  String _resolveType(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['type'],
      data['updateType'],
      data['category'],
      data['title'],
    ]);
  }

  String _resolveByRole(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['byRole'],
      data['createdByRole'],
      data['senderRole'],
      data['role'],
    ]);
  }

  bool _isUsableRemoteUrl(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  String _resolveMediaUrl(Map<String, dynamic> data) {
    final directUrl = _firstNonEmpty([
      data['mediaUrl'],
      data['imageUrl'],
      data['videoUrl'],
      data['url'],
    ]);

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
    final path = _firstNonEmpty([
      data['mediaPath'],
      data['path'],
      data['imagePath'],
      data['videoPath'],
    ]);

    if (path.startsWith('blob:')) return '';
    if (_isUsableRemoteUrl(path)) return '';

    return path;
  }

  String _resolveStorageProvider(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['storageProvider'],
      data['provider'],
    ]);
  }

  String _resolvePublicUrl(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['publicUrl'],
      data['mediaPublicUrl'],
    ]);
  }

  String _resolveMediaType(Map<String, dynamic> data) {
    final mediaType = (data['mediaType'] ?? '').toString().trim().toLowerCase();

    if (mediaType == 'image' || mediaType == 'video') {
      return mediaType;
    }

    final url = _resolveMediaUrl(data).toLowerCase();
    final path = _resolveMediaPath(data).toLowerCase();
    final mimeType = (data['mimeType'] ?? '').toString().trim().toLowerCase();
    final source = '$url $path $mimeType';

    if (source.contains('video') ||
        source.endsWith('.mp4') ||
        source.endsWith('.mov') ||
        source.endsWith('.avi') ||
        source.endsWith('.mkv') ||
        source.endsWith('.webm') ||
        source.endsWith('.m4v')) {
      return 'video';
    }

    if (source.contains('image') ||
        source.endsWith('.jpg') ||
        source.endsWith('.jpeg') ||
        source.endsWith('.png') ||
        source.endsWith('.webp') ||
        source.endsWith('.gif')) {
      return 'image';
    }

    return '';
  }

  List<Map<String, dynamic>> _prepareMediaUpdates(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = docs.map((doc) {
      final data = doc.data();

      final mediaUrl = _resolveMediaUrl(data);
      final mediaPath = _resolveMediaPath(data);
      final mediaType = _resolveMediaType(data);
      final displayDateTime = _resolveDateTime(data);
      final publicUrl = _resolvePublicUrl(data);
      final storageProvider = _resolveStorageProvider(data);

      return {
        'id': doc.id,
        'type': _resolveType(data),
        'note': _resolveNote(data),
        'displayDateTime': displayDateTime,
        'mediaPath': mediaPath,
        'mediaUrl': mediaUrl,
        'publicUrl': publicUrl,
        'storageProvider': storageProvider,
        'mediaType': mediaType,
        'byRole': _resolveByRole(data),
      };
    }).where((item) {
      final mediaUrl = (item['mediaUrl'] ?? '').toString().trim();
      final mediaPath = (item['mediaPath'] ?? '').toString().trim();
      final publicUrl = (item['publicUrl'] ?? '').toString().trim();
      final mediaType = (item['mediaType'] ?? '').toString().trim();

      final hasMediaSource =
          mediaPath.isNotEmpty || mediaUrl.isNotEmpty || publicUrl.isNotEmpty;

      if (!hasMediaSource || mediaType.isEmpty) {
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

    items.sort((a, b) {
      final aTime = a['displayDateTime'] as DateTime?;
      final bTime = b['displayDateTime'] as DateTime?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _mediaUpdatesStream() {
    return _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .snapshots();
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
    }

    if (difference == 1) {
      return 'أمس، ${date.day} ${months[date.month]}';
    }

    return '${date.day} ${months[date.month]} ${date.year}';
  }

  String formatTime(DateTime? date) {
    if (date == null) return '';

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
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
    final mediaUrl = item['mediaUrl']?.toString() ?? '';
    final mediaPath = item['mediaPath']?.toString() ?? '';
    final publicUrl = item['publicUrl']?.toString() ?? '';
    final storageProvider = item['storageProvider']?.toString() ?? '';
    final mediaType = item['mediaType']?.toString() ?? '';
    final note = item['note']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';
    final time = item['displayDateTime'] as DateTime?;

    final isVideo = mediaType == 'video';

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPreviewPage(
                path: mediaUrl.isNotEmpty ? mediaUrl : mediaPath,
                mediaPath: mediaPath,
                mediaUrl: mediaUrl,
                publicUrl: publicUrl,
                storageProvider:
                    storageProvider.isNotEmpty ? storageProvider : 'supabase',
                title: widget.child.name,
              ),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryPreviewPage(
              mediaPath: mediaPath,
              mediaUrl: mediaUrl,
              publicUrl: publicUrl,
              storageProvider:
                  storageProvider.isNotEmpty ? storageProvider : 'supabase',
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
                  mediaUrl: mediaUrl,
                  publicUrl: publicUrl,
                  storageProvider:
                      storageProvider.isNotEmpty ? storageProvider : 'supabase',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    required String mediaUrl,
    required String publicUrl,
    required String storageProvider,
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

    return FreshMediaImage(
      mediaPath: mediaPath,
      mediaUrl: mediaUrl,
      publicUrl: publicUrl,
      storageProvider: storageProvider,
      fit: BoxFit.cover,
    );
  }

  Widget buildBrokenMedia({String message = 'تعذر عرض الوسائط'}) {
    return Container(
      color: AppColors.primary.withOpacity(0.06),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupByDate(
    List<Map<String, dynamic>> items,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final item in items) {
      final date = item['displayDateTime'] as DateTime?;
      if (date == null) continue;

      final key = '${date.year}-${date.month}-${date.day}';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final headerSubtitle = sectionLabel(widget.child.section);

    return AppPageScaffold(
      title: 'معرض الطفل',
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
                        headerSubtitle,
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _mediaUpdatesStream(),
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

                final rawDocs = snapshot.data?.docs ?? [];
                final items = _prepareMediaUpdates(rawDocs);

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
                    final date = groupItems.first['displayDateTime'] as DateTime?;
                    final title = date == null ? key : formatDateLabel(date);

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

class FreshMediaImage extends StatefulWidget {
  final String mediaPath;
  final String mediaUrl;
  final String publicUrl;
  final String storageProvider;
  final BoxFit fit;

  const FreshMediaImage({
    super.key,
    required this.mediaPath,
    required this.mediaUrl,
    required this.publicUrl,
    required this.storageProvider,
    this.fit = BoxFit.cover,
  });

  @override
  State<FreshMediaImage> createState() => _FreshMediaImageState();
}

class _FreshMediaImageState extends State<FreshMediaImage> {
  final GalleryService _galleryService = GalleryService();

  late Future<String?> _futureUrl;

  @override
  void initState() {
    super.initState();
    _futureUrl = _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant FreshMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mediaPath != widget.mediaPath ||
        oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.publicUrl != widget.publicUrl ||
        oldWidget.storageProvider != widget.storageProvider) {
      _futureUrl = _resolveUrl();
    }
  }

  Future<String?> _resolveUrl() {
    return _galleryService.resolveFreshMediaUrlFromFields(
      storageProvider: widget.storageProvider,
      mediaPath: widget.mediaPath,
      oldMediaUrl: widget.mediaUrl,
      publicUrl: widget.publicUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _futureUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: AppColors.primary.withOpacity(0.06),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final url = snapshot.data ?? '';

        if (url.trim().isEmpty) {
          return const _BrokenMediaBox(
            message: 'تعذر عرض الصورة',
          );
        }

        return Image.network(
          url,
          fit: widget.fit,
          errorBuilder: (_, __, ___) {
            return const _BrokenMediaBox(
              message: 'تعذر عرض الصورة',
            );
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
      },
    );
  }
}

class GalleryPreviewPage extends StatelessWidget {
  final String mediaPath;
  final String mediaUrl;
  final String publicUrl;
  final String storageProvider;
  final String title;
  final String subtitle;
  final String timeText;

  const GalleryPreviewPage({
    super.key,
    required this.mediaPath,
    required this.mediaUrl,
    required this.publicUrl,
    required this.storageProvider,
    required this.title,
    required this.subtitle,
    required this.timeText,
  });

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
                child: InteractiveViewer(
                  child: FreshMediaImage(
                    mediaPath: mediaPath,
                    mediaUrl: mediaUrl,
                    publicUrl: publicUrl,
                    storageProvider: storageProvider,
                    fit: BoxFit.contain,
                  ),
                ),
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
}

class _BrokenMediaBox extends StatelessWidget {
  final String message;

  const _BrokenMediaBox({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withOpacity(0.06),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                size: 36,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}