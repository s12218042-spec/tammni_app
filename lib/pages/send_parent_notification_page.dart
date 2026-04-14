import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
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

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {
        'uid': '',
        'name': 'مستخدم غير معروف',
        'role': '',
      };
    }

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final data = userDoc.data() ?? {};

    return {
      'uid': currentUser.uid,
      'name': (data['displayName'] ??
              data['name'] ??
              data['username'] ??
              'مستخدم')
          .toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  Future<Map<String, String>> fetchParentLinkInfo() async {
    String parentUid = widget.child.parentUid.trim();
    String parentUsername = widget.child.parentUsername.trim().toLowerCase();

    try {
      final childDoc =
          await _firestore.collection('children').doc(widget.child.id).get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? <String, dynamic>{};

        final docParentUid = (data['parentUid'] ?? '').toString().trim();
        final docParentUsername =
            (data['parentUsername'] ?? '').toString().trim().toLowerCase();

        if (docParentUid.isNotEmpty) {
          parentUid = docParentUid;
        }

        if (docParentUsername.isNotEmpty) {
          parentUsername = docParentUsername;
        }
      }
    } catch (_) {
      // fallback على بيانات child الحالية
    }

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
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

  String helperText() {
    switch (selectedTemplate) {
      case 'health':
        return 'اكتبي ملاحظة صحية مختصرة وواضحة، مثل تعب بسيط أو متابعة دواء أو ملاحظة تحتاج انتباه الأهل.';
      case 'media':
        return 'استخدمي هذا النوع عندما يتم إرسال صورة أو فيديو جديد متعلق بالطفل أو نشاطه.';
      case 'supplies':
        return 'اكتبي المستلزمات المطلوبة بشكل مباشر، مثل ملابس إضافية أو مناديل أو أدوات خاصة.';
      case 'care':
        return 'هذا النوع مناسب للمتابعة اليومية العامة، مثل الأكل أو اللعب أو التفاعل أو الراحة.';
      case 'note':
        return 'استخدميه لأي ملاحظة عامة قصيرة تريدين إيصالها لوليّ الأمر.';
      default:
        return 'اكتبي رسالة مخصصة وواضحة كما تريدين إرسالها تمامًا للأهل.';
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

  Future<void> sendNotification() async {
    final finalMessage = buildMessage().trim();

    if (selectedTemplate == 'custom' && finalMessage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي الرسالة أولًا')),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      final parentInfo = await fetchParentLinkInfo();

      await _firestore.collection('notifications').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUid': parentInfo['parentUid'],
        'parentUsername': parentInfo['parentUsername'],
        'section': widget.child.section,
        'group': widget.child.group,
        'title': buildTitle(),
        'body': finalMessage,
        'message': finalMessage,
        'type': 'nursery_notification',
        'templateType': selectedTemplate,
        'priority': selectedPriority,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
        'byRole': userInfo['role'],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الإشعار بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إرسال الإشعار: $e')),
      );
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إرسال إشعار للأهل',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'اختاري نوع الإشعار، أضيفي التفاصيل إذا لزم، وراجعي المعاينة قبل الإرسال. هذه الصفحة مخصصة لإرسال إشعارات سريعة وواضحة لوليّ الأمر.',
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

  Widget buildReceiverCard() {
    final groupText = widget.child.group.trim().isEmpty
        ? 'غير محددة'
        : widget.child.group;

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
                const Text(
                  'سيتم إرسال الإشعار إلى وليّ أمر:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
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
                  'القسم: ${widget.child.section == 'Nursery' ? 'حضانة' : 'روضة'}  •  المجموعة: $groupText',
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

  Widget buildSectionTitle(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.8,
                    color: AppColors.textLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget buildHelperCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              helperText(),
              style: const TextStyle(
                fontSize: 13.2,
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detailsLabel(),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك ترك الحقل فارغًا في بعض الأنواع الجاهزة، وسيتم تكوين الرسالة تلقائيًا.',
            style: const TextStyle(
              fontSize: 12.8,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
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
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أولوية الإشعار',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اختاري مستوى الأهمية المناسب. هذه الإضافة آمنة ولا تؤثر على الصفحات الأخرى.',
            style: TextStyle(
              fontSize: 12.8,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
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
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معاينة الإشعار',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      priorityColor(selectedPriority).withOpacity(0.12),
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
                        preview.isEmpty
                            ? 'ستظهر معاينة الرسالة هنا'
                            : preview,
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
                child: CircularProgressIndicator(strokeWidth: 2),
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
          const SizedBox(height: 16),
          buildSectionTitle(
            'نوع الإشعار',
            'اختاري القالب الأقرب للحالة لتقليل الحيرة وتسريع الإرسال.',
            Icons.widgets_outlined,
          ),
          const SizedBox(height: 12),
          buildTemplateCards(),
          const SizedBox(height: 12),
          buildHelperCard(),
          const SizedBox(height: 16),
          buildSectionTitle(
            'تفاصيل الرسالة',
            'أضيفي نصًا مساعدًا عند الحاجة، خاصة إذا كان الإشعار يحتاج توضيحًا إضافيًا.',
            Icons.message_outlined,
          ),
          const SizedBox(height: 12),
          buildMessageCard(),
          const SizedBox(height: 16),
          buildSectionTitle(
            'الأولوية',
            'حددي أهمية الإشعار بشكل واضح قبل إرساله.',
            Icons.priority_high_rounded,
          ),
          const SizedBox(height: 12),
          buildPriorityCard(),
          const SizedBox(height: 16),
          buildSectionTitle(
            'المعاينة النهائية',
            'راجعي الشكل النهائي الذي سيصل لوليّ الأمر.',
            Icons.remove_red_eye_outlined,
          ),
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