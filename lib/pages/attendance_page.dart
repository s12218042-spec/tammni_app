import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AttendancePage extends StatefulWidget {
  final String sectionFilter; // Kindergarten only here

  const AttendancePage({
    super.key,
    this.sectionFilter = 'Kindergarten',
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  final Map<String, bool> attendanceValues = {};
  final Set<String> selectedGroups = {};
  final Set<String> selectedPresenceFilters = {};

  bool isSaving = false;
  String searchText = '';

  bool get isSupportedSection => widget.sectionFilter == 'Kindergarten';

  String sectionLabel(String section) {
    switch (section) {
      case 'Nursery':
        return 'حضانة';
      case 'Kindergarten':
        return 'روضة';
      default:
        return 'الكل';
    }
  }

  String pageDescription() {
    return 'عرض وتسجيل حضور أطفال قسم الروضة';
  }

  String get dateKey {
    final today = DateTime.now();
    return '${today.year}-${today.month}-${today.day}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ChildModel>> fetchChildren() async {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Kindergarten')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ChildModel.fromMap(data, docId: doc.id);
    }).toList();
  }

  Future<void> loadAttendanceForChildren(List<ChildModel> children) async {
    for (final child in children) {
      if (attendanceValues.containsKey(child.id)) continue;

      final docId = '${child.id}_$dateKey';
      final doc = await _firestore.collection('attendance').doc(docId).get();

      attendanceValues[child.id] =
          doc.exists ? (doc.data()?['present'] == true) : false;
    }
  }

  Future<void> saveAttendance(List<ChildModel> children) async {
    setState(() {
      isSaving = true;
    });

    try {
      for (final child in children) {
        final present = attendanceValues[child.id] ?? false;
        final docId = '${child.id}_$dateKey';

        await _firestore.collection('attendance').doc(docId).set({
          'childId': child.id,
          'childName': child.name,
          'section': child.section,
          'group': child.group,
          'dateKey': dateKey,
          'present': present,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ حضور أطفال الروضة ✅')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الحضور: $e')),
      );
    }

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });
  }

  List<String> extractAvailableGroups(List<ChildModel> children) {
    final groups = children
        .map((child) => child.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList();

    groups.sort();
    return groups;
  }

  List<ChildModel> applyFilters(List<ChildModel> children) {
    return children.where((child) {
      final name = child.name.toLowerCase().trim();
      final group = child.group.trim();
      final isPresent = attendanceValues[child.id] ?? false;

      final query = searchText.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          group.toLowerCase().contains(query);

      final matchesGroup =
          selectedGroups.isEmpty || selectedGroups.contains(group);

      final matchesPresence = selectedPresenceFilters.isEmpty ||
          (selectedPresenceFilters.contains('present') && isPresent) ||
          (selectedPresenceFilters.contains('absent') && !isPresent);

      return matchesSearch && matchesGroup && matchesPresence;
    }).toList();
  }

  void toggleGroup(String value) {
    setState(() {
      if (selectedGroups.contains(value)) {
        selectedGroups.remove(value);
      } else {
        selectedGroups.add(value);
      }
    });
  }

  void togglePresence(String value) {
    setState(() {
      if (selectedPresenceFilters.contains(value)) {
        selectedPresenceFilters.remove(value);
      } else {
        selectedPresenceFilters.add(value);
      }
    });
  }

  void clearFilters() {
    setState(() {
      selectedGroups.clear();
      selectedPresenceFilters.clear();
      searchText = '';
      _searchController.clear();
    });
  }

  Widget buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color selectedColor,
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
      selectedColor: selectedColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? selectedColor : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateText = '${today.year}/${today.month}/${today.day}';

    if (!isSupportedSection) {
      return AppPageScaffold(
        title: 'تسجيل الحضور',
        child: ListView(
          children: [
            Text(
              'تسجيل الحضور',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'هذه الصفحة مخصصة لأطفال الروضة فقط.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.warning.withOpacity(0.12),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'لا يتم استخدام الحضور اليومي الثابت في قسم الحضانة، لأن حضور الطفل يكون مرنًا حسب الزيارة. يمكن متابعة أطفال الحضانة عبر التحديثات والصور والملاحظات.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppPageScaffold(
      title: 'تسجيل الحضور',
      child: FutureBuilder<List<ChildModel>>(
        future: fetchChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final children = snapshot.data ?? [];

          return FutureBuilder<void>(
            future: loadAttendanceForChildren(children),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final availableGroups = extractAvailableGroups(children);
              final filteredChildren = applyFilters(children);

              final hasCustomFilters = searchText.trim().isNotEmpty ||
                  selectedGroups.isNotEmpty ||
                  selectedPresenceFilters.isNotEmpty;

              return ListView(
                children: [
                  Text(
                    'الحضور اليومي',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pageDescription(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'تاريخ اليوم: $dateText',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.school_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'القسم الحالي: روضة',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'ابحثي باسم الطفل أو المجموعة',
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
                              buildFilterChip(
                                label: 'حاضر',
                                selected:
                                    selectedPresenceFilters.contains('present'),
                                selectedColor: Colors.green,
                                onTap: () => togglePresence('present'),
                              ),
                              buildFilterChip(
                                label: 'غائب',
                                selected:
                                    selectedPresenceFilters.contains('absent'),
                                selectedColor: Colors.redAccent,
                                onTap: () => togglePresence('absent'),
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
                                return buildFilterChip(
                                  label: group,
                                  selected: selectedGroups.contains(group),
                                  selectedColor: Colors.teal,
                                  onTap: () => toggleGroup(group),
                                );
                              }).toList(),
                            ),
                          ],
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
                  const SizedBox(height: 16),
                  if (children.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'لا يوجد أطفال في قسم الروضة حاليًا.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  else if (filteredChildren.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.filter_alt_off_outlined,
                              size: 40,
                              color: AppColors.textLight,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'لا يوجد أطفال مطابقون للفلاتر',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'جرّبي تغيير البحث أو المجموعة أو حالة الحضور.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textLight,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredChildren.map(
                      (child) => _AttendanceChildCard(
                        child: child,
                        isPresent: attendanceValues[child.id] ?? false,
                        sectionText: sectionLabel(child.section),
                        onChanged: (value) {
                          setState(() {
                            attendanceValues[child.id] = value;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () => saveAttendance(children),
                    icon: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الحضور'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AttendanceChildCard extends StatelessWidget {
  final ChildModel child;
  final bool isPresent;
  final String sectionText;
  final ValueChanged<bool> onChanged;

  const _AttendanceChildCard({
    required this.child,
    required this.isPresent,
    required this.sectionText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final groupText = child.group.trim().isEmpty ? 'بدون مجموعة' : child.group;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: const Icon(
                Icons.child_care,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sectionText • $groupText',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isPresent,
                  onChanged: onChanged,
                ),
                Text(
                  isPresent ? 'حاضر' : 'غائب',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPresent ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}