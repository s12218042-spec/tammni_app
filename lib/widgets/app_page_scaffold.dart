import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_bar_widget.dart';

class AppPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 16),
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: AppBarWidget(
          title: title,
          actions: actions,
        ),
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}