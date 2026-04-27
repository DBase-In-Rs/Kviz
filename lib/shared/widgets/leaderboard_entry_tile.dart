import 'package:flutter/material.dart';

import '../../presentation/kviz_theme.dart';

import 'player_avatar.dart';

class LeaderboardEntryTile extends StatelessWidget {
  const LeaderboardEntryTile({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank']?.toString() ?? '-';
    final name = entry['name']?.toString().trim();
    final avatarUrl =
        entry['avatar_url']?.toString().trim() ??
        entry['profile_photo_url']?.toString().trim();
    final score = (entry['rating'] ?? entry['score'])?.toString() ?? '0';
    final gamesPlayed = entry['games_played']?.toString() ?? '0';
    final hasPremier =
        _asBool(entry['has_premier']) || _asBool(entry['is_premium']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              rank,
              style: TextStyle(
                color: context.accentText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          PlayerAvatar(
            label: (name == null || name.isEmpty) ? 'Igrac' : name,
            avatarUrl: avatarUrl == null || avatarUrl.isEmpty
                ? null
                : avatarUrl,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (name == null || name.isEmpty) ? 'Igrac' : name,
                        style: TextStyle(
                          color: context.strongText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasPremier) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Premier korisnik',
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: const Color(0xFFFFD54F),
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$gamesPlayed partija',
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD54F),
            size: 22,
          ),
          const SizedBox(width: 6),
          Text(
            score,
            style: TextStyle(
              color: context.strongText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }
}
