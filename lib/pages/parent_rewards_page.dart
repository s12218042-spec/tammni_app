import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentRewardsPage extends StatelessWidget {
  final ChildModel child;

  const ParentRewardsPage({
    super.key,
    required this.child,
  });

  String _resolveTitle(Map<String, dynamic> data) {
    final candidates = [
      data['title'],
      data['name'],
      data['label'],
      data['rewardTitle'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return 'تعزيز';
  }

  String _resolveType(Map<String, dynamic> data) {
    final candidates = [
      data['type'],
      data['rewardType'],
      data['category'],
      data['kind'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return 'تشجيع';
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

  String _resolveCreatedByName(Map<String, dynamic> data) {
    final candidates = [
      data['createdByName'],
      data['byName'],
      data['teacherName'],
      data['staffName'],
      data['senderName'],
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
      data['eventAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  String _formatDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  Color _rewardColor(String type) {
    switch (type.trim()) {
      case 'نجمة':
        return Colors.amber;
      case 'شارة':
        return Colors.purple;
      case 'تشجيع':
        return Colors.green;
      case 'إنجاز':
        return AppColors.primary;
      default:
        return AppColors.textLight;
    }
  }

  IconData _rewardIcon(String type) {
    switch (type.trim()) {
      case 'نجمة':
        return Icons.star_rounded;
      case 'شارة':
        return Icons.workspace_premium_rounded;
      case 'تشجيع':
        return Icons.favorite_rounded;
      case 'إنجاز':
        return Icons.emoji_events_rounded;
      default:
        return Icons.celebration_rounded;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRewards() async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection('rewards')
        .where('childId', isEqualTo: child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'title': _resolveTitle(data),
        'type': _resolveType(data),
        'note': _resolveNote(data),
        'createdByName': _resolveCreatedByName(data),
        'displayTime': _resolveTimestamp(data),
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
    return AppPageScaffold(
      title: 'تعزيزات الطفل',
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchRewards(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل التعزيزات',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final docs = snapshot.data ?? [];

                if (docs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 60),
                      _buildEmptyState(),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index];

                    final title = (data['title'] ?? 'تعزيز').toString();
                    final type = (data['type'] ?? 'تشجيع').toString();
                    final note = (data['note'] ?? '').toString();
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final time = data['displayTime'];

                    return _RewardCard(
                      title: title,
                      type: type,
                      note: note,
                      dateText: _formatDate(time),
                      createdByName: createdByName,
                      rewardColor: _rewardColor(type),
                      rewardIcon: _rewardIcon(type),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.14),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعزيزات ${child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك متابعة النجوم والشارات وعبارات التشجيع الخاصة بالطفل.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد تعزيزات مضافة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند إضافة أول تعزيز سيظهر هنا مباشرة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String title;
  final String type;
  final String note;
  final String dateText;
  final String createdByName;
  final Color rewardColor;
  final IconData rewardIcon;

  const _RewardCard({
    required this.title,
    required this.type,
    required this.note,
    required this.dateText,
    required this.createdByName,
    required this.rewardColor,
    required this.rewardIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: rewardColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  rewardIcon,
                  color: rewardColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: rewardColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: rewardColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'التاريخ',
            value: dateText,
          ),
          if (createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'أضيف بواسطة',
              value: createdByName,
            ),
          ],
          if (note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'ملاحظة',
              value: note,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}