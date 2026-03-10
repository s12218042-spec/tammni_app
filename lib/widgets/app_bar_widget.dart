import 'package:flutter/material.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {

  final String title;

  const AppBarWidget({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {

    final canGoBack = Navigator.of(context).canPop();

    return AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: const Color(0xFF8E97FD),
      foregroundColor: Colors.white,

      leading: canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}