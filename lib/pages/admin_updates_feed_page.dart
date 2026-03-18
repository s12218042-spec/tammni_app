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

  String selectedSection = 'all';
  String selectedType = 'all';
  String searchText = '';

  final List<String> nurseryTypes = [
    'meal',
    'sleep',
    'health',
    'activity',
    'entry',
    'exit',
    'note',
  ];

  final List<String> kindergartenTypes = [
    'attendance',
    'activity',
    'homework',
    'grade',
    'note',
  ];

  List<String> get availableTypes {
    if (selectedSection == 'Nursery') {
      return ['all', ...nurseryTypes];
    }

    if (selectedSection == 'Kindergarten') {
      return ['all', ...kindergartenTypes];
    }

    return [
      'all',
      'meal',
      'sleep',
      'health',
      'activity',
      'attendance',
      'homework',
      'grade',
      'entry',
      'exit',
      'note',
    ];
  }

  String sectionLabel(String value) {
    switch (value) {
      case 'Nursery':
        return 'الحضانة';
      case 'Kindergarten':
        return 'الروضة';
      case 'all':
        return 'كل الأقسام';
      default:
        return value;
    }
  }

  String typeLabel(String value) {
    switch (value) {
      case 'all':
        return 'كل الأنواع';
      case 'meal':
        return 'وجبة';
      case 'sleep':
        return 'نوم';
      case 'health':
        return 'صحة';
      case 'activity':
        return 'نشاط';
      case 'attendance':
        return 'حضور';
      case 'homework':
        return 'واجب';
      case 'grade':
        return 'علامة';
      case 'entry':
        return 'دخول';
      case 'exit':
        return 'خروج';
      case 'note':
        return 'ملاحظة';
      default:
        return value;
    }
  }

  IconData typeIcon(String value) {
    switch (value) {
      case 'meal':
        return Icons.restaurant_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'activity':
        return Icons.extension_rounded;
      case 'attendance':
        return Icons.fact_check_rounded;
      case 'homework':
        return Icons.assignment_rounded;
      case 'grade':
        return Icons.grade_rounded;
      case 'entry':
        return Icons.login_rounded;
      case 'exit':
        return Icons.logout_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color typeColor(String value) {
    switch (value) {
      case 'meal':
        return Colors.orange;
      case 'sleep':
        return Colors.indigo;
      case 'health':
        return Colors.redAccent;
      case 'activity':
        return Colors.green;
      case 'attendance':
        return Colors.teal;
      case 'homework':
        return Colors.deepPurple;
      case 'grade':
        return Colors.blue;
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.deepOrange;
      case 'note':
        return Colors.brown;
      default:
        return AppColors.primary;
    }
  }

  DateTime extractDate(Map<String, dynamic> data) {
    final value = data['time'] ?? data['createdAt'];

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      final section = (data['section'] ?? '').toString().trim();
      final type = (data['type'] ?? '').toString().trim();
      final childName = (data['childName'] ?? data['name'] ?? '').toString();
      final createdByName = (data['createdByName'] ?? '').toString();
      final group = (data['group'] ?? '').toString();
      final notes = (data['notes'] ??
              data['description'] ??
              data['text'] ??
              data['message'] ??
              '')
          .toString();

      final matchesSection =
          selectedSection == 'all' || section == selectedSection;

      final matchesType = selectedType == 'all' || type == selectedType;

      final query = searchText.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          childName.toLowerCase().contains(query) ||
          createdByName.toLowerCase().contains(query) ||
          group.toLowerCase().contains(query) ||
          notes.toLowerCase().contains(query);

      return matchesSection && matchesType && matchesSearch;
    }).toList();
  }

  void onSectionChanged(String? value) {
    final newSection = value ?? 'all';

    setState(() {
      selectedSection = newSection;

      if (!availableTypes.contains(selectedType)) {
        selectedType = 'all';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'سجل التحديثات الإداري',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'ابحثي باسم الطفل أو المنشئ أو المجموعة',
                      prefixIcon: const Icon(Icons.search_rounded),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedSection,
                          decoration: InputDecoration(
                            labelText: 'القسم',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('كل الأقسام'),
                            ),
                            DropdownMenuItem(
                              value: 'Nursery',
                              child: Text('الحضانة'),
                            ),
                            DropdownMenuItem(
                              value: 'Kindergarten',
                              child: Text('الروضة'),
                            ),
                          ],
                          onChanged: onSectionChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'نوع التحديث',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: availableTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(typeLabel(type)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedType = value ?? 'all';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
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
                          const Text(
                            'جرّبي تغيير الفلاتر أو البحث بكلمات أخرى.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
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

                    final type = (data['type'] ?? '').toString().trim();
                    final childName =
                        (data['childName'] ?? data['name'] ?? 'طفل').toString();
                    final createdByName =
                        (data['createdByName'] ?? 'مستخدم غير معروف').toString();
                    final createdByRole =
                        (data['createdByRole'] ?? '').toString();
                    final section = (data['section'] ?? '').toString();
                    final group = (data['group'] ?? '').toString();
                    final details = (data['notes'] ??
                            data['description'] ??
                            data['text'] ??
                            data['message'] ??
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
                                          if (section.isNotEmpty)
                                            _InfoChip(
                                              label: sectionLabel(section),
                                              icon: Icons.apartment_rounded,
                                              color: AppColors.primary,
                                            ),
                                          if (group.isNotEmpty)
                                            _InfoChip(
                                              label: 'المجموعة: $group',
                                              icon: Icons.groups_rounded,
                                              color: Colors.teal,
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