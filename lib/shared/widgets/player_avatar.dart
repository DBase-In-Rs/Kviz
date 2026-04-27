import 'package:flutter/material.dart';

import '../../presentation/kviz_theme.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.label,
    required this.avatarUrl,
    required this.size,
  });

  final String label;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final initial = label.trim().isNotEmpty
        ? label.trim()[0].toUpperCase()
        : 'I';

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E4C86), Color(0xFF1565C0)],
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final imageUrl = url;
    if (imageUrl == null) {
      return fallback();
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) {
      return fallback();
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.innerBg,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: size * 0.38,
              height: size * 0.38,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.accentText,
              ),
            ),
          );
        },
      ),
    );
  }
}
