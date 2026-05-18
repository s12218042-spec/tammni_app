import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminOffersPage extends StatefulWidget {
  const AdminOffersPage({super.key});

  @override
  State<AdminOffersPage> createState() => _AdminOffersPageState();
}

class _AdminOffersPageState extends State<AdminOffersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSavingDefaults = false;

  CollectionReference<Map<String, dynamic>> get _offersRef =>
      _firestore.collection('subscription_offers');

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> _hasFullGroups() async {
    try {
      final snapshot = await _firestore.collection('groups').get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final isActive = data['isActive'] != false &&
            data['active'] != false &&
            data['disabled'] != true;

        if (!isActive) continue;

        final maxChildren = _numValue(
          data['maxChildren'] ??
              data['capacity'] ??
              data['childrenLimit'] ??
              data['maxCapacity'],
        );

        final currentChildren = _numValue(
          data['currentChildrenCount'] ??
              data['childrenCount'] ??
              data['currentCount'] ??
              data['registeredChildrenCount'],
        );

        if (maxChildren > 0 && currentChildren >= maxChildren) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureDefaultOffers() async {
    if (_isSavingDefaults) return;

    setState(() {
      _isSavingDefaults = true;
    });

    try {
      final now = FieldValue.serverTimestamp();
      final currentUser = _auth.currentUser;

      final defaults = [
        {
          'id': 'base_700',
          'title': 'الاشتراك الأساسي',
          'description': 'اشتراك شهري شامل الغداء ويوم السبت',
          'price': 700.0,
          'discountAmount': 0.0,
          'childrenCount': 1,
          'isActive': true,
          'isDefault': true,
          'includesLunch': true,
          'includesSaturday': true,
          'disableWhenGroupsFull': false,
          'blockedBecauseGroupsFull': false,
          'type': 'base_subscription',
          'createdByUid': currentUser?.uid ?? '',
          'createdAt': now,
          'updatedAt': now,
        },
        {
          'id': 'offer_600',
          'title': 'عرض 600 شيكل',
          'description': 'عرض خاص لطفل واحد حسب قرار الإدارة',
          'price': 600.0,
          'discountAmount': 100.0,
          'childrenCount': 1,
          'isActive': true,
          'isDefault': true,
          'includesLunch': true,
          'includesSaturday': true,
          'disableWhenGroupsFull': true,
          'blockedBecauseGroupsFull': false,
          'type': 'special_offer',
          'createdByUid': currentUser?.uid ?? '',
          'createdAt': now,
          'updatedAt': now,
        },
        {
          'id': 'two_children_1100',
          'title': 'عرض طفلين',
          'description': 'اشتراك شهري لطفلين من نفس ولي الأمر',
          'price': 1100.0,
          'discountAmount': 300.0,
          'childrenCount': 2,
          'isActive': true,
          'isDefault': true,
          'includesLunch': true,
          'includesSaturday': true,
          'disableWhenGroupsFull': true,
          'blockedBecauseGroupsFull': false,
          'type': 'two_children_offer',
          'createdByUid': currentUser?.uid ?? '',
          'createdAt': now,
          'updatedAt': now,
        },
      ];

      final batch = _firestore.batch();

      for (final offer in defaults) {
        final docRef = _offersRef.doc(offer['id'].toString());
        final doc = await docRef.get();

        if (!doc.exists) {
          batch.set(docRef, offer);
        }
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز العروض الأساسية بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تجهيز العروض: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDefaults = false;
        });
      }
    }
  }

  Future<void> _openOfferForm({
    String? offerId,
    Map<String, dynamic>? existingData,
  }) async {
    final titleCtrl = TextEditingController(
      text: (existingData?['title'] ?? '').toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (existingData?['description'] ?? '').toString(),
    );
    final priceCtrl = TextEditingController(
      text: existingData == null
          ? ''
          : ((existingData['price'] ?? 0).toString()),
    );
    final discountCtrl = TextEditingController(
      text: existingData == null
          ? '0'
          : ((existingData['discountAmount'] ?? 0).toString()),
    );
    final childrenCountCtrl = TextEditingController(
      text: existingData == null
          ? '1'
          : ((existingData['childrenCount'] ?? 1).toString()),
    );

    bool isActive = (existingData?['isActive'] ?? true) == true;
    bool includesLunch = (existingData?['includesLunch'] ?? true) == true;
    bool includesSaturday = (existingData?['includesSaturday'] ?? true) == true;
    bool disableWhenGroupsFull =
        (existingData?['disableWhenGroupsFull'] ?? false) == true;
    String selectedType = (existingData?['type'] ?? 'custom_offer').toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(
                  existingData == null ? 'إضافة عرض جديد' : 'تعديل العرض',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم العرض',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'وصف العرض',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر النهائي بالشيكل',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'قيمة الخصم',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: childrenCountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'عدد الأطفال المشمولين',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'نوع العرض',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'base_subscription',
                            child: Text('اشتراك أساسي'),
                          ),
                          DropdownMenuItem(
                            value: 'special_offer',
                            child: Text('عرض خاص'),
                          ),
                          DropdownMenuItem(
                            value: 'two_children_offer',
                            child: Text('عرض طفلين'),
                          ),
                          DropdownMenuItem(
                            value: 'custom_offer',
                            child: Text('عرض مخصص'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedType = value ?? 'custom_offer';
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('العرض فعّال'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('يشمل الغداء'),
                        value: includesLunch,
                        onChanged: (value) {
                          setDialogState(() {
                            includesLunch = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('يشمل يوم السبت'),
                        value: includesSaturday,
                        onChanged: (value) {
                          setDialogState(() {
                            includesSaturday = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تعطيل العرض عند امتلاء المجموعات'),
                        subtitle: const Text(
                          'إذا أصبحت إحدى المجموعات ممتلئة، تستطيع الإدارة تعطيل هذا العرض بسرعة.',
                        ),
                        value: disableWhenGroupsFull,
                        onChanged: (value) {
                          setDialogState(() {
                            disableWhenGroupsFull = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final description = descriptionCtrl.text.trim();
                      final price =
                          double.tryParse(priceCtrl.text.trim()) ?? -1;
                      final discount =
                          double.tryParse(discountCtrl.text.trim()) ?? 0;
                      final childrenCount =
                          int.tryParse(childrenCountCtrl.text.trim()) ?? 1;

                      if (title.isEmpty || price < 0 || childrenCount < 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تأكدي من اسم العرض والسعر وعدد الأطفال',
                            ),
                          ),
                        );
                        return;
                      }

                      final currentUser = _auth.currentUser;
                      final now = FieldValue.serverTimestamp();

                      final data = {
                        'title': title,
                        'description': description,
                        'price': price,
                        'discountAmount': discount,
                        'childrenCount': childrenCount,
                        'isActive': isActive,
                        'includesLunch': includesLunch,
                        'includesSaturday': includesSaturday,
                        'disableWhenGroupsFull': disableWhenGroupsFull,
                        'blockedBecauseGroupsFull': false,
                        'type': selectedType,
                        'updatedAt': now,
                        'updatedByUid': currentUser?.uid ?? '',
                      };

                      try {
                        if (offerId == null) {
                          data.addAll({
                            'createdAt': now,
                            'createdByUid': currentUser?.uid ?? '',
                            'isDefault': false,
                          });

                          await _offersRef.add(data);
                        } else {
                          await _offersRef.doc(offerId).update(data);
                        }

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext, true);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل حفظ العرض: $e')),
                        );
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    descriptionCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
    childrenCountCtrl.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ العرض بنجاح')),
      );
    }
  }

  Future<void> _toggleOfferStatus(String offerId, bool currentStatus) async {
    try {
      await _offersRef.doc(offerId).update({
        'isActive': !currentStatus,
        'blockedBecauseGroupsFull': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': _auth.currentUser?.uid ?? '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus ? 'تم تفعيل العرض' : 'تم تعطيل العرض',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تغيير حالة العرض: $e')),
      );
    }
  }

  Future<void> _disableOfferBecauseGroupsFull(String offerId) async {
    try {
      await _offersRef.doc(offerId).update({
        'isActive': false,
        'blockedBecauseGroupsFull': true,
        'blockedReason': 'groups_full',
        'blockedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': _auth.currentUser?.uid ?? '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعطيل العرض بسبب امتلاء المجموعات'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تعطيل العرض: $e')),
      );
    }
  }

  Future<void> _deleteOffer(String offerId, Map<String, dynamic> data) async {
    final isDefault = (data['isDefault'] ?? false) == true;

    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف العروض الأساسية، يمكن تعطيلها فقط'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العرض'),
          content: const Text('هل أنتِ متأكدة من حذف هذا العرض؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await _offersRef.doc(offerId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العرض')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف العرض: $e')),
      );
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'base_subscription':
        return 'اشتراك أساسي';
      case 'special_offer':
        return 'عرض خاص';
      case 'two_children_offer':
        return 'عرض طفلين';
      case 'custom_offer':
        return 'عرض مخصص';
      default:
        return 'عرض';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'base_subscription':
        return Icons.payments_rounded;
      case 'special_offer':
        return Icons.local_offer_rounded;
      case 'two_children_offer':
        return Icons.family_restroom_rounded;
      case 'custom_offer':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.local_offer_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'العروض والاشتراكات',
      actions: [
        IconButton(
          tooltip: 'تجهيز العروض الأساسية',
          onPressed: _isSavingDefaults ? null : _ensureDefaultOffers,
          icon: _isSavingDefaults
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_rounded),
        ),
      ],
      child: Column(
        children: [
          _HeaderCard(
            onCreateDefaults: _isSavingDefaults ? null : _ensureDefaultOffers,
            onAddOffer: () => _openOfferForm(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<bool>(
              future: _hasFullGroups(),
              builder: (context, groupsSnapshot) {
                final hasFullGroups = groupsSnapshot.data == true;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _offersRef.orderBy('createdAt', descending: false).snapshots(),
                  builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل العروض:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _EmptyOffersBox(
                    onCreateDefaults: _ensureDefaultOffers,
                    onAddOffer: () => _openOfferForm(),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final title = (data['title'] ?? 'عرض بدون اسم').toString();
                    final description =
                        (data['description'] ?? '').toString();
                    final price = (data['price'] ?? 0).toString();
                    final discount =
                        (data['discountAmount'] ?? 0).toString();
                    final childrenCount =
                        (data['childrenCount'] ?? 1).toString();
                    final type = (data['type'] ?? 'custom_offer').toString();
                    final isActive = (data['isActive'] ?? true) == true;
                    final isDefault = (data['isDefault'] ?? false) == true;
                    final includesLunch =
                        (data['includesLunch'] ?? false) == true;
                    final includesSaturday =
                        (data['includesSaturday'] ?? false) == true;
                    final disableWhenGroupsFull =
                        (data['disableWhenGroupsFull'] ?? false) == true;
                    final blockedBecauseGroupsFull =
                        (data['blockedBecauseGroupsFull'] ?? false) == true;
                    final canDisableBecauseGroupsFull =
                        hasFullGroups && disableWhenGroupsFull && isActive;

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
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.10),
                                  child: Icon(
                                    _typeIcon(type),
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _typeLabel(type),
                                        style: const TextStyle(
                                          color: Colors.black54,
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
                                    color: isActive
                                        ? Colors.green.withOpacity(0.12)
                                        : Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isActive ? 'فعّال' : 'معطّل',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green.shade700
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (description.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                description,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoChip(
                                  icon: Icons.payments_rounded,
                                  label: '$price شيكل',
                                ),
                                _InfoChip(
                                  icon: Icons.discount_rounded,
                                  label: 'خصم $discount شيكل',
                                ),
                                _InfoChip(
                                  icon: Icons.child_care_rounded,
                                  label: '$childrenCount طفل',
                                ),
                                if (includesLunch)
                                  const _InfoChip(
                                    icon: Icons.restaurant_rounded,
                                    label: 'يشمل الغداء',
                                  ),
                                if (includesSaturday)
                                  const _InfoChip(
                                    icon: Icons.calendar_month_rounded,
                                    label: 'يشمل السبت',
                                  ),
                                if (disableWhenGroupsFull)
                                  const _InfoChip(
                                    icon: Icons.groups_rounded,
                                    label: 'يتعطل عند الامتلاء',
                                  ),
                                if (isDefault)
                                  const _InfoChip(
                                    icon: Icons.verified_rounded,
                                    label: 'عرض أساسي',
                                  ),
                              ],
                            ),
                            if (blockedBecauseGroupsFull) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.22),
                                  ),
                                ),
                                child: const Text(
                                  'تم تعطيل هذا العرض بسبب امتلاء المجموعات.',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            if (canDisableBecauseGroupsFull) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _disableOfferBecauseGroupsFull(doc.id),
                                  icon: const Icon(Icons.block_rounded),
                                  label: const Text(
                                    'تعطيل الآن بسبب امتلاء المجموعات',
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openOfferForm(
                                      offerId: doc.id,
                                      existingData: data,
                                    ),
                                    icon: const Icon(Icons.edit_rounded),
                                    label: const Text('تعديل'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _toggleOfferStatus(doc.id, isActive),
                                    icon: Icon(
                                      isActive
                                          ? Icons.pause_circle_outline_rounded
                                          : Icons.play_circle_outline_rounded,
                                    ),
                                    label: Text(isActive ? 'تعطيل' : 'تفعيل'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: () => _deleteOffer(doc.id, data),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final VoidCallback? onCreateDefaults;
  final VoidCallback onAddOffer;

  const _HeaderCard({
    required this.onCreateDefaults,
    required this.onAddOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إدارة عروض واشتراكات الحضانة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'من هنا يمكن للإدارة إضافة عروض الاشتراك الشهرية، تعديلها، تفعيلها أو تعطيلها.',
              style: TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddOffer,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة عرض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCreateDefaults,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('العروض الأساسية'),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17, color: AppColors.primary),
      label: Text(label),
      backgroundColor: AppColors.primary.withOpacity(0.08),
      side: BorderSide(color: AppColors.primary.withOpacity(0.12)),
    );
  }
}

class _EmptyOffersBox extends StatelessWidget {
  final VoidCallback onCreateDefaults;
  final VoidCallback onAddOffer;

  const _EmptyOffersBox({
    required this.onCreateDefaults,
    required this.onAddOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.10),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'لا توجد عروض حالياً',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'يمكنك تجهيز العروض الأساسية أو إضافة عرض جديد يدويًا.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreateDefaults,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('تجهيز العروض الأساسية'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAddOffer,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة عرض جديد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
