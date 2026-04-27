import 'package:flutter/material.dart';

import '../../presentation/kviz_theme.dart';

class AppTitle extends StatelessWidget {
  const AppTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text != 'Kviz DBase') {
      return Text(
        text,
        style: TextStyle(
          color: context.strongText,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Text(
      'Kviz DBase',
      style: TextStyle(
        color: context.accentText,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
