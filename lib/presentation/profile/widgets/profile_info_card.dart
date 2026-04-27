import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../kviz_theme.dart';
import '../../../data/remote/auth_models.dart'; // AuthSession
import '../../../shared/widgets/player_avatar.dart';

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.useCyrillic,
    required this.authSession,
    required this.onAchievementsTap,
  });

  final bool useCyrillic;
  final AuthSession authSession;
  final VoidCallback onAchievementsTap;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final user = authSession.user;
    final email = user.email?.trim();
    final displayName = user.displayName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Google nalog', 'Google налог'),
            style: TextStyle(
              color: context.accentText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              PlayerAvatar(
                label: displayName,
                avatarUrl: user.avatarUrl,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAchievementsTap,
              icon: const Icon(Icons.emoji_events_rounded),
              label: Text(t('Dostignuća', 'Достигнућа')),
            ),
          ),
        ],
      ),
    );
  }
}
