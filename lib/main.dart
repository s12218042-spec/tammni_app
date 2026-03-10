import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/welcome_page.dart';

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
      theme: ThemeData(
        textTheme: GoogleFonts.cairoTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8E97FD)),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}