import 'package:flutter/material.dart';
import 'package:tammni_app/pages/welcome_page.dart';
import 'package:tammni_app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: AppTheme.lightTheme,
      home: const WelcomePage(),
    );
  }
}