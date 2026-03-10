import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../widgets/app_bar_widget.dart';

class WeeklyReportPage extends StatelessWidget {
  final ChildModel child;
  const WeeklyReportPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final updates = DummyData.updatesForChild(child.id);
    final top3 = updates.take(3).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _card('القسم', '${child.section}'),
              _card('الصف/المجموعة', '${child.group}'),
              _card('عدد التحديثات المسجلة', '${updates.length}'),

              const SizedBox(height: 16),
              const Text('أهم التحديثات', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (top3.isEmpty)
                const Text('لا يوجد تحديثات بعد.')
              else
                ...top3.map((u) => _simpleLine('• ${u.type}: ${u.note}')),

              const SizedBox(height: 16),
              _simpleLine('ملاحظة عامة: هذا تقرير تجريبي (Demo) ويمكن ربطه لاحقًا بقاعدة بيانات.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        color: const Color(0xFFF6F6FF),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(value),
        ],
      ),
    );
  }

  Widget _simpleLine(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text),
      );
}