import 'package:flutter/material.dart';
import '../../../domain/entities.dart';

class ModeBadgeIcon extends StatelessWidget {
  const ModeBadgeIcon({super.key, required this.kind});

  final ModeKind kind;

  @override
  Widget build(BuildContext context) {
    late final List<Color> colors;
    late final IconData icon;

    switch (kind) {
      case ModeKind.quiz:
        colors = const [Color(0xFF1B5E20), Color(0xFF2E7D32)];
        icon = Icons.emoji_events_rounded;
        break;
      case ModeKind.questions:
        colors = const [Color(0xFF0E4C86), Color(0xFF1565C0)];
        icon = Icons.menu_book_rounded;
        break;
      case ModeKind.associations:
        colors = const [Color(0xFFB71C1C), Color(0xFFE53935)];
        icon = Icons.link_rounded;
        break;
      case ModeKind.myNumber:
        colors = const [Color(0xFF0D3B66), Color(0xFF1565C0)];
        icon = Icons.pin_rounded;
        break;
      case ModeKind.tangram:
        colors = const [Color(0xFFB71C1C), Color(0xFFE53935)];
        icon = Icons.extension_rounded;
        break;
      case ModeKind.premier:
        colors = const [Color(0xFF7A5700), Color(0xFFE0A800)];
        icon = Icons.workspace_premium_rounded;
        break;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 26)),
    );
  }
}
