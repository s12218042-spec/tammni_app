import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../utils/child_section_utils.dart';
import '../widgets/app_page_scaffold.dart';
import 'entry_exit_log_page.dart';

class ManageChildrenPage extends StatefulWidget {
  const ManageChildrenPage({super.key});

  @override
  State<ManageChildrenPage> createState() => _ManageChildrenPageState();
}

class _ManageChildrenPageState extends State<ManageChildrenPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedView = 'active'; // active / archived / all
  String searchText = '';

  String sectionLabel(String section) {
    return ChildSectionUtils.sectionArabicLabel(section);
  }

  Color sectionColor(String section) {
    if (section == 'Nursery') return const Color(0xFFEFA7C8);
    if (section == 'Kindergarten') return const Color(0xFF7BB6FF);
    if (section == 'OutOfRange') return Colors.redAccent;
    return AppColors.primary;
  }

  Future<List<Map<String, dynamic>>> fetchChildren() async {
    final snapshot = await _firestore.collection('children').get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'identityNumber': data['identityNumber'] ?? '',
        'gender': data['gender'] ?? 'female',
        'section': data['section'] ?? 'Nursery',
        'group': data['group'] ?? '',
        'birthDate': data['birthDate'],
        'isActive': data['isActive'] ?? true,
        'status': data['status'] ?? 'active',
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'history': (data['history'] as List?) ?? [],
        'parentName': data['parentName'] ?? '',
        'parentUsername': data['parentUsername'] ?? '',
        'parentUid': data['parentUid'] ?? '',

        'hasChronicDiseases': data['hasChronicDiseases'] ?? false,
        'chronicDiseases': data['chronicDiseases'] ?? '',
        'hasAllergies': data['hasAllergies'] ?? false,
        'allergies': data['allergies'] ?? '',
        'takesMedications': data['takesMedications'] ?? false,
        'medications': data['medications'] ?? '',
        'hasDietaryRestrictions': data['hasDietaryRestrictions'] ?? false,
        'dietaryRestrictions': data['dietaryRestrictions'] ?? '',
        'hasSpecialNeeds': data['hasSpecialNeeds'] ?? false,
        'specialNeeds': data['specialNeeds'] ?? '',
        'healthNotes': data['healthNotes'] ?? '',
        'authorizedPickupContacts':
            (data['authorizedPickupContacts'] as List?) ?? [],
      };
    }).toList();

    final filteredByStatus = items.where((child) {
      final isActive = child['isActive'] == true;

      if (selectedView == 'active') return isActive;
      if (selectedView == 'archived') return !isActive;
      return true;
    }).toList();

    final query = searchText.trim().toLowerCase();

    final filtered = filteredByStatus.where((child) {
      final name = (child['name'] ?? '').toString().toLowerCase();
      final identity = (child['identityNumber'] ?? '').toString().toLowerCase();
      final section = (child['section'] ?? '').toString().toLowerCase();
      final group = (child['group'] ?? '').toString().toLowerCase();

      return query.isEmpty ||
          name.contains(query) ||
          identity.contains(query) ||
          section.contains(query) ||
          group.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return filtered;
  }

  String formatBirthDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  int? calculateAge(dynamic raw) {
    if (raw is Timestamp) {
      return ChildSectionUtils.calculateAgeInYears(raw.toDate());
    }
    return null;
  }

  String genderLabel(String value) {
    return value == 'male' ? 'ذكر' : 'أنثى';
  }

  String healthSummary(Map<String, dynamic> child) {
    final items = <String>[];

    if (child['hasChronicDiseases'] == true) items.add('مرض مزمن');
    if (child['hasAllergies'] == true) items.add('حساسية');
    if (child['takesMedications'] == true) items.add('أدوية');
    if (child['hasDietaryRestrictions'] == true) items.add('قيود غذائية');
    if (child['hasSpecialNeeds'] == true) items.add('احتياجات خاصة');

    if (items.isEmpty) return 'لا توجد ملاحظات صحية بارزة';
    return items.join(' • ');
  }

  ChildModel mapToChildModel(Map<String, dynamic> child) {
  return ChildModel.fromMap(
    {
      'name': child['name'] ?? '',
      'section': child['section'] ?? '',
      'group': child['group'] ?? '',
      'parentName': child['parentName'] ?? '',
      'parentUsername': child['parentUsername'] ?? '',
      'birthDate': child['birthDate'],
      'isActive': child['isActive'] ?? true,
      'status': child['status'] ?? 'active',
    },
    docId: (child['id'] ?? '').toString(),
  );
}

  Future<void> openEntryExitLog(Map<String, dynamic> child) async {
    final childModel = mapToChildModel(child);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryExitLogPage(child: childModel),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> showChildForm({
    required Map<String, dynamic> child,
  }) async {
    final nameCtrl = TextEditingController(text: child['name'] ?? '');
    final identityNumberCtrl =
        TextEditingController(text: child['identityNumber'] ?? '');
    final groupCtrl = TextEditingController(text: child['group'] ?? '');
    final healthNotesCtrl =
        TextEditingController(text: child['healthNotes'] ?? '');

    final chronicDiseasesCtrl =
        TextEditingController(text: child['chronicDiseases'] ?? '');
    final allergiesCtrl =
        TextEditingController(text: child['allergies'] ?? '');
    final medicationsCtrl =
        TextEditingController(text: child['medications'] ?? '');
    final dietaryRestrictionsCtrl =
        TextEditingController(text: child['dietaryRestrictions'] ?? '');
    final specialNeedsCtrl =
        TextEditingController(text: child['specialNeeds'] ?? '');

    DateTime selectedBirthDate = child['birthDate'] is Timestamp
        ? (child['birthDate'] as Timestamp).toDate()
        : DateTime(2023, 1, 1);

    String selectedSection =
        ChildSectionUtils.resolveSectionAndGroup(selectedBirthDate).section;

    String selectedGender = (child['gender'] ?? 'female').toString();

    bool hasChronicDiseases = child['hasChronicDiseases'] == true;
    bool hasAllergies = child['hasAllergies'] == true;
    bool takesMedications = child['takesMedications'] == true;
    bool hasDietaryRestrictions = child['hasDietaryRestrictions'] == true;
    bool hasSpecialNeeds = child['hasSpecialNeeds'] == true;

    final List<_PickupContactEditor> pickupContacts =
        ((child['authorizedPickupContacts'] as List?) ?? [])
            .map((e) => _PickupContactEditor.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();

    if (pickupContacts.isEmpty) {
      pickupContacts.add(_PickupContactEditor());
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تعديل بيانات الطفل'),
                content: SizedBox(
                  width: 470,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اسم الطفل',
                              prefixIcon: Icon(Icons.child_care_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'اكتب اسم الطفل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: identityNumberCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'رقم هوية الطفل',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'أدخل رقم هوية الطفل';
                              if (!RegExp(r'^\d{9}$').hasMatch(text)) {
                                return 'رقم الهوية يجب أن يتكون من 9 أرقام';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'الجنس',
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('أنثى'),
                              ),
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('ذكر'),
                              ),
                            ],
                            onChanged: (value) {
                              setLocalState(() {
                                selectedGender = value ?? 'female';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedBirthDate,
                                firstDate: DateTime(2015),
                                lastDate: DateTime.now(),
                              );

                              if (picked != null) {
                                setLocalState(() {
                                  selectedBirthDate = picked;
                                  selectedSection = ChildSectionUtils
                                      .resolveSectionAndGroup(picked)
                                      .section;

                                  if (!ChildSectionUtils.shouldShowGroupField(
                                      selectedSection)) {
                                    groupCtrl.clear();
                                  }
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تاريخ الميلاد',
                                prefixIcon:
                                    Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                '${selectedBirthDate.year}/${selectedBirthDate.month}/${selectedBirthDate.day}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'القسم',
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                            child: Text(
                              ChildSectionUtils.sectionArabicLabel(
                                  selectedSection),
                            ),
                          ),
                          if (selectedSection == 'OutOfRange') ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.25),
                                ),
                              ),
                              child: const Text(
                                'عمر الطفل أكبر من نطاق الحضانة/الروضة في النظام الحالي.',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (ChildSectionUtils.shouldShowGroupField(
                              selectedSection)) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: groupCtrl,
                              decoration: const InputDecoration(
                                labelText: 'المجموعة / الصف',
                                prefixIcon: Icon(Icons.groups_2_outlined),
                              ),
                              validator: (value) {
                                if (ChildSectionUtils.shouldShowGroupField(
                                        selectedSection) &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'اكتب المجموعة / الصف';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'البيانات الصحية',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: hasChronicDiseases,
                            onChanged: (value) {
                              setLocalState(() {
                                hasChronicDiseases = value;
                                if (!value) chronicDiseasesCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل أمراض مزمنة؟'),
                          ),
                          if (hasChronicDiseases) ...[
                            TextFormField(
                              controller: chronicDiseasesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الأمراض المزمنة',
                                prefixIcon:
                                    Icon(Icons.monitor_heart_outlined),
                              ),
                              validator: (value) {
                                if (hasChronicDiseases &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الأمراض المزمنة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: hasAllergies,
                            onChanged: (value) {
                              setLocalState(() {
                                hasAllergies = value;
                                if (!value) allergiesCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل حساسية؟'),
                          ),
                          if (hasAllergies) ...[
                            TextFormField(
                              controller: allergiesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الحساسية',
                                prefixIcon:
                                    Icon(Icons.warning_amber_rounded),
                              ),
                              validator: (value) {
                                if (hasAllergies &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الحساسية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: takesMedications,
                            onChanged: (value) {
                              setLocalState(() {
                                takesMedications = value;
                                if (!value) medicationsCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'هل يتناول الطفل أدوية بشكل مستمر؟',
                            ),
                          ),
                          if (takesMedications) ...[
                            TextFormField(
                              controller: medicationsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الأدوية',
                                prefixIcon: Icon(Icons.medication_outlined),
                              ),
                              validator: (value) {
                                if (takesMedications &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الأدوية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: hasDietaryRestrictions,
                            onChanged: (value) {
                              setLocalState(() {
                                hasDietaryRestrictions = value;
                                if (!value) dietaryRestrictionsCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل قيود غذائية؟'),
                          ),
                          if (hasDietaryRestrictions) ...[
                            TextFormField(
                              controller: dietaryRestrictionsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل القيود الغذائية',
                                prefixIcon:
                                    Icon(Icons.restaurant_menu_rounded),
                              ),
                              validator: (value) {
                                if (hasDietaryRestrictions &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل القيود الغذائية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: hasSpecialNeeds,
                            onChanged: (value) {
                              setLocalState(() {
                                hasSpecialNeeds = value;
                                if (!value) specialNeedsCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل احتياجات خاصة؟'),
                          ),
                          if (hasSpecialNeeds) ...[
                            TextFormField(
                              controller: specialNeedsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الاحتياجات الخاصة',
                                prefixIcon: Icon(Icons.accessible_rounded),
                              ),
                              validator: (value) {
                                if (hasSpecialNeeds &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الاحتياجات الخاصة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: healthNotesCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات صحية عامة',
                              prefixIcon:
                                  Icon(Icons.health_and_safety_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'المخولون بالاستلام',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(pickupContacts.length, (index) {
                            final pickup = pickupContacts[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'الشخص ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      if (pickupContacts.length > 1)
                                        IconButton(
                                          onPressed: () {
                                            setLocalState(() {
                                              pickup.dispose();
                                              pickupContacts.removeAt(index);
                                            });
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                          color: Colors.redAccent,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: pickup.nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'الاسم',
                                      prefixIcon:
                                          Icon(Icons.person_outline_rounded),
                                    ),
                                    validator: (value) {
                                      if ((value?.trim() ?? '').isEmpty) {
                                        return 'أدخل الاسم';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: pickup.relationCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'صلة القرابة',
                                      prefixIcon:
                                          Icon(Icons.family_restroom_rounded),
                                    ),
                                    validator: (value) {
                                      if ((value?.trim() ?? '').isEmpty) {
                                        return 'أدخل صلة القرابة';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: pickup.phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'رقم الجوال',
                                      prefixIcon: Icon(Icons.phone_rounded),
                                    ),
                                    validator: (value) {
                                      final clean = (value ?? '').trim();
                                      if (clean.isEmpty) {
                                        return 'أدخل رقم الجوال';
                                      }
                                      if (!RegExp(r'^(059|056)\d{7}$')
                                          .hasMatch(clean)) {
                                        return 'رقم جوال فلسطيني غير صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setLocalState(() {
                                  pickupContacts.add(_PickupContactEditor());
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة شخص مخوّل آخر'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final resolvedSection = ChildSectionUtils
                          .resolveSectionAndGroup(selectedBirthDate)
                          .section;
                      final resolvedGroup =
                          ChildSectionUtils.shouldShowGroupField(
                                  resolvedSection)
                              ? groupCtrl.text.trim()
                              : '';

                      if (resolvedSection == 'OutOfRange') {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'عمر الطفل أكبر من نطاق الحضانة/الروضة في النظام الحالي',
                            ),
                          ),
                        );
                        return;
                      }

                      final oldSection = (child['section'] ?? '').toString();
                      final oldGroup = (child['group'] ?? '').toString();
                      final oldHistory = List<Map<String, dynamic>>.from(
                        (child['history'] as List?) ?? [],
                      );

                      List<Map<String, dynamic>> newHistory = oldHistory;
                      final nowTs = Timestamp.now();

                      final sectionChanged = oldSection != resolvedSection;
                      final groupChanged = oldGroup != resolvedGroup;

                      if (sectionChanged || groupChanged) {
                        newHistory = oldHistory.map((item) {
                          final updated = Map<String, dynamic>.from(item);
                          if (updated['to'] == null) {
                            updated['to'] = nowTs;
                          }
                          return updated;
                        }).toList();

                        newHistory.add({
                          'section': resolvedSection,
                          'group': resolvedGroup,
                          'from': nowTs,
                          'to': null,
                        });
                      }

                      await _firestore
                          .collection('children')
                          .doc(child['id'])
                          .update({
                        'name': nameCtrl.text.trim(),
                        'identityNumber': identityNumberCtrl.text.trim(),
                        'gender': selectedGender,
                        'birthDate': Timestamp.fromDate(selectedBirthDate),
                        'section': resolvedSection,
                        'group': resolvedGroup,
                        'hasChronicDiseases': hasChronicDiseases,
                        'chronicDiseases': hasChronicDiseases
                            ? chronicDiseasesCtrl.text.trim()
                            : '',
                        'hasAllergies': hasAllergies,
                        'allergies':
                            hasAllergies ? allergiesCtrl.text.trim() : '',
                        'takesMedications': takesMedications,
                        'medications':
                            takesMedications ? medicationsCtrl.text.trim() : '',
                        'hasDietaryRestrictions': hasDietaryRestrictions,
                        'dietaryRestrictions': hasDietaryRestrictions
                            ? dietaryRestrictionsCtrl.text.trim()
                            : '',
                        'hasSpecialNeeds': hasSpecialNeeds,
                        'specialNeeds':
                            hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
                        'healthNotes': healthNotesCtrl.text.trim(),
                        'authorizedPickupContacts':
                            pickupContacts.map((e) => e.toMap()).toList(),
                        'updatedAt': FieldValue.serverTimestamp(),
                        'history': newHistory,
                      });

                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث بيانات الطفل بنجاح'),
                        ),
                      );
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

    nameCtrl.dispose();
    identityNumberCtrl.dispose();
    groupCtrl.dispose();
    healthNotesCtrl.dispose();
    chronicDiseasesCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    dietaryRestrictionsCtrl.dispose();
    specialNeedsCtrl.dispose();
    for (final pickup in pickupContacts) {
      pickup.dispose();
    }
  }

  Future<void> archiveChild(Map<String, dynamic> child) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('أرشفة الطفل'),
              content: Text(
                'هل تريد أرشفة الطفل "${child['name']}"؟\n\nلن يتم حذفه من قاعدة البيانات، لكنه سيختفي من الأطفال النشطين.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('أرشفة'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    await _firestore.collection('children').doc(child['id']).update({
      'isActive': false,
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت أرشفة الطفل')),
    );
  }

  Future<void> restoreChild(Map<String, dynamic> child) async {
    await _firestore.collection('children').doc(child['id']).update({
      'isActive': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت استعادة الطفل إلى القائمة النشطة')),
    );
  }

  Widget buildTopFilter({
    required String label,
    required String value,
  }) {
    final isSelected = selectedView == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedView = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.14),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChildCard(Map<String, dynamic> child) {
    final name = (child['name'] ?? '').toString();
    final section = (child['section'] ?? '').toString();
    final group = (child['group'] ?? '').toString();
    final identityNumber = (child['identityNumber'] ?? '').toString();
    final gender = (child['gender'] ?? 'female').toString();
    final isActive = child['isActive'] == true;
    final color = sectionColor(section);
    final age = calculateAge(child['birthDate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  name.isEmpty ? 'ط' : name.substring(0, 1),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'بدون اسم' : name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.isNotEmpty
                          ? '${sectionLabel(section)} • $group'
                          : sectionLabel(section),
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  isActive ? 'نشط' : 'مؤرشف',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (identityNumber.isNotEmpty)
            _infoRow(Icons.badge_outlined, 'رقم الهوية', identityNumber),
          if (identityNumber.isNotEmpty) const SizedBox(height: 8),
          _infoRow(Icons.wc_outlined, 'الجنس', genderLabel(gender)),
          const SizedBox(height: 8),
          _infoRow(
            Icons.calendar_today_outlined,
            'تاريخ الميلاد',
            formatBirthDate(child['birthDate']),
          ),
          if (age != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.cake_outlined, 'العمر', '$age سنة'),
          ],
          const SizedBox(height: 8),
          _infoRow(
            Icons.health_and_safety_outlined,
            'الحالة الصحية',
            healthSummary(child),
          ),
          const SizedBox(height: 14),
          if (section == 'Nursery') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => openEntryExitLog(child),
                icon: const Icon(Icons.login_outlined),
                label: const Text('السجل الإداري للدخول والخروج'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showChildForm(child: child),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isActive) {
                      archiveChild(child);
                    } else {
                      restoreChild(child);
                    }
                  },
                  icon: Icon(
                    isActive
                        ? Icons.archive_outlined
                        : Icons.restore_outlined,
                  ),
                  label: Text(isActive ? 'أرشفة' : 'استعادة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة الأطفال',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'ملاحظة: هذه الصفحة مخصصة لإدارة بيانات الأطفال فقط. إضافة طفل جديد لم تعد من هنا، بل تتم عبر طلبات إضافة طفل يرسلها ولي الأمر وتراجعها الإدارة. كما أن تسجيل دخول وخروج أطفال الحضانة يتم من خلال السجل الإداري فقط.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحثي باسم الطفل أو رقم الهوية أو القسم أو المجموعة',
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
          const SizedBox(height: 16),
          Row(
            children: [
              buildTopFilter(label: 'النشطون', value: 'active'),
              const SizedBox(width: 10),
              buildTopFilter(label: 'المؤرشفون', value: 'archived'),
              const SizedBox(width: 10),
              buildTopFilter(label: 'الكل', value: 'all'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchChildren(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل الأطفال',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final children = snapshot.data ?? [];

                if (children.isEmpty) {
                  return Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.child_care_outlined,
                            size: 52,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'لا يوجد أطفال في هذه القائمة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedView == 'active'
                                ? 'لا يوجد أطفال نشطون حاليًا'
                                : selectedView == 'archived'
                                    ? 'لا يوجد أطفال مؤرشفون حاليًا'
                                    : 'لا توجد بيانات بعد',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      return buildChildCard(children[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupContactEditor {
  final nameCtrl = TextEditingController();
  final relationCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  _PickupContactEditor();

  factory _PickupContactEditor.fromMap(Map<String, dynamic> data) {
    final editor = _PickupContactEditor();
    editor.nameCtrl.text = (data['name'] ?? '').toString();
    editor.relationCtrl.text = (data['relation'] ?? '').toString();
    editor.phoneCtrl.text = (data['phone'] ?? '').toString();
    return editor;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameCtrl.text.trim(),
      'relation': relationCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
    };
  }

  void dispose() {
    nameCtrl.dispose();
    relationCtrl.dispose();
    phoneCtrl.dispose();
  }
}