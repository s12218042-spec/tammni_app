import 'package:flutter/material.dart';
import '../widgets/app_page_scaffold.dart';

class AdminComplaintsPage extends StatelessWidget {
  const AdminComplaintsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'شكاوي أولياء الأمور',
      child: Center(
        child: Text('هنا سيتم عرض الشكاوي', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
