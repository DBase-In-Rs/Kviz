import 'package:flutter/material.dart';
import 'settings_panel.dart';

class SettingsAccountPanel extends StatelessWidget {
  const SettingsAccountPanel({
    super.key,
    required this.useCyrillic,
    required this.onLogoutTap,
  });

  final bool useCyrillic;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPanel(
      icon: Icons.account_circle_rounded,
      title: useCyrillic ? 'Налог' : 'Nalog',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onLogoutTap,
          icon: const Icon(Icons.logout_rounded),
          label: Text(useCyrillic ? 'Одјава' : 'Odjava'),
        ),
      ),
    );
  }
}
