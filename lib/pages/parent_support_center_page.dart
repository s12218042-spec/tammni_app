import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentSupportCenterPage extends StatelessWidget {
  const ParentSupportCenterPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'مركز الدعم',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
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
                  'مركز الدعم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'إجابات مختصرة على أكثر الأسئلة شيوعًا داخل التطبيق.',
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
            title: 'الأسئلة الشائعة',
            icon: Icons.quiz_outlined,
          ),
          const SizedBox(height: 10),

          const _FaqTile(
            question: 'كيف أضيف طفل جديد؟',
            answer:
                'يمكنك إرسال طلب إضافة طفل من الصفحة المخصصة لطلبات إضافة الأطفال داخل حساب ولي الأمر، وبعدها تنتظر مراجعة الإدارة للطلب.',
          ),
          const _FaqTile(
            question: 'كيف أتابع تحديثات طفلي؟',
            answer:
                'من تبويب المتابعة، اختر الطفل المطلوب ثم تابع التحديثات اليومية، الصور، الفيديوهات، والسجلات المرتبطة به.',
          ),
          const _FaqTile(
            question: 'كيف أرسل شكوى أو ملاحظة؟',
            answer:
                'الشكاوى والملاحظات لها صفحة مستقلة داخل حساب ولي الأمر، ومن خلالها يمكنك إرسال الشكوى ومتابعة رد الإدارة.',
          ),
          const _FaqTile(
            question: 'كيف أتابع الفواتير؟',
            answer:
                'الفواتير تظهر في صفحة الفواتير الخاصة بولي الأمر، ويمكنك متابعة المبلغ الكلي، المدفوع، المتبقي، وحالة الدفع.',
          ),
          const _FaqTile(
            question: 'كيف أراسل الإدارة أو الحضانة؟',
            answer:
                'يمكنك استخدام قسم الرسائل في التطبيق للتواصل مع الإدارة أو موظف الحضانة حسب المحادثات المتاحة لك.',
          ),
          const _FaqTile(
            question: 'كيف أطلب بث مباشر؟',
            answer:
                'من صفحة الطفل أو مكان البث المباشر داخل التطبيق. إذا كان هناك بث قائم حاليًا، قد يتم وضعك في قائمة انتظار حتى ينتهي البث الحالي.',
          ),
          const _FaqTile(
            question: 'كيف أعدل بيانات الحساب؟',
            answer:
                'تعديل بيانات الحساب مثل الاسم أو البريد أو كلمة المرور يتم من صفحة إعدادات الحساب أو الملف الشخصي.',
          ),
          const _FaqTile(
            question: 'ماذا أفعل إذا لم تظهر بيانات طفلي؟',
            answer:
                'تأكد من أن طلب الطفل تمت الموافقة عليه من الإدارة، وأنك تستخدم نفس الحساب المرتبط بالطفل.',
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