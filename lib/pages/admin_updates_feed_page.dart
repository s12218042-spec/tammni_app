import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminUpdatesFeedPage extends StatefulWidget {
  const AdminUpdatesFeedPage({super.key});

  @override
  State<AdminUpdatesFeedPage> createState() => _AdminUpdatesFeedPageState();
}

class _AdminUpdatesFeedPageState extends State<AdminUpdatesFeedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Set<String> selectedSections = {};
  final Set<String> selectedTypes = {};
  String searchText = '';

  final List<String> nurseryTypes = [
  'group_update',
  'نشاط جماعي',
  'وجبة جماعية',
  'فعالية',
  'صورة جماعية',
  'فيديو جماعي',
  'إعلان',
  'ملاحظة عامة',
  'وجبة',
  'نوم',
  'صحة',
  'نشاط',
  'ملاحظة',
  'كاميرا',
  'وسائط',
];


 List<String> get availableTypes => nurseryTypes;

  String sectionLabel(String value) {
  return 'الحضانة';
}

  String typeLabel(String value) {
  switch (value.trim()) {
    case 'group_update':
      return 'تحديث جماعي';
    case 'meal':
    case 'وجبة':
      return 'وجبة';
    case 'sleep':
    case 'نوم':
      return 'نوم';
    case 'health':
    case 'صحة':
      return 'صحة';
    case 'activity':
    case 'نشاط':
      return 'نشاط';
    case 'entry':
      return 'دخول';
    case 'exit':
      return 'خروج';
    case 'note':
    case 'ملاحظة':
      return 'ملاحظة';
    case 'نشاط جماعي':
      return 'نشاط جماعي';
    case 'وجبة جماعية':
      return 'وجبة جماعية';
    case 'فعالية':
      return 'فعالية';
    case 'صورة جماعية':
      return 'صورة جماعية';
    case 'فيديو جماعي':
      return 'فيديو جماعي';
    case 'إعلان':
      return 'إعلان';
    case 'ملاحظة عامة':
      return 'ملاحظة عامة';
    case 'كاميرا':
      return 'كاميرا';
    case 'وسائط':
      return 'وسائط';
    default:
      return value.trim().isEmpty ? 'تحديث' : value;
  }
}

  IconData typeIcon(String value) {
  switch (value.trim()) {
    case 'group_update':
    case 'نشاط جماعي':
    case 'وجبة جماعية':
    case 'فعالية':
    case 'صورة جماعية':
    case 'فيديو جماعي':
    case 'إعلان':
    case 'ملاحظة عامة':
      return Icons.groups_2_rounded;
    case 'meal':
    case 'وجبة':
      return Icons.restaurant_rounded;
    case 'sleep':
    case 'نوم':
      return Icons.bedtime_rounded;
    case 'health':
    case 'صحة':
      return Icons.medical_services_rounded;
    case 'activity':
    case 'نشاط':
      return Icons.extension_rounded;
    case 'entry':
      return Icons.login_rounded;
    case 'exit':
      return Icons.logout_rounded;
    case 'note':
    case 'ملاحظة':
      return Icons.sticky_note_2_rounded;
    case 'كاميرا':
    case 'وسائط':
      return Icons.photo_library_outlined;
    default:
      return Icons.notifications_active_rounded;
  }
}

  Color typeColor(String value) {
  switch (value.trim()) {
    case 'group_update':
    case 'نشاط جماعي':
    case 'وجبة جماعية':
    case 'فعالية':
    case 'صورة جماعية':
    case 'فيديو جماعي':
    case 'إعلان':
    case 'ملاحظة عامة':
      return Colors.purple;
    case 'meal':
    case 'وجبة':
      return Colors.orange;
    case 'sleep':
    case 'نوم':
      return Colors.indigo;
    case 'health':
    case 'صحة':
      return Colors.redAccent;
    case 'activity':
    case 'نشاط':
      return Colors.green;
    case 'entry':
      return Colors.green;
    case 'exit':
      return Colors.deepOrange;
    case 'note':
    case 'ملاحظة':
      return Colors.brown;
    case 'كاميرا':
    case 'وسائط':
      return AppColors.secondary;
    default:
      return AppColors.primary;
  }
}

  Color sectionColor(String section) {
  return const Color(0xFFEFA7C8);
}

  DateTime extractDate(Map<String, dynamic> data) {
  final value = data['eventAt'] ??
      data['time'] ??
      data['createdAt'] ??
      data['timestamp'] ??
      data['updatedAt'];

  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  return DateTime.fromMillisecondsSinceEpoch(0);
}

  String formatDateTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'بدون وقت';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '$year/$month/$day - $hour:$minute $period';
  }

  void toggleSectionFilter(String value) {
    setState(() {
      if (selectedSections.contains(value)) {
        selectedSections.remove(value);
      } else {
        selectedSections.add(value);
      }

      selectedTypes.removeWhere((type) => !availableTypes.contains(type));
    });
  }

  void toggleTypeFilter(String value) {
    setState(() {
      if (selectedTypes.contains(value)) {
        selectedTypes.remove(value);
      } else {
        selectedTypes.add(value);
      }
    });
  }

  void clearFilters() {
    setState(() {
      selectedSections.clear();
      selectedTypes.clear();
      searchText = '';
    });
  }
  
  bool _isGroupUpdate(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString().trim().toLowerCase();
  final source = (data['source'] ?? '').toString().trim().toLowerCase();
  final updateSource =
      (data['updateSource'] ?? '').toString().trim().toLowerCase();

  return data['isGroupUpdate'] == true ||
      type == 'group_update' ||
      source == 'group_update' ||
      updateSource == 'group_update' ||
      data['groupUpdateId'] != null;
}

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilters(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  return docs.where((doc) {
    final data = doc.data();

    final section = (data['section'] ?? '').toString().trim();
    final type = (data['type'] ??
            data['updateType'] ??
            data['category'] ??
            '')
        .toString()
        .trim();

    final isGroupUpdate = _isGroupUpdate(data);

    final childName =
        (data['childName'] ?? data['name'] ?? '').toString();

    final createdByName =
        (data['createdByName'] ?? data['senderName'] ?? '').toString();

    final groupName =
        (data['groupName'] ?? data['group'] ?? '').toString();

    final notes = (data['note'] ??
            data['notes'] ??
            data['description'] ??
            data['text'] ??
            data['message'] ??
            data['body'] ??
            '')
        .toString();

    final matchesSection =
        section.trim().isEmpty || section.trim() == 'Nursery';

    final matchesType = selectedTypes.isEmpty ||
        selectedTypes.contains(type) ||
        (selectedTypes.contains('group_update') && isGroupUpdate);

    final query = searchText.trim().toLowerCase();

    final matchesSearch = query.isEmpty ||
        childName.toLowerCase().contains(query) ||
        createdByName.toLowerCase().contains(query) ||
        groupName.toLowerCase().contains(query) ||
        notes.toLowerCase().contains(query);

    return matchesSection && matchesType && matchesSearch;
  }).toList();
}

  Widget buildSectionChip({
    required String label,
    required String value,
  }) {
    final isSelected = selectedSections.contains(value);
    final color = sectionColor(value);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => toggleSectionFilter(value),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? color : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget buildTypeChip({
    required String value,
  }) {
    final isSelected = selectedTypes.contains(value);
    final color = typeColor(value);

    return FilterChip(
      label: Text(
        typeLabel(value),
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      avatar: Icon(
        typeIcon(value),
        size: 16,
        color: isSelected ? Colors.white : color,
      ),
      selected: isSelected,
      onSelected: (_) => toggleTypeFilter(value),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? color : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFilters =
        selectedSections.isNotEmpty ||
        selectedTypes.isNotEmpty ||
        searchText.trim().isNotEmpty;

    return AppPageScaffold(
      title: 'سجل تحديثات الأطفال',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                     hintText: 'ابحثي باسم الطفل أو المنشئ',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchText.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                setState(() {
                                  searchText = '';
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchText = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'نوع التحديث',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (availableTypes.isEmpty)
                    const Text(
                      'لا توجد أنواع متاحة للفلاتر المختارة حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTypes.map((type) {
                        return buildTypeChip(value: type);
                      }).toList(),
                    ),
                  if (hasCustomFilters) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: clearFilters,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('إعادة تعيين الفلاتر'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('updates')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل سجل التحديثات:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = applyFilters(docs);

                if (filteredDocs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.inbox_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'لا توجد تحديثات مطابقة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasCustomFilters
                                ? 'جرّبي تغيير الفلاتر أو البحث بكلمات أخرى.'
                                : 'لا توجد تحديثات حالياً.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data();

                    final isGroupUpdate = _isGroupUpdate(data);

                    final rawType = (data['type'] ??
                      data['updateType'] ??
                      data['category'] ??
                       '')
                     .toString()
                     .trim();

                    final type = isGroupUpdate ? 'group_update' : rawType;
                    final childName =
                        (data['childName'] ?? data['name'] ?? 'طفل').toString();
                    final createdByName =
                        (data['createdByName'] ?? 'مستخدم غير معروف').toString();
                    final createdByRole =
                        (data['createdByRole'] ?? '').toString();
                    final section = (data['section'] ?? '').toString();
                    final groupName =
                        (data['groupName'] ?? data['group'] ?? '').toString().trim();

                    final targetScopeLabel =
                        (data['targetScopeLabel'] ??
                   ((data['targetScope'] ?? '').toString() == 'all_nursery'
                   ? 'كل أطفال الحضانة'
                   : (data['targetScope'] ?? '').toString() == 'my_group'
                    ? 'مجموعتي فقط'
                    : ''))
                    .toString()
                    .trim();
                    final details = (data['note'] ??
        data['notes'] ??
        data['description'] ??
        data['text'] ??
        data['message'] ??
        data['body'] ??
        '')
    .toString();

                    final time = extractDate(data);
                    final color = typeColor(type);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withOpacity(0.12),
                                  child: Icon(
                                    typeIcon(type),
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        childName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                         _InfoChip(
  label: typeLabel(type),
  icon: typeIcon(type),
  color: color,
),

if (isGroupUpdate)
  _InfoChip(
    label: 'تحديث جماعي',
    icon: Icons.groups_2_rounded,
    color: Colors.purple,
  ),

if (isGroupUpdate && groupName.isNotEmpty)
  _InfoChip(
    label: 'المجموعة: $groupName',
    icon: Icons.group_outlined,
    color: Colors.purple,
  ),

if (isGroupUpdate && targetScopeLabel.isNotEmpty)
  _InfoChip(
    label: targetScopeLabel,
    icon: Icons.send_outlined,
    color: Colors.purple,
  ),

if (section.isNotEmpty)
  _InfoChip(
    label: sectionLabel(section),
    icon: Icons.apartment_rounded,
    color: AppColors.primary,
  ),
                                            _InfoChip(
                                              label: sectionLabel(section),
                                              icon: Icons.apartment_rounded,
                                              color: AppColors.primary,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'أُضيف بواسطة: $createdByName'
                              '${createdByRole.isNotEmpty ? ' • $createdByRole' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'الوقت: ${formatDateTime(time)}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (details.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  details,
                                  style: const TextStyle(height: 1.5),
                                ),
                              ),
                            ],
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

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}