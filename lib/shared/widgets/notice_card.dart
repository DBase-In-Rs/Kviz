import 'package:flutter/material.dart';
import '../../presentation/kviz_theme.dart';

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.warningBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.warningText,
        ),
      ),
    );
  }
}
