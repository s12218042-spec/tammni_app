import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentIncidentReportsPage extends StatelessWidget {
  final ChildModel child;

  const ParentIncidentReportsPage({
    super.key,
    required this.child,
  });

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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$year/$month/$day - $hour:$minute $period';
  }

  Color _priorityColor(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
      case 'urgent':
      case 'عالية':
      case 'عاجل':
        return Colors.red;
      case 'medium':
      case 'important':
      case 'متوسطة':
      case 'مهم':
        return Colors.orange;
      case 'low':
      case 'normal':
      case 'منخفضة':
      case 'عادي':
        return Colors.green;
      default:
        return Colors.redAccent;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
      case 'urgent':
      case 'عالية':
      case 'عاجل':
        return 'عالية';
      case 'medium':
      case 'important':
      case 'متوسطة':
      case 'مهم':
        return 'متوسطة';
      case 'low':
      case 'normal':
      case 'منخفضة':
      case 'عادي':
        return 'منخفضة';
      default:
        return priority.trim().isEmpty ? 'غير محددة' : priority;
    }
  }

  String _incidentTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'health':
        return 'ملاحظة صحية';
      case 'injury':
        return 'إصابة';
      case 'behavior':
        return 'سلوك';
      case 'accident':
        return 'حادث';
      case 'incident':
      case 'incident_report':
        return 'تقرير حادث';
      case 'سقوط بسيط':
        return 'سقوط بسيط';
      case 'اصطدام':
        return 'اصطدام';
      case 'جرح':
        return 'جرح';
      case 'وعكة صحية':
        return 'وعكة صحية';
      case 'حادث آخر':
        return 'حادث آخر';
      case 'إصابة':
        return 'إصابة';
      case 'حادث':
        return 'حادث';
      case 'ملاحظة':
        return 'ملاحظة';
      default:
        return type.trim().isEmpty ? 'تقرير حادث' : type;
    }
  }

  String _roleLabel(String role) {
    final clean = role.trim().toLowerCase();

    if (clean == 'nursery' ||
        clean == 'nursery staff' ||
        clean == 'nursery_staff' ||
        clean == 'staff' ||
        clean == 'employee' ||
        clean == 'teacher') {
      return 'موظف الحضانة';
    }

    if (clean == 'admin') return 'الإدارة';
    if (clean == 'parent') return 'وليّ الأمر';

    return role.trim().isEmpty ? '' : role;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  bool _isUsableRemoteUrl(String value) {
    final clean = value.trim().toLowerCase();
    return clean.startsWith('http://') || clean.startsWith('https://');
  }

  String _resolveIncidentType(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['incidentType'],
      data['incidentLabel'],
      data['type'] == 'incident_report' ? '' : data['type'],
      data['reportType'] == 'incident_report' ? '' : data['reportType'],
      data['title'] == 'تقرير حادث' ? '' : data['title'],
    ]);
  }

  String _resolvePriority(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['priority'],
      data['importance'],
      data['severity'],
      data['level'],
      data['autoRisk'],
    ]);
  }

  String _resolveDetails(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['details'],
      data['incidentDetails'],
      data['note'],
    ]);
  }

  String _resolveActionTaken(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['actionTaken'],
      data['action'],
      data['response'],
      data['actionNote'],
    ]);
  }

  String _resolveIncidentPlace(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['incidentPlace'],
      data['locationLabel'],
      data['place'],
      data['location'],
    ]);
  }

  String _resolveCreatedByName(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['createdByName'],
      data['byName'],
      data['staffName'],
      data['adminName'],
      data['senderName'],
    ]);
  }

  String _resolveCreatedByRole(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['createdByRole'],
      data['byRole'],
      data['senderRole'],
      data['role'],
    ]);
  }

  String _resolveMediaPath(Map<String, dynamic> data) {
    final path = _firstNonEmpty([
      data['mediaPath'],
      data['imagePath'],
      data['path'],
      data['photoPath'],
      data['attachmentPath'],
    ]);

    if (path.startsWith('blob:')) return '';
    if (_isUsableRemoteUrl(path)) return '';

    return path;
  }

  String _resolveMediaUrl(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['mediaUrl'],
      data['imageUrl'],
      data['photoUrl'],
      data['attachmentUrl'],
      data['url'],
      data['signedUrl'],
      data['downloadUrl'],
    ]);
  }

  String _resolvePublicUrl(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['publicUrl'],
      data['mediaPublicUrl'],
    ]);
  }

  String _resolveStorageProvider(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['storageProvider'],
      data['provider'],
    ]);
  }

  bool _hasImage(Map<String, dynamic> data) {
    final mediaType = (data['mediaType'] ?? data['imageType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final hasAnySource = _resolveMediaPath(data).isNotEmpty ||
        _resolveMediaUrl(data).isNotEmpty ||
        _resolvePublicUrl(data).isNotEmpty;

    if (!hasAnySource) return false;
    if (mediaType.isEmpty) return true;

    return mediaType == 'image';
  }

  List<String> _resolveWitnesses(Map<String, dynamic> data) {
    final value = data['witnesses'];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = _firstNonEmpty([
      data['witnessesText'],
      data['witness'],
    ]);

    if (text.isEmpty) return [];

    return text
        .split(RegExp(r'[,،]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _prepareIncidentReports(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = docs.map((doc) {
      final data = doc.data();
      final displayDateTime = _resolveDateTime(data);

      return {
        'id': doc.id,
        'incidentType': _resolveIncidentType(data),
        'priority': _resolvePriority(data),
        'autoRisk': (data['autoRisk'] ?? '').toString().trim(),
        'details': _resolveDetails(data),
        'actionTaken': _resolveActionTaken(data),
        'incidentPlace': _resolveIncidentPlace(data),
        'createdByName': _resolveCreatedByName(data),
        'createdByRole': _resolveCreatedByRole(data),
        'displayDateTime': displayDateTime,
        'mediaPath': _resolveMediaPath(data),
        'mediaUrl': _resolveMediaUrl(data),
        'publicUrl': _resolvePublicUrl(data),
        'storageProvider': _resolveStorageProvider(data),
        'hasImage': _hasImage(data),
        'witnesses': _resolveWitnesses(data),
      };
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _incidentReportsStream() {
    return FirebaseFirestore.instance
        .collection('incident_reports')
        .where('childId', isEqualTo: child.id)
        .snapshots();
  }

  Widget _buildImagePreview({
    required bool hasImage,
    required String mediaPath,
    required String mediaUrl,
    required String publicUrl,
    required String storageProvider,
  }) {
    if (!hasImage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IncidentFreshMediaImage(
          mediaPath: mediaPath,
          mediaUrl: mediaUrl,
          publicUrl: publicUrl,
          storageProvider:
              storageProvider.trim().isEmpty ? 'supabase' : storageProvider,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textLight,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 44,
              color: AppColors.textLight,
            ),
            SizedBox(height: 10),
            Text(
              'لا توجد تقارير حالياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تقارير الحوادث',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.red.withOpacity(0.14),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  child: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incidentReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'حدث خطأ أثناء تحميل التقارير\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final docs = _prepareIncidentReports(rawDocs);

                if (docs.isEmpty) {
                  return _emptyState();
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index];

                    final incidentType = (data['incidentType'] ?? '').toString();
                    final priority = (data['priority'] ?? '').toString();
                    final autoRisk = (data['autoRisk'] ?? '').toString();
                    final details = (data['details'] ?? '').toString();
                    final actionTaken = (data['actionTaken'] ?? '').toString();
                    final incidentPlace =
                        (data['incidentPlace'] ?? '').toString();
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final createdByRole =
                        (data['createdByRole'] ?? '').toString();
                    final displayDateTime =
                        data['displayDateTime'] as DateTime?;
                    final mediaPath = (data['mediaPath'] ?? '').toString();
                    final mediaUrl = (data['mediaUrl'] ?? '').toString();
                    final publicUrl = (data['publicUrl'] ?? '').toString();
                    final storageProvider =
                        (data['storageProvider'] ?? '').toString();
                    final hasImage = data['hasImage'] == true;
                    final witnesses =
                        (data['witnesses'] as List<String>?) ?? [];

                    final resolvedPriority =
                        priority.trim().isNotEmpty ? priority : autoRisk;
                    final priorityColor = _priorityColor(resolvedPriority);

                    final senderText = [
                      if (createdByName.trim().isNotEmpty)
                        createdByName.trim(),
                      if (_roleLabel(createdByRole).trim().isNotEmpty)
                        _roleLabel(createdByRole).trim(),
                    ].join(' - ');

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      priorityColor.withOpacity(0.12),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: priorityColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _incidentTypeLabel(incidentType),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDateTime(displayDateTime),
                                        style: const TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _priorityLabel(resolvedPriority),
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _buildImagePreview(
                              hasImage: hasImage,
                              mediaPath: mediaPath,
                              mediaUrl: mediaUrl,
                              publicUrl: publicUrl,
                              storageProvider: storageProvider,
                            ),
                            const SizedBox(height: 4),
                            _infoRow(
                              icon: Icons.location_on_outlined,
                              label: 'المكان',
                              value: incidentPlace,
                            ),
                            _infoRow(
                              icon: Icons.description_outlined,
                              label: 'التفاصيل',
                              value: details,
                            ),
                            _infoRow(
                              icon: Icons.medical_services_outlined,
                              label: 'الإجراء',
                              value: actionTaken,
                            ),
                            if (witnesses.isNotEmpty)
                              _infoRow(
                                icon: Icons.groups_outlined,
                                label: 'الشهود',
                                value: witnesses.join('، '),
                              ),
                            _infoRow(
                              icon: Icons.badge_outlined,
                              label: 'تم بواسطة',
                              value: senderText,
                            ),
                          ],
                        ),
                      ),
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

class IncidentFreshMediaImage extends StatefulWidget {
  final String mediaPath;
  final String mediaUrl;
  final String publicUrl;
  final String storageProvider;

  const IncidentFreshMediaImage({
    super.key,
    required this.mediaPath,
    required this.mediaUrl,
    required this.publicUrl,
    required this.storageProvider,
  });

  @override
  State<IncidentFreshMediaImage> createState() =>
      _IncidentFreshMediaImageState();
}

class _IncidentFreshMediaImageState extends State<IncidentFreshMediaImage> {
  final GalleryService _galleryService = GalleryService();

  late Future<String?> _futureUrl;

  @override
  void initState() {
    super.initState();
    _futureUrl = _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant IncidentFreshMediaImage oldWidget) {
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
            height: 160,
            width: double.infinity,
            color: AppColors.primary.withOpacity(0.06),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }

        final url = snapshot.data ?? '';

        if (url.trim().isEmpty) {
          return const _BrokenIncidentImageBox();
        }

        return Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const _BrokenIncidentImageBox();
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;

            return Container(
              height: 160,
              width: double.infinity,
              color: AppColors.primary.withOpacity(0.06),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          },
        );
      },
    );
  }
}

class _BrokenIncidentImageBox extends StatelessWidget {
  const _BrokenIncidentImageBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        'تعذر عرض صورة الحادث',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
