import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class SendParentNotificationPage extends StatefulWidget {
  final ChildModel child;

  const SendParentNotificationPage({
    super.key,
    required this.child,
  });

  @override
  State<SendParentNotificationPage> createState() =>
      _SendParentNotificationPageState();
}

class _SendParentNotificationPageState
    extends State<SendParentNotificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController messageCtrl = TextEditingController();

  bool isSending = false;
  String selectedTemplate = 'care';
  String selectedPriority = 'normal';

  final List<Map<String, dynamic>> templates = const [
    {
      'value': 'care',
      'label': 'متابعة يومية',
      'icon': Icons.favorite_border_rounded,
    },
    {
      'value': 'health',
      'label': 'ملاحظة صحية',
      'icon': Icons.health_and_safety_outlined,
    },
    {
      'value': 'supplies',
      'label': 'مستلزمات',
      'icon': Icons.inventory_2_outlined,
    },
    {
      'value': 'media',
      'label': 'وسائط',
      'icon': Icons.perm_media_outlined,
    },
    {
      'value': 'note',
      'label': 'ملاحظة',
      'icon': Icons.sticky_note_2_outlined,
    },
    {
      'value': 'custom',
      'label': 'رسالة مخصصة',
      'icon': Icons.edit_note_rounded,
    },
  ];

  @override
  void dispose() {
    messageCtrl.dispose();
    super.dispose();
  }

  String normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  String templateNotificationType(String value) {
    switch (value.trim().toLowerCase()) {
      case 'health':
        return 'health';
      case 'supplies':
        return 'supplies';
      case 'media':
        return 'media';
      case 'custom':
        return 'custom';
      case 'care':
      case 'note':
      default:
        return 'nursery_notification';
    }
  }

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {
        'uid': '',
        'name': 'مستخدم غير معروف',
        'role': 'nursery_staff',
        'username': '',
      };
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final data = userDoc.data() ?? <String, dynamic>{};

      final role = normalizeRole((data['role'] ?? '').toString());

      return {
        'uid': currentUser.uid,
        'name': (data['displayName'] ??
                data['name'] ??
                data['fullName'] ??
                data['username'] ??
                currentUser.displayName ??
                'مستخدم')
            .toString()
            .trim(),
        'role': role.isEmpty ? 'nursery_staff' : role,
        'username': (data['username'] ?? '').toString().trim().toLowerCase(),
      };
    } catch (_) {
      return {
        'uid': currentUser.uid,
        'name': currentUser.displayName?.trim().isNotEmpty == true
            ? currentUser.displayName!.trim()
            : 'مستخدم',
        'role': 'nursery_staff',
        'username': '',
      };
    }
  }

  Future<Map<String, String>> fetchParentLinkInfo() async {
    String parentUid = widget.child.parentUid.trim();
    String parentUsername = widget.child.parentUsername.trim().toLowerCase();
    String parentName = widget.child.parentName.trim();

    try {
      final childDoc =
          await _firestore.collection('children').doc(widget.child.id).get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? <String, dynamic>{};

        final docParentUid = (data['parentUid'] ?? '').toString().trim();
        final docParentUsername =
            (data['parentUsername'] ?? '').toString().trim().toLowerCase();
        final docParentName = (data['parentName'] ?? '').toString().trim();

        if (docParentUid.isNotEmpty) {
          parentUid = docParentUid;
        }

        if (docParentUsername.isNotEmpty) {
          parentUsername = docParentUsername;
        }

        if (docParentName.isNotEmpty) {
          parentName = docParentName;
        }
      }
    } catch (_) {}

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
    };
  }

  String buildTitle() {
    switch (selectedTemplate) {
      case 'health':
        return 'ملاحظة صحية من الحضانة';
      case 'media':
        return 'وسائط جديدة من الحضانة';
      case 'supplies':
        return 'مستلزمات مطلوبة';
      case 'care':
        return 'متابعة يومية من الحضانة';
      case 'note':
        return 'ملاحظة من الحضانة';
      default:
        return 'إشعار من الحضانة';
    }
  }

  String buildMessage() {
    final custom = messageCtrl.text.trim();

    switch (selectedTemplate) {
      case 'media':
        return custom.isEmpty
            ? 'تمت إضافة صورة أو فيديو جديد لـ ${widget.child.name}.'
            : 'تمت إضافة صورة أو فيديو جديد لـ ${widget.child.name}: $custom';
      case 'health':
        return custom.isEmpty
            ? 'هناك ملاحظة صحية تخص ${widget.child.name}، يرجى المتابعة.'
            : 'ملاحظة صحية تخص ${widget.child.name}: $custom';
      case 'supplies':
        return custom.isEmpty
            ? 'يرجى تزويد ${widget.child.name} بالمستلزمات المطلوبة.'
            : 'يرجى تزويد ${widget.child.name} بـ: $custom';
      case 'care':
        return custom.isEmpty
            ? 'تمت متابعة ${widget.child.name} اليوم داخل الحضانة.'
            : 'متابعة اليوم لـ ${widget.child.name}: $custom';
      case 'note':
        return custom.isEmpty
            ? 'هناك ملاحظة جديدة تخص ${widget.child.name}.'
            : 'ملاحظة تخص ${widget.child.name}: $custom';
      default:
        return custom;
    }
  }

  String detailsLabel() {
    switch (selectedTemplate) {
      case 'health':
        return 'تفاصيل الملاحظة الصحية';
      case 'media':
        return 'وصف الوسائط';
      case 'supplies':
        return 'المستلزمات المطلوبة';
      case 'care':
        return 'تفاصيل المتابعة اليومية';
      case 'note':
        return 'تفاصيل الملاحظة';
      default:
        return 'نص الرسالة';
    }
  }

  String detailsHint() {
    switch (selectedTemplate) {
      case 'health':
        return 'مثال: يعاني اليوم من سعال خفيف وتمت متابعته.';
      case 'media':
        return 'مثال: صورة من النشاط الفني اليوم.';
      case 'supplies':
        return 'مثال: مناديل مبللة وملابس إضافية.';
      case 'care':
        return 'مثال: شارك اليوم بالنشاط وتناول وجبته بشكل جيد.';
      case 'note':
        return 'مثال: كان هادئًا اليوم ويحتاج متابعة بسيطة.';
      default:
        return 'اكتبي الرسالة التي تريدين إرسالها للأهل.';
    }
  }

  String priorityLabel(String value) {
    switch (value) {
      case 'urgent':
        return 'عاجل';
      case 'important':
        return 'مهم';
      default:
        return 'عادي';
    }
  }

  Color priorityColor(String value) {
    switch (value) {
      case 'urgent':
        return Colors.redAccent;
      case 'important':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData priorityIcon(String value) {
    switch (value) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'important':
        return Icons.priority_high_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  IconData templateIcon(String value) {
    final item = templates.firstWhere(
      (e) => e['value'] == value,
      orElse: () => templates.first,
    );
    return item['icon'] as IconData;
  }

  void showSnack(
    String message, {
    Color backgroundColor = Colors.redAccent,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> sendNotification() async {
    final finalMessage = buildMessage().trim();

    if (selectedTemplate == 'custom' && finalMessage.isEmpty) {
      showSnack('اكتبي الرسالة أولًا');
      return;
    }

    if (finalMessage.isEmpty) {
      showSnack('لا يمكن إرسال إشعار فارغ');
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();

      final parentUid = (parentInfo['parentUid'] ?? '').trim();
      final parentUsername =
          (parentInfo['parentUsername'] ?? '').trim().toLowerCase();
      final parentName = (parentInfo['parentName'] ?? '').trim();

      if (parentUid.isEmpty && parentUsername.isEmpty) {
        throw Exception('لا يوجد ولي أمر مرتبط بهذا الطفل لإرسال الإشعار');
      }

      final title = buildTitle();
      final notificationType = templateNotificationType(selectedTemplate);

      await AppNotificationService.instance.createNotification(
        title: title,
        body: finalMessage,
        type: notificationType,
        notificationFor: 'parent',
        priority: selectedPriority,
        targetUid: parentUid,
        targetUsername: parentUsername,
        targetRole: 'parent',
        parentUid: parentUid,
        parentUsername: parentUsername,
        parentName: parentName,
        childId: widget.child.id,
        childName: widget.child.name,
        section: widget.child.section,
        group: widget.child.group,
        createdByUid: userInfo['uid'] ?? '',
        createdByName: userInfo['name'] ?? 'مستخدم',
        createdByRole: userInfo['role'] ?? 'nursery_staff',
        extraData: {
          'targetName': parentName,
          'subject': title,
          'notificationTitle': title,
          'message': finalMessage,
          'text': finalMessage,
          'description': finalMessage,
          'notificationType': notificationType,
          'category': selectedTemplate,
          'templateType': selectedTemplate,
          'importance': selectedPriority,
          'level': selectedPriority,
          'createdByUsername': userInfo['username'] ?? '',
          'byRole': userInfo['role'] ?? 'nursery_staff',
          'senderId': userInfo['uid'] ?? '',
          'senderName': userInfo['name'] ?? 'مستخدم',
          'senderRole': userInfo['role'] ?? 'nursery_staff',
          'source': 'send_parent_notification_page',
          'route': 'parent_notifications',
          'relatedCollection': 'notifications',
        },
      );

      if (!mounted) return;

      showSnack(
        'تم إرسال الإشعار بنجاح',
        backgroundColor: Colors.green,
      );

      Navigator.pop(context, true);
    } catch (e) {
      showSnack('حدث خطأ أثناء إرسال الإشعار: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isSending = false;
      });
    }
  }

  Widget buildHeaderCard() {
    return Container(
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'إرسال إشعار للأهل',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReceiverCard() {
    final groupText =
        widget.child.group.trim().isEmpty ? 'غير محددة' : widget.child.group;

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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: const Icon(
              Icons.child_friendly_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.child.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'حضانة  •  $groupText',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget buildTemplateCards() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: templates.map((item) {
        final selected = selectedTemplate == item['value'];

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              selectedTemplate = item['value'] as String;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.border.withOpacity(0.75),
                width: selected ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected
                      ? AppColors.primary.withOpacity(0.18)
                      : AppColors.background,
                  child: Icon(
                    item['icon'] as IconData,
                    color: selected ? AppColors.primary : AppColors.textLight,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildMessageCard() {
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
      child: TextField(
        controller: messageCtrl,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: detailsLabel(),
          hintText: detailsHint(),
          alignLabelWithHint: true,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.border.withOpacity(0.8),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.border.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPriorityCard() {
    final priorities = [
      {'value': 'normal', 'label': 'عادي'},
      {'value': 'important', 'label': 'مهم'},
      {'value': 'urgent', 'label': 'عاجل'},
    ];

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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: priorities.map((item) {
          final value = item['value']!;
          final label = item['label']!;
          final selected = selectedPriority == value;

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  priorityIcon(value),
                  size: 16,
                  color: selected ? Colors.white : priorityColor(value),
                ),
                const SizedBox(width: 6),
                Text(label),
              ],
            ),
            selected: selected,
            selectedColor: priorityColor(value),
            onSelected: (_) {
              setState(() {
                selectedPriority = value;
              });
            },
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: AppColors.background,
            side: BorderSide(
              color: priorityColor(value).withOpacity(0.35),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildPreviewCard() {
    final preview = buildMessage();
    final title = buildTitle();

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: priorityColor(selectedPriority).withOpacity(0.12),
            child: Icon(
              templateIcon(selectedTemplate),
              color: priorityColor(selectedPriority),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الأولوية: ${priorityLabel(selectedPriority)}',
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                    color: priorityColor(selectedPriority),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  preview.isEmpty ? 'ستظهر معاينة الرسالة هنا' : preview,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
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

  Widget buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSending ? null : sendNotification,
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_outlined),
        label: Text(isSending ? 'جاري الإرسال...' : 'إرسال الإشعار'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إرسال إشعار للأهل',
      child: ListView(
        children: [
          buildHeaderCard(),
          const SizedBox(height: 16),
          buildReceiverCard(),
          const SizedBox(height: 18),
          buildSectionTitle('نوع الإشعار', Icons.widgets_outlined),
          const SizedBox(height: 12),
          buildTemplateCards(),
          const SizedBox(height: 18),
          buildSectionTitle('تفاصيل الرسالة', Icons.message_outlined),
          const SizedBox(height: 12),
          buildMessageCard(),
          const SizedBox(height: 18),
          buildSectionTitle('الأولوية', Icons.priority_high_rounded),
          const SizedBox(height: 12),
          buildPriorityCard(),
          const SizedBox(height: 18),
          buildSectionTitle('المعاينة النهائية', Icons.remove_red_eye_outlined),
          const SizedBox(height: 12),
          buildPreviewCard(),
          const SizedBox(height: 20),
          buildSendButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}