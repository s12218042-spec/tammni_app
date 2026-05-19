import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_child_request_page.dart';
import 'parent_chats_page.dart';
import 'parent_complaints_page.dart';
import 'parent_invoice_page.dart';
import 'profile_details_page.dart';

class ParentSupportCenterPage extends StatelessWidget {
  final String parentUsername;
  final List<ChildModel> children;

  const ParentSupportCenterPage({
    super.key,
    required this.parentUsername,
    required this.children,
  });

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'مركز الدعم',
      child: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                SizedBox(height: 12),
                Text(
                  'كيف يمكننا مساعدتك؟',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'اختاري نوع المشكلة أو تواصلي مع الإدارة مباشرة من داخل التطبيق.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const _SectionTitle(
            title: 'خدمات الدعم',
            icon: Icons.help_outline_rounded,
          ),
          const SizedBox(height: 10),

          _SupportActionCard(
            icon: Icons.report_problem_outlined,
            color: Colors.red,
            title: 'إرسال شكوى أو ملاحظة',
            subtitle: 'أرسلي مشكلة أو اقتراح للإدارة وتابعي الردود.',
            onTap: () {
              _openPage(
                context,
                ParentComplaintsPage(parentUsername: parentUsername),
              );
            },
          ),

          _SupportActionCard(
            icon: Icons.chat_bubble_outline_rounded,
            color: Colors.blueGrey,
            title: 'مراسلة الإدارة أو الحضانة',
            subtitle: 'افتحي المحادثات للتواصل المباشر.',
            onTap: () {
              if (children.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لا توجد محادثات متاحة بدون أطفال مرتبطين'),
                  ),
                );
                return;
              }

              _openPage(
                context,
                ParentChatsPage(children: children),
              );
            },
          ),

          _SupportActionCard(
            icon: Icons.receipt_long_rounded,
            color: Colors.indigo,
            title: 'مشكلة في الفواتير',
            subtitle: 'راجعي الفواتير أو تواصلي مع الإدارة بخصوص المبلغ.',
            onTap: () {
              _openPage(
                context,
                ParentInvoicesPage(parentUsername: parentUsername),
              );
            },
          ),

          _SupportActionCard(
            icon: Icons.manage_accounts_outlined,
            color: Colors.orange,
            title: 'مشكلة في الحساب',
            subtitle: 'تعديل الاسم أو البريد أو كلمة المرور.',
            onTap: () {
              _openPage(
                context,
                const ProfileDetailsPage(),
              );
            },
          ),

          _SupportActionCard(
            icon: Icons.person_add_alt_1_rounded,
            color: AppColors.primary,
            title: 'طلب إضافة طفل',
            subtitle: 'إرسال طلب جديد للإدارة لربط طفل بالحساب.',
            onTap: () {
              _openPage(
                context,
                const AddChildRequestPage(),
              );
            },
          ),

          const SizedBox(height: 18),

          const _SectionTitle(
            title: 'الأسئلة الشائعة',
            icon: Icons.quiz_outlined,
          ),
          const SizedBox(height: 10),

          const _FaqTile(
            question: 'كيف أضيف طفل جديد؟',
            answer:
                'من مركز الدعم أو الإعدادات اضغطي على طلب إضافة طفل، ثم املئي البيانات وانتظري موافقة الإدارة.',
          ),
          const _FaqTile(
            question: 'كيف أتابع تحديثات طفلي؟',
            answer:
                'من تبويب المتابعة، اختاري الطفل ثم اضغطي على التحديثات أو ملف الطفل.',
          ),
          const _FaqTile(
            question: 'كيف أرسل شكوى أو ملاحظة؟',
            answer:
                'من مركز الدعم اضغطي على إرسال شكوى أو ملاحظة، وسيصل الطلب للإدارة.',
          ),
          const _FaqTile(
            question: 'كيف أتابع الفواتير؟',
            answer:
                'من الرئيسية أو الإعدادات أو مركز الدعم اضغطي على الفواتير لمراجعة الفواتير المرتبطة بحسابك.',
          ),
          const _FaqTile(
            question: 'كيف أطلب بث مباشر؟',
            answer:
                'من بطاقة الطفل في المتابعة اضغطي على طلب بث مباشر للطفل، وسيصل الطلب للإدارة للموافقة.',
          ),

          const SizedBox(height: 18),

          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.12),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFEDEBFF),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'سيتم الرد على الشكاوى والملاحظات من خلال الإدارة داخل التطبيق. تابعي الإشعارات والرسائل لمعرفة الرد.',
                      style: TextStyle(
                        color: AppColors.textDark,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
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

class _SupportActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textLight,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
        onTap: onTap,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.10),
          child: const Icon(
            Icons.question_answer_outlined,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              answer,
              style: const TextStyle(
                color: AppColors.textLight,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}