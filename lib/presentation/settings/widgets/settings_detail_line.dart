import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class SettingsDetailLine extends StatelessWidget {
  const SettingsDetailLine({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.strongText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
