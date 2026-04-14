import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_assignment_page.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  final Set<String> selectedStatuses = {};
  final Set<String> selectedGroups = {};
  String searchText = '';

  Future<void> refreshPage() async {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic time) {
    if (time is Timestamp) {
      final date = time.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'نشط':
        return AppColors.primary;
      case 'مغلق':
        return Colors.red;
      case 'مكتمل':
        return Colors.green;
      default:
        return AppColors.textLight;
    }
  }

  void _toggleStatus(String value) {
    setState(() {
      if (selectedStatuses.contains(value)) {
        selectedStatuses.remove(value);
      } else {
        selectedStatuses.add(value);
      }
    });
  }

  void _toggleGroup(String value) {
    setState(() {
      if (selectedGroups.contains(value)) {
        selectedGroups.remove(value);
      } else {
        selectedGroups.add(value);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      selectedStatuses.clear();
      selectedGroups.clear();
      searchText = '';
      _searchController.clear();
    });
  }

  List<String> _extractAvailableGroups(List<QueryDocumentSnapshot> docs) {
    final groups = docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['group'] ?? '')
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    groups.sort();
    return groups;
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final title = (data['title'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final subject = (data['subject'] ?? '').toString().toLowerCase();
      final group = (data['group'] ?? '').toString().trim();
      final note = (data['note'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? 'نشط').toString().trim();

      final q = searchText.trim().toLowerCase();

      final matchesSearch = q.isEmpty ||
          title.contains(q) ||
          description.contains(q) ||
          subject.contains(q) ||
          group.toLowerCase().contains(q) ||
          note.contains(q);

      final matchesStatus =
          selectedStatuses.isEmpty || selectedStatuses.contains(status);

      final matchesGroup =
          selectedGroups.isEmpty || selectedGroups.contains(group);

      return matchesSearch && matchesStatus && matchesGroup;
    }).toList();
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedColor ?? AppColors.primary,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? (selectedColor ?? AppColors.primary)
            : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFilters = searchText.trim().isNotEmpty ||
        selectedStatuses.isNotEmpty ||
        selectedGroups.isNotEmpty;

    return AppPageScaffold(
      title: 'الواجبات',
      actions: [
        IconButton(
          tooltip: 'إضافة واجب',
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddAssignmentPage(),
              ),
            );

            if (res == true) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.add),
        ),
      ],
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('assignments')
                  .where('section', isEqualTo: 'Kindergarten')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل الواجبات',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final availableGroups = _extractAvailableGroups(docs);
                final filteredDocs = _applyFilters(docs);

                if (selectedGroups.isNotEmpty) {
                  final validGroups = availableGroups.toSet();
                  selectedGroups.removeWhere((group) => !validGroups.contains(group));
                }

                return RefreshIndicator(
                  onRefresh: refreshPage,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildFiltersCard(
                        availableGroups: availableGroups,
                        hasCustomFilters: hasCustomFilters,
                      ),
                      const SizedBox(height: 16),
                      if (filteredDocs.isEmpty)
                        docs.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: _buildEmptyState(),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: _buildFilteredEmptyState(),
                              )
                      else
                        ...List.generate(filteredDocs.length, (index) {
                          final data =
                              filteredDocs[index].data() as Map<String, dynamic>;

                          final title = data['title'] ?? 'واجب بدون عنوان';
                          final description = data['description'] ?? '';
                          final subject = data['subject'] ?? 'مادة غير محددة';
                          final group = data['group'] ?? '';
                          final dueDate = data['dueDate'];
                          final status = data['status'] ?? 'نشط';
                          final note = data['note'] ?? '';

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == filteredDocs.length - 1 ? 0 : 12,
                            ),
                            child: _AssignmentCard(
                              title: title,
                              description: description,
                              subject: subject,
                              group: group,
                              dueDateText: _formatDate(dueDate),
                              status: status,
                              statusColor: _statusColor(status),
                              note: note,
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard({
    required List<String> availableGroups,
    required bool hasCustomFilters,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحثي بالعنوان أو الوصف أو المادة أو المجموعة',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            searchText = '';
                            _searchController.clear();
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
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
              'الحالة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'نشط',
                  selected: selectedStatuses.contains('نشط'),
                  selectedColor: _statusColor('نشط'),
                  onTap: () => _toggleStatus('نشط'),
                ),
                _buildFilterChip(
                  label: 'مغلق',
                  selected: selectedStatuses.contains('مغلق'),
                  selectedColor: _statusColor('مغلق'),
                  onTap: () => _toggleStatus('مغلق'),
                ),
                _buildFilterChip(
                  label: 'مكتمل',
                  selected: selectedStatuses.contains('مكتمل'),
                  selectedColor: _statusColor('مكتمل'),
                  onTap: () => _toggleStatus('مكتمل'),
                ),
              ],
            ),
            if (availableGroups.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'المجموعة',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableGroups.map((group) {
                  return _buildFilterChip(
                    label: group,
                    selected: selectedGroups.contains(group),
                    selectedColor: Colors.teal,
                    onTap: () => _toggleGroup(group),
                  );
                }).toList(),
              ),
            ],
            if (hasCustomFilters) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('إعادة تعيين الفلاتر'),
                ),
              ),
            ],
          ],
        ),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'واجبات أطفال الروضة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'يمكنكِ من هنا متابعة الواجبات الحالية وإضافة واجبات جديدة.',
            style: TextStyle(
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
            Icons.assignment_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد واجبات مضافة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند إضافة أول واجب سيظهر هنا مباشرة.',
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

  Widget _buildFilteredEmptyState() {
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
            Icons.filter_alt_off_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد واجبات مطابقة للفلاتر',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'جرّبي تغيير البحث أو اختيار حالات ومجموعات مختلفة.',
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

class _AssignmentCard extends StatelessWidget {
  final String title;
  final String description;
  final String subject;
  final String group;
  final String dueDateText;
  final String status;
  final Color statusColor;
  final String note;

  const _AssignmentCard({
    required this.title,
    required this.description,
    required this.subject,
    required this.group,
    required this.dueDateText,
    required this.status,
    required this.statusColor,
    required this.note,
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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.isEmpty ? 'بدون مجموعة' : group,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'الوصف',
            value: description.isEmpty ? 'لا يوجد وصف' : description,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  title: 'المادة',
                  value: subject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  title: 'موعد التسليم',
                  value: dueDateText,
                ),
              ),
            ],
          ),
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