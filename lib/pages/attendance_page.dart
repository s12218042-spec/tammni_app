import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../widgets/app_bar_widget.dart';

class AttendancePage extends StatefulWidget {
  final String sectionFilter; // Nursery / Kindergarten / All

  const AttendancePage({super.key, this.sectionFilter = 'All'});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<ChildModel> get list {
    if (widget.sectionFilter == 'All') return DummyData.children;
    return DummyData.children.where((c) => c.section == widget.sectionFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateText = '${today.year}/${today.month}/${today.day}';

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF6F6FF),
                ),
                child: Text(
                  widget.sectionFilter == 'All'
                      ? 'عرض كل الأطفال'
                      : 'عرض أطفال قسم: ${widget.sectionFilter}',
                ),
              ),
              const SizedBox(height: 12),

              ...list.map((child) {
                final present = DummyData.isPresentToday(child.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF8E97FD),
                        child: Icon(Icons.child_care, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${child.section} - ${child.group}',
                                style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: present,
                        onChanged: (v) {
                          setState(() {
                            DummyData.setPresentToday(child.id, v);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 12),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ الحضور ✅')),
                    );
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('حفظ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E97FD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}