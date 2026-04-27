import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/data/remote/play_games_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('rs.in.dbase.kviz/play_games');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('normalizes Google leaderboard aliases', () {
    expect(
      PlayGamesService.normalizeGoogleLeaderboardMode('ko_zna_zna'),
      'pitanja',
    );
    expect(
      PlayGamesService.normalizeGoogleLeaderboardMode('my_number'),
      'moj_broj',
    );
    expect(
      PlayGamesService.normalizeGoogleLeaderboardMode('daily'),
      'kviz_plus',
    );
    expect(PlayGamesService.hasGoogleLeaderboardForMode('solo'), isFalse);
    expect(PlayGamesService.hasGoogleLeaderboardForMode('pitanja'), isTrue);
  });

  test(
    'syncSessionResult submits score and unlocks achievements once',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });

      await const PlayGamesService().syncSessionResult(
        mode: 'pitanja',
        finalScore: 120,
        bestStreak: 7,
        perfectKviz: false,
        associationsMaster: false,
        speedDemonCount: 0,
        serverConfirmedAchievements: const [
          PlayGamesService.sevenCorrectStreakAchievement,
        ],
        myNumberPerfect: false,
        userKey: 'google:123',
      );

      expect(calls.map((call) => call.method), <String>[
        'submitLeaderboardScore',
        'unlockAchievement',
        'unlockAchievement',
      ]);
      expect(calls[0].arguments, <String, Object?>{
        'leaderboardMode': 'pitanja',
        'score': 120,
      });
      expect(calls[1].arguments, <String, Object?>{
        'achievementKey': 'first_game',
      });
      expect(calls[2].arguments, <String, Object?>{
        'achievementKey': 'seven_correct_streak',
      });

      calls.clear();

      await const PlayGamesService().syncSessionResult(
        mode: 'pitanja',
        finalScore: 140,
        bestStreak: 7,
        perfectKviz: false,
        associationsMaster: false,
        speedDemonCount: 0,
        serverConfirmedAchievements: const [],
        myNumberPerfect: false,
        userKey: 'google:123',
      );

      expect(calls.map((call) => call.method), <String>[
        'submitLeaderboardScore',
      ]);
      expect(calls.single.arguments, <String, Object?>{
        'leaderboardMode': 'pitanja',
        'score': 140,
      });
    },
  );
}
