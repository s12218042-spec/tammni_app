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

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final raw = _cleanText(value);
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';

    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y/$m/$d';
  }

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

    return {
      'id': doc.id,
      ...doc.data()!,
    };
  }

  ChildModel _resolveChild(Map<String, dynamic>? currentData) {
    if (currentData == null) return widget.child;

    return ChildModel.fromMap(
      currentData,
      docId: widget.child.id,
    );
  }

  String _childTypeText(ChildModel child) {
    if (child.isTrialPendingDecision) return 'بانتظار قرار التجربة';
    if (child.isTrial) return 'طفل تجربة';
    if (child.isTemporaryChild) return 'طفل زائر';
    return '';
  }

  Color _childTypeColor(ChildModel child) {
    if (child.isTrialPendingDecision) return Colors.deepOrange;
    if (child.isTrial) return Colors.orange;
    if (child.isTemporaryChild) return Colors.deepPurple;
    return AppColors.primary;
  }

  DateTime? _periodStart({
    required ChildModel child,
    required Map<String, dynamic>? data,
  }) {
    if (child.isTrial) {
      return _dateFromDynamic(data?['trialStartAt']) ??
          child.trialStartAt ??
          _dateFromDynamic(data?['temporaryAccessStartAt']) ??
          child.temporaryAccessStartAt;
    }

    if (child.isTemporaryChild) {
      return _dateFromDynamic(data?['temporaryAccessStartAt']) ??
          child.temporaryAccessStartAt ??
          _dateFromDynamic(data?['temporaryStartDate']) ??
          _dateFromDynamic(data?['temporaryStartAt']) ??
          child.temporaryStartAt;
    }

    return null;
  }

  DateTime? _periodEnd({
    required ChildModel child,
    required Map<String, dynamic>? data,
  }) {
    if (child.isTrial) {
      return _dateFromDynamic(data?['trialEndAt']) ??
          child.trialEndAt ??
          _dateFromDynamic(data?['temporaryAccessEndAt']) ??
          child.temporaryAccessEndAt;
    }

    if (child.isTemporaryChild) {
      return _dateFromDynamic(data?['temporaryAccessEndAt']) ??
          child.temporaryAccessEndAt ??
          _dateFromDynamic(data?['temporaryEndDate']) ??
          _dateFromDynamic(data?['temporaryEndAt']) ??
          child.temporaryEndAt;
    }

    return null;
  }

  void openUpdatesPage(ChildModel child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentUpdatesPage(child: child),
      ),
    );
  }

  void openIncidentReportsPage(ChildModel child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentIncidentReportsPage(child: child),
      ),
    );
  }

  void openHandoffLogPage(ChildModel child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentHandoffLogPage(child: child),
      ),
    );
  }

  void openGalleryPage(ChildModel child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPage(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'ملف الطفل',
      child: FutureBuilder<Map<String, dynamic>?>(
        future: fetchChildDetails(),
        builder: (context, childSnapshot) {
          final currentData = childSnapshot.data;
          final child = _resolveChild(currentData);

          final currentName = child.displayName.trim().isEmpty
              ? widget.child.name
              : child.displayName;

          final currentBirthDate = child.birthDate;
          final childTypeText = _childTypeText(child);
          final childTypeColor = _childTypeColor(child);
          final periodStart = _periodStart(
            child: child,
            data: currentData,
          );

          final periodEnd = _periodEnd(
            child: child,
            data: currentData,
          );

          return ListView(
            children: [
              if (childSnapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          if (childTypeText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  childTypeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
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
                      const SizedBox(height: 10),
                      _ProfileInfoBox(
                        icon: Icons.groups_2_outlined,
                        title: 'المجموعة',
                        value: child.displayGroup,
                      ),
                      if (childTypeText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _ProfileInfoBox(
                          icon: Icons.flag_outlined,
                          title: 'نوع التسجيل',
                          value: childTypeText,
                          iconColor: childTypeColor,
                        ),
                      ],
                      if (periodStart != null || periodEnd != null) ...[
                        const SizedBox(height: 10),
                        _ProfileInfoBox(
                          icon: Icons.event_available_outlined,
                          title: child.isTrial
                              ? 'فترة تجربة مجانية لمدة 3 أيام'
                              : 'فترة الزيارة',
                          value:
                              '${_formatDate(periodStart)} - ${_formatDate(periodEnd)}',
                          iconColor: child.isTrial ? Colors.orange : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _ProfileNavigationCard(
                title: 'متابعة الطفل',
                subtitle: '',
                icon: Icons.notifications_none_outlined,
                onTap: () => openUpdatesPage(child),
              ),
              const SizedBox(height: 12),
              _ProfileNavigationCard(
                title: 'تقارير المتابعة',
                subtitle: '',
                icon: Icons.report_problem_outlined,
                onTap: () => openIncidentReportsPage(child),
              ),
              const SizedBox(height: 12),
              _ProfileNavigationCard(
                title: 'الاستلام والتسليم',
                subtitle: '',
                icon: Icons.how_to_reg_outlined,
                onTap: () => openHandoffLogPage(child),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => openGalleryPage(child),
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
  final Color? iconColor;

  const _ProfileInfoBox({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppColors.primary;

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
            backgroundColor: resolvedIconColor.withValues(alpha: 0.12),
            child: Icon(
              icon,
              color: resolvedIconColor,
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
            value.trim().isEmpty ? 'غير محدد' : value,
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
                  if (subtitle.trim().isNotEmpty) ...[
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
