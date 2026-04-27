import 'package:flutter/material.dart';

import '../../presentation/kviz_theme.dart';

import '../../shared/utils.dart';
import 'nav_item.dart';

class KvizBottomNav extends StatelessWidget {
  const KvizBottomNav({
    super.key,
    required this.useCyrillic,
    required this.selectedIndex,
    required this.onTap,
  });

  final bool useCyrillic;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavItem(
                icon: Icons.home_rounded,
                label: t('Početna', 'Почетна'),
                active: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              NavItem(
                icon: Icons.leaderboard_rounded,
                label: t('Rang lista', 'Ранг листа'),
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              NavItem(
                icon: Icons.person_rounded,
                label: t('Profil', 'Профил'),
                active: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              NavItem(
                icon: Icons.settings_rounded,
                label: t('Podešavanja', 'Подешавања'),
                active: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
