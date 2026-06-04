import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminGeneralReportsPage extends StatefulWidget {
  const AdminGeneralReportsPage({super.key});

  @override
  State<AdminGeneralReportsPage> createState() =>
      _AdminGeneralReportsPageState();
}

class _AdminGeneralReportsPageState extends State<AdminGeneralReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;

  int activeChildrenCount = 0;
  int parentsCount = 0;
  int nurseryStaffCount = 0;
  int groupsCount = 0;

  int unpaidInvoicesCount = 0;
  int paidInvoicesCount = 0;
  int overdueInvoicesCount = 0;
  double invoicesTotalAmount = 0;
  double paidInvoicesTotalAmount = 0;
  double unpaidInvoicesTotalAmount = 0;

  int pendingExtraHoursCount = 0;
  double extraHoursTotalAmount = 0;

  int consultationsCount = 0;
  double consultationsTotalAmount = 0;

  int activeLiveStreamsCount = 0;

  int updatesTodayCount = 0;
  int incidentsThisMonthCount = 0;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  String normalizeRole(dynamic value) {
    final role = (value ?? '').toString().trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  String normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();

    if (status.isEmpty) return 'unpaid';
    if (status == 'pending') return 'unpaid';
    if (status == 'not_paid') return 'unpaid';
    if (status == 'notpaid') return 'unpaid';
    if (status == 'partially_paid') return 'partial';

    return status;
  }

  double numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool isActiveChild(Map<String, dynamic> data) {
    final isActiveValue = data['isActive'];

    final status = (data['status'] ?? data['childStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (isActiveValue != null) return isActiveValue == true;

    return status != 'inactive' &&
        status != 'withdrawn' &&
        status != 'rejected_after_trial';
  }

  bool isNurseryChild(Map<String, dynamic> data) {
    final section = (data['section'] ??
            data['childSection'] ??
            data['nurserySection'] ??
            'Nursery')
        .toString()
        .trim()
        .toLowerCase();

    return section.isEmpty ||
        section == 'nursery' ||
        section == 'حضانة' ||
        section == 'nursery_section';
  }

  bool isHiddenInvoice(Map<String, dynamic> data) {
    final status = normalizeStatus(data['status']);
    final paymentStatus = normalizeStatus(data['paymentStatus']);
    final invoiceStatus = normalizeStatus(data['invoiceStatus']);

    const hidden = {
      'superseded',
      'deleted',
      'void',
      'archived',
    };

    return hidden.contains(status) ||
        hidden.contains(paymentStatus) ||
        hidden.contains(invoiceStatus);
  }

  bool isActiveLiveStream(Map<String, dynamic> data) {
    final status = (data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final streamStatus = (data['streamStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final isActiveValue = data['isActive'];
    final activeValue = data['active'];

    final hasEndedAt = data['endedAt'] != null ||
        data['endedTime'] != null ||
        data['endedAtTimestamp'] != null ||
        data['endTime'] != null;

    final isEndedStatus = status == 'ended' ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'inactive' ||
        status == 'pending' ||
        streamStatus == 'ended' ||
        streamStatus == 'completed' ||
        streamStatus == 'cancelled' ||
        streamStatus == 'canceled' ||
        streamStatus == 'inactive' ||
        streamStatus == 'pending';

    if (isEndedStatus || hasEndedAt) return false;
    if (isActiveValue == false || activeValue == false) return false;

    return status == 'active' || streamStatus == 'active';
  }

  DateTime startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime startOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final childrenSnapshot = await _firestore.collection('children').get();
      final usersSnapshot = await _firestore.collection('users').get();
      final groupsSnapshot = await _firestore.collection('groups').get();
      final invoicesSnapshot = await _firestore.collection('invoices').get();
      final extraHoursSnapshot =
          await _firestore.collection('extra_child_hours').get();
      final consultationsSnapshot =
          await _firestore.collection('child_consultations').get();
      QuerySnapshot<Map<String, dynamic>> liveStreamsSnapshot;

      try {
        liveStreamsSnapshot = await _firestore
            .collection('live_streams')
            .where('status', isEqualTo: 'active')
            .get();
      } catch (_) {
        liveStreamsSnapshot = await _firestore.collection('live_streams').get();
      }

      final today = startOfToday();
      final monthStart = startOfMonth();

      int children = 0;
      for (final doc in childrenSnapshot.docs) {
        final data = doc.data();
        if (isActiveChild(data) && isNurseryChild(data)) {
          children++;
        }
      }

      int parents = 0;
      int staff = 0;

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = normalizeRole(data['role']);
        final isActive = data['isActive'] != false;

        if (!isActive) continue;

        if (role == 'parent') parents++;
        if (role == 'nursery_staff') staff++;
      }

      int activeGroups = 0;
      for (final doc in groupsSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        final isActive = data['isActive'] != false &&
            data['active'] != false &&
            status != 'inactive' &&
            status != 'disabled';

        if (isActive) activeGroups++;
      }

      int unpaidCount = 0;
      int paidCount = 0;
      int overdueCount = 0;
      double allInvoicesTotal = 0;
      double paidTotal = 0;
      double unpaidTotal = 0;

      for (final doc in invoicesSnapshot.docs) {
        final data = doc.data();
        if (isHiddenInvoice(data)) continue;

        final status = normalizeStatus(data['status'] ?? data['paymentStatus']);
        final amount = numValue(data['totalAmount']);

        allInvoicesTotal += amount;

        if (status == 'paid') {
          paidCount++;
          paidTotal += amount;
        } else if (status == 'overdue') {
          overdueCount++;
          unpaidTotal += amount;
        } else if (status == 'cancelled' || status == 'canceled') {
        } else {
          unpaidCount++;
          unpaidTotal += amount;
        }
      }

      int extraPending = 0;
      double extraTotal = 0;

      for (final doc in extraHoursSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().trim().toLowerCase();

        if (status == 'pending_invoice' || status == 'pending') {
          extraPending++;
        }

        extraTotal += numValue(data['totalAmount']);
      }

      int consultationCount = 0;
      double consultationTotal = 0;

      for (final doc in consultationsSnapshot.docs) {
        final data = doc.data();
        consultationCount++;
        consultationTotal += numValue(data['totalAmount']);
      }

      int activeStreams = 0;
      for (final doc in liveStreamsSnapshot.docs) {
        final data = doc.data();

        if (isActiveLiveStream(data)) {
          activeStreams++;
        }
      }

      int todayUpdates = 0;
      try {
        final updatesSnapshot = await _firestore
            .collection('updates')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(today),
            )
            .get();

        todayUpdates = updatesSnapshot.docs.length;
      } catch (_) {
        final updatesSnapshot = await _firestore.collection('updates').get();

        for (final doc in updatesSnapshot.docs) {
          final data = doc.data();
          final value = data['createdAt'] ?? data['time'] ?? data['timestamp'];

          if (value is Timestamp && value.toDate().isAfter(today)) {
            todayUpdates++;
          }
        }
      }

      int monthIncidents = 0;
      try {
        final incidentsSnapshot = await _firestore
            .collection('incident_reports')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
            )
            .get();

        monthIncidents = incidentsSnapshot.docs.length;
      } catch (_) {
        final incidentsSnapshot =
            await _firestore.collection('incident_reports').get();

        for (final doc in incidentsSnapshot.docs) {
          final data = doc.data();
          final value = data['createdAt'] ?? data['time'] ?? data['timestamp'];

          if (value is Timestamp && value.toDate().isAfter(monthStart)) {
            monthIncidents++;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        activeChildrenCount = children;
        parentsCount = parents;
        nurseryStaffCount = staff;
        groupsCount = activeGroups;

        unpaidInvoicesCount = unpaidCount;
        paidInvoicesCount = paidCount;
        overdueInvoicesCount = overdueCount;
        invoicesTotalAmount = allInvoicesTotal;
        paidInvoicesTotalAmount = paidTotal;
        unpaidInvoicesTotalAmount = unpaidTotal;

        pendingExtraHoursCount = extraPending;
        extraHoursTotalAmount = extraTotal;

        consultationsCount = consultationCount;
        consultationsTotalAmount = consultationTotal;

        activeLiveStreamsCount = activeStreams;

        updatesTodayCount = todayUpdates;
        incidentsThisMonthCount = monthIncidents;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  String amount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  Widget buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.16),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التقارير العامة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget reportSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 19,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statsGrid(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.15,
      children: children,
    );
  }

  Widget summaryTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textLight,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFinanceDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            summaryTile(
              icon: Icons.receipt_long_outlined,
              title: 'إجمالي قيمة الفواتير',
              value: '${amount(invoicesTotalAmount)} شيكل',
            ),
            summaryTile(
              icon: Icons.verified_rounded,
              title: 'إجمالي الفواتير المدفوعة',
              value: '${amount(paidInvoicesTotalAmount)} شيكل',
            ),
            summaryTile(
              icon: Icons.schedule_rounded,
              title: 'إجمالي غير المدفوع والمتأخر',
              value: '${amount(unpaidInvoicesTotalAmount)} شيكل',
            ),
            summaryTile(
              icon: Icons.access_time_filled_rounded,
              title: 'إجمالي الساعات الإضافية',
              value: '${amount(extraHoursTotalAmount)} شيكل',
            ),
            summaryTile(
              icon: Icons.psychology_alt_outlined,
              title: 'إجمالي الاستشارات',
              value: '${amount(consultationsTotalAmount)} شيكل',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'حدث خطأ أثناء تحميل التقارير',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: loadReports,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'التقارير العامة',
      child: RefreshIndicator(
        onRefresh: loadReports,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? buildErrorState()
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      reportSectionTitle(
                        'ملخص الحضانة',
                        Icons.child_care_rounded,
                      ),
                      statsGrid([
                        statCard(
                          title: 'الأطفال النشطون',
                          value: activeChildrenCount.toString(),
                          icon: Icons.child_care_rounded,
                        ),
                        statCard(
                          title: 'أولياء الأمور',
                          value: parentsCount.toString(),
                          icon: Icons.family_restroom_rounded,
                        ),
                        statCard(
                          title: 'موظفات الحضانة',
                          value: nurseryStaffCount.toString(),
                          icon: Icons.badge_outlined,
                        ),
                        statCard(
                          title: 'المجموعات النشطة',
                          value: groupsCount.toString(),
                          icon: Icons.groups_2_outlined,
                        ),
                      ]),
                      reportSectionTitle(
                        'ملخص الفواتير',
                        Icons.receipt_long_rounded,
                      ),
                      statsGrid([
                        statCard(
                          title: 'غير مدفوعة',
                          value: unpaidInvoicesCount.toString(),
                          icon: Icons.schedule_rounded,
                        ),
                        statCard(
                          title: 'مدفوعة',
                          value: paidInvoicesCount.toString(),
                          icon: Icons.verified_rounded,
                        ),
                        statCard(
                          title: 'متأخرة',
                          value: overdueInvoicesCount.toString(),
                          icon: Icons.warning_amber_rounded,
                        ),
                        statCard(
                          title: 'إجمالي الفواتير',
                          value: '${amount(invoicesTotalAmount)}',
                          subtitle: 'شيكل',
                          icon: Icons.payments_outlined,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      buildFinanceDetailsCard(),
                      reportSectionTitle(
                        'الخدمات والطلبات',
                        Icons.widgets_rounded,
                      ),
                      statsGrid([
                        statCard(
                          title: 'ساعات إضافية غير مفوترة',
                          value: pendingExtraHoursCount.toString(),
                          icon: Icons.access_time_filled_rounded,
                        ),
                        statCard(
                          title: 'الاستشارات',
                          value: consultationsCount.toString(),
                          icon: Icons.psychology_alt_outlined,
                        ),
                        statCard(
                          title: 'بث مباشر نشط',
                          value: activeLiveStreamsCount.toString(),
                          icon: Icons.live_tv_rounded,
                        ),
                      ]),
                      reportSectionTitle(
                        'المتابعة اليومية',
                        Icons.today_rounded,
                      ),
                      statsGrid([
                        statCard(
                          title: 'تحديثات اليوم',
                          value: updatesTodayCount.toString(),
                          icon: Icons.update_rounded,
                        ),
                        statCard(
                          title: 'حوادث هذا الشهر',
                          value: incidentsThisMonthCount.toString(),
                          icon: Icons.report_problem_outlined,
                        ),
                      ]),
                      const SizedBox(height: 90),
                    ],
                  ),
      ),
    );
  }
}

