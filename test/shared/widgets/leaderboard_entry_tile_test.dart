import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/shared/widgets/leaderboard_entry_tile.dart';

void main() {
  testWidgets('shows premier badge for premium leaderboard entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LeaderboardEntryTile(
            entry: <String, dynamic>{
              'rank': 1,
              'name': 'Premier Igrac',
              'score': 120,
              'games_played': 7,
              'has_premier': true,
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.byTooltip('Premier korisnik'), findsOneWidget);
  });

  testWidgets('does not show premier badge for regular leaderboard entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LeaderboardEntryTile(
            entry: <String, dynamic>{
              'rank': 2,
              'name': 'Regularan Igrac',
              'score': 80,
              'games_played': 4,
              'has_premier': false,
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(find.byTooltip('Premier korisnik'), findsNothing);
  });
}
