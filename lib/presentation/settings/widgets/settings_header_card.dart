import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class SettingsHeaderCard extends StatelessWidget {
  const SettingsHeaderCard({super.key, required this.useCyrillic});

  final bool useCyrillic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.settings_rounded,
              color: context.accentText,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  useCyrillic ? 'Подешавања' : 'Podešavanja',
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  useCyrillic
                      ? 'Приказ, писмо и налог'
                      : 'Prikaz, pismo i nalog',
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
