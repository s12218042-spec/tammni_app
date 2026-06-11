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
  final TextEditingController searchCtrl = TextEditingController();

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

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
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

  void clearFilters() {
    searchCtrl.clear();

    setState(() {
      selectedTypes.clear();
      searchText = '';
    });
  }

  void clearSearch() {
    searchCtrl.clear();

    setState(() {
      searchText = '';
    });
  }

  void openTypeFiltersSheet() {
    final draftSelectedTypes = <String>{...selectedTypes};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'فلترة حسب نوع التحديث',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'يمكنك اختيار أكثر من نوع',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableTypes.map((type) {
                            return buildTypeChip(
                              value: type,
                              selectedValues: draftSelectedTypes,
                              onChanged: (isSelected) {
                                setSheetState(() {
                                  if (isSelected) {
                                    draftSelectedTypes.add(type);
                                  } else {
                                    draftSelectedTypes.remove(type);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: draftSelectedTypes.isEmpty
                                ? null
                                : () {
                                    setSheetState(() {
                                      draftSelectedTypes.clear();
                                    });
                                  },
                            child: const Text('مسح الاختيارات'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedTypes
                                  ..clear()
                                  ..addAll(draftSelectedTypes);
                              });

                              Navigator.pop(sheetContext);
                            },
                            child: const Text('تطبيق'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

      final childName = (data['childName'] ?? data['name'] ?? '').toString();

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

  Widget buildTypeChip({
    required String value,
    required Set<String> selectedValues,
    required ValueChanged<bool> onChanged,
  }) {
    final isSelected = selectedValues.contains(value);
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
      onSelected: onChanged,
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

  Widget compactFiltersCard({
    required bool hasCustomFilters,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ابحث باسم الطفل أو المنشئ',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: clearSearch,
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openTypeFiltersSheet,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(
                      selectedTypes.isEmpty
                          ? 'فلترة حسب النوع'
                          : 'الأنواع المختارة: ${selectedTypes.length}',
                    ),
                  ),
                ),
                if (hasCustomFilters) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'إعادة تعيين الفلاتر',
                    onPressed: clearFilters,
                    icon: const Icon(Icons.restart_alt_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
            if (selectedTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final value = selectedTypes.elementAt(index);
                    final color = typeColor(value);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withOpacity(0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(typeIcon(value), size: 14, color: color),
                          const SizedBox(width: 5),
                          Text(
                            typeLabel(value),
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFilters =
        selectedTypes.isNotEmpty || searchText.trim().isNotEmpty;

    return AppPageScaffold(
      title: 'سجل تحديثات الحضانة',
      child: Column(
        children: [
          compactFiltersCard(
            hasCustomFilters: hasCustomFilters,
          ),
          const SizedBox(height: 10),
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
                    margin: EdgeInsets.zero,
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
                                ? 'جرّب تغيير الفلاتر أو البحث بكلمات أخرى.'
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
                  padding: const EdgeInsets.only(bottom: 18),
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
                    final groupName =
                        (data['groupName'] ?? data['group'] ?? '')
                            .toString()
                            .trim();

                    final targetScopeLabel = (data['targetScopeLabel'] ??
                            ((data['targetScope'] ?? '').toString() ==
                                    'all_nursery'
                                ? 'كل أطفال الحضانة'
                                : (data['targetScope'] ?? '').toString() ==
                                        'my_group'
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
                      margin: const EdgeInsets.only(bottom: 10),
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
                                          if (isGroupUpdate &&
                                              groupName.isNotEmpty)
                                            _InfoChip(
                                              label: 'المجموعة: $groupName',
                                              icon: Icons.group_outlined,
                                              color: Colors.purple,
                                            ),
                                          if (isGroupUpdate &&
                                              targetScopeLabel.isNotEmpty)
                                            _InfoChip(
                                              label: targetScopeLabel,
                                              icon: Icons.send_outlined,
                                              color: Colors.purple,
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
