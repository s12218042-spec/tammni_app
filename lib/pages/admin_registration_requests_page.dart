import 'package:flutter/material.dart';
import '../widgets/app_page_scaffold.dart';

class AdminRegistrationRequestsPage extends StatelessWidget {
  const AdminRegistrationRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'طلبات التسجيل',
      child: Center(
        child: Text('صفحة طلبات التسجيل - قيد التطوير'),
      ),
    );
  }
}