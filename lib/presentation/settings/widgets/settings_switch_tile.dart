import 'package:flutter/material.dart';
import '../../kviz_theme.dart';

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.innerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.accentText, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.strongText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
