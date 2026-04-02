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
  String selectedTemplate = 'custom';

  final List<Map<String, String>> templates = const [
    {'value': 'custom', 'label': 'رسالة مخصصة'},
    {'value': 'media', 'label': 'تمت إضافة صورة/فيديو'},
    {'value': 'health', 'label': 'ملاحظة صحية'},
    {'value': 'supplies', 'label': 'يرجى إحضار مستلزمات'},
    {'value': 'care', 'label': 'متابعة يومية'},
    {'value': 'note', 'label': 'ملاحظة رعاية'},
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
      'name': (data['displayName'] ?? data['username'] ?? 'مستخدم').toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  String buildMessage() {
    final custom = messageCtrl.text.trim();

    switch (selectedTemplate) {
      case 'media':
        return 'تمت إضافة صورة أو فيديو جديد لـ ${widget.child.name}.';
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

  Future<void> sendNotification() async {
    final finalMessage = buildMessage().trim();

    if (finalMessage.isEmpty) {
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

      await _firestore.collection('notifications').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'section': widget.child.section,
        'group': widget.child.group,
        'title': buildTitle(),
        'body': finalMessage,
        'message': finalMessage,
        'type': 'nursery_notification',
        'templateType': selectedTemplate,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'time': FieldValue.serverTimestamp(),
        'createdByUid': userInfo['uid'],
        'createdByName': userInfo['name'],
        'createdByRole': userInfo['role'],
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

  @override
  Widget build(BuildContext context) {
    final preview = buildMessage();

    return AppPageScaffold(
      title: 'إرسال إشعار للأهل',
      child: ListView(
        children: [
          Container(
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
            ),
            child: Text(
              'إشعار أو متابعة سريعة بخصوص ${widget.child.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: selectedTemplate,
                decoration: const InputDecoration(
                  labelText: 'نوع الإشعار',
                ),
                items: templates.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['value'],
                    child: Text(item['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTemplate = value ?? 'custom';
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل إضافية',
                  hintText: 'اختياري حسب نوع الإشعار',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                preview.isEmpty ? 'ستظهر معاينة الرسالة هنا' : preview,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: isSending ? null : sendNotification,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(isSending ? 'جاري الإرسال...' : 'إرسال الإشعار'),
          ),
        ],
      ),
    );
  }
}