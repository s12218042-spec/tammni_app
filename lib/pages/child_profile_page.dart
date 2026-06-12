import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'gallery_page.dart';
import 'parent_handoff_log_page.dart';
import 'parent_incident_reports_page.dart';
import 'parent_updates_page.dart';

class ChildProfilePage extends StatefulWidget {
  final ChildModel child;

  const ChildProfilePage({
    super.key,
    required this.child,
  });

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    if (years <= 0) return '$months شهر';
    if (months == 0) return '$years سنة';
    return '$years سنة و $months شهر';
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1).toUpperCase();
  }

  Future<Map<String, dynamic>?> fetchChildDetails() async {
    final doc =
        await _firestore.collection('children').doc(widget.child.id).get();

    if (!doc.exists) return null;

    final data = doc.data()!;

    return {
      'id': doc.id,
      'name': data['name'] ?? widget.child.name,
      'birthDate': data['birthDate'] ??
          (widget.child.birthDate != null
              ? Timestamp.fromDate(widget.child.birthDate!)
              : null),
      'isActive': data['isActive'] ?? true,
      'status': data['status'] ?? 'active',
    };
  }

  void openUpdatesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentUpdatesPage(child: widget.child),
      ),
    );
  }

  void openIncidentReportsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentIncidentReportsPage(child: widget.child),
      ),
    );
  }

  void openHandoffLogPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentHandoffLogPage(child: widget.child),
      ),
    );
  }

  void openGalleryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPage(child: widget.child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return AppPageScaffold(
      title: 'ملف الطفل',
      child: FutureBuilder<Map<String, dynamic>?>(
        future: fetchChildDetails(),
        builder: (context, childSnapshot) {
          final currentData = childSnapshot.data;

          final currentName = (currentData?['name'] ?? child.name).toString();

          final birthDateRaw = currentData?['birthDate'];
          final currentBirthDate = birthDateRaw is Timestamp
              ? birthDateRaw.toDate()
              : child.birthDate;

          return ListView(
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
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        firstLetter(currentName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        currentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _ProfileSectionHeader(
                title: 'النظرة العامة',
                icon: Icons.dashboard_outlined,
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ProfileInfoBox(
                        icon: Icons.cake_outlined,
                        title: 'العمر',
                        value: childAgeText(currentBirthDate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _ProfileNavigationCard(
                title: 'متابعة الطفل',
                subtitle: '',
                icon: Icons.notifications_none_outlined,
                onTap: openUpdatesPage,
              ),
              const SizedBox(height: 12),
              _ProfileNavigationCard(
                title: 'تقارير المتابعة',
                subtitle: '',
                icon: Icons.report_problem_outlined,
                onTap: openIncidentReportsPage,
              ),
              const SizedBox(height: 12),
              _ProfileNavigationCard(
                title: 'الاستلام والتسليم',
                subtitle: '',
                icon: Icons.how_to_reg_outlined,
                onTap: openHandoffLogPage,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: openGalleryPage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('فتح معرض الصور'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _ProfileSectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
            textAlign: TextAlign.center,
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

class _ProfileNavigationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileNavigationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(
                icon,
                color: AppColors.primary,
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
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}