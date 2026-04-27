import 'package:flutter/material.dart';

import '../../presentation/kviz_theme.dart';

class DarkProgressCard extends StatelessWidget {
  const DarkProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: LinearProgressIndicator(
        minHeight: 6,
        color: context.accentText,
        backgroundColor: context.innerBg,
      ),
    );
  }
}
