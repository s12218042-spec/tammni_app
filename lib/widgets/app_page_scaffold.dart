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
  final bool showBackButton;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 16),
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.showBackButton = true,
  });

  EdgeInsets _resolvePadding(BuildContext context) {
    final basePadding = padding.resolve(Directionality.of(context));
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;

    return basePadding.copyWith(
      bottom: basePadding.bottom + bottomSafePadding + 20,
    );
  }

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
          showBackButton: showBackButton,
        ),
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: _resolvePadding(context),
            child: child,
          ),
        ),
      ),
    );
  }
}