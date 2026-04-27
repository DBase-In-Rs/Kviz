import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kviz/data/remote/api_client.dart';
import 'package:kviz/data/remote/api_config.dart';
import 'package:kviz/data/remote/auth_models.dart';
import 'package:kviz/data/remote/laravel_api_service.dart';
import 'package:kviz/features/queue/solo_queue_page.dart';
import 'package:kviz/presentation/online_session_page.dart';

void main() {
  group('SoloQueuePage', () {
    testWidgets('queue join prikazuje waiting state', (tester) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/quota')) {
          return _json(_quota(canStart: true));
        }
        if (request.url.path.endsWith('/quiz/queue/solo/join')) {
          return _json(_waitingPayload());
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(_app(_queuePage(api)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Tražimo protivnika...'), findsOneWidget);
      expect(find.text('Spajamo te sa igračem sličnog nivoa.'), findsOneWidget);
      expect(find.text('Odustani'), findsOneWidget);
    });

    testWidgets('matched response otvara online session', (tester) async {
      var quotaRefreshed = false;
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/quota')) {
          return _json(_quota(canStart: true));
        }
        if (request.url.path.endsWith('/quiz/queue/solo/join')) {
          return _json(_matchedPayload());
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        _app(_queuePage(api, onAdQuotaChanged: () => quotaRefreshed = true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final sessionPage = tester.widget<OnlineSessionPage>(
        find.byType(OnlineSessionPage),
      );
      expect(sessionPage.modeKey, 'solo_duel');
      expect(quotaRefreshed, isTrue);
    });

    testWidgets('poll obnavlja istekao mobile session token', (tester) async {
      var providerCalls = 0;
      final mobileHeaders = <String?>[];
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/quota')) {
          return _json(_quota(canStart: true));
        }
        if (request.url.path.endsWith('/quiz/queue/solo/join')) {
          return _json(_waitingPayload());
        }
        if (request.url.path.endsWith('/quiz/queue/ticket-1/status')) {
          mobileHeaders.add(_mobileHeader(request));
          if (mobileHeaders.length == 1) {
            return _json(<String, dynamic>{
              'message': 'mobile_session_token is required.',
            }, 401);
          }

          return _json(_matchedPayload());
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        _app(
          _queuePage(
            api,
            mobileSessionTokenProvider: (_) async {
              providerCalls += 1;
              return providerCalls == 1 ? 'mobile-token' : 'mobile-token-2';
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 200));

      final sessionPage = tester.widget<OnlineSessionPage>(
        find.byType(OnlineSessionPage),
      );
      expect(sessionPage.modeKey, 'solo_duel');
      expect(providerCalls, 2);
      expect(mobileHeaders, <String?>['mobile-token', 'mobile-token-2']);
    });

    testWidgets(
      'inactive lifecycle ne otkazuje queue dok Google UI prelazi fokus',
      (tester) async {
        var cancelCalled = false;
        final api = _apiFor((request) async {
          if (request.url.path.endsWith('/quiz/quota')) {
            return _json(_quota(canStart: true));
          }
          if (request.url.path.endsWith('/quiz/queue/solo/join')) {
            return _json(_waitingPayload());
          }
          if (request.url.path.endsWith('/quiz/queue/ticket-1/cancel')) {
            cancelCalled = true;
            return _json(<String, dynamic>{
              'ticket_id': 'ticket-1',
              'status': 'cancelled',
            });
          }
          return _json(<String, dynamic>{'message': 'unexpected'}, 404);
        });

        await tester.pumpWidget(_app(_queuePage(api)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(cancelCalled, isFalse);
        expect(find.text('Tražimo protivnika...'), findsOneWidget);
      },
    );

    testWidgets('cancel vraca korisnika na solo ekran', (tester) async {
      var cancelCalled = false;
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/quota')) {
          return _json(_quota(canStart: true));
        }
        if (request.url.path.endsWith('/quiz/queue/solo/join')) {
          return _json(_waitingPayload());
        }
        if (request.url.path.endsWith('/quiz/queue/ticket-1/cancel')) {
          cancelCalled = true;
          return _json(<String, dynamic>{
            'ticket_id': 'ticket-1',
            'status': 'cancelled',
          });
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _queuePage(api)),
                  );
                },
                child: const Text('Solo ekran'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Solo ekran'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Odustani'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(cancelCalled, isTrue);
      expect(find.text('Solo ekran'), findsOneWidget);
      expect(find.byType(SoloQueuePage), findsNothing);
    });

    testWidgets('API error prikazuje kratku korisnicku poruku', (tester) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/quota')) {
          return _json(<String, dynamic>{'message': 'server_down'}, 500);
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(_app(_queuePage(api)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Pretraga je zastala'), findsOneWidget);
      expect(find.textContaining('Greška na serveru'), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
    });
  });
}

Widget _app(Widget child) {
  return MaterialApp(home: child);
}

SoloQueuePage _queuePage(
  LaravelApiService api, {
  VoidCallback? onAdQuotaChanged,
  Future<String> Function(LaravelApiService api)? mobileSessionTokenProvider,
}) {
  return SoloQueuePage(
    modeKey: 'solo',
    modeTitle: 'Solo',
    useCyrillic: false,
    authSession: _authSession,
    deviceId: 'device-1',
    apiConfig: const ApiConfig(
      baseUrl: 'https://api.example.test/api/v1',
      appVersion: '1.0.0',
      googleServerClientId: 'client-id',
    ),
    accessTokenRefresher: (_) async => null,
    onAdQuotaChanged: onAdQuotaChanged ?? () {},
    api: api,
    mobileSessionTokenProvider:
        mobileSessionTokenProvider ?? (_) async => 'mobile-token',
  );
}

LaravelApiService _apiFor(
  Future<http.Response> Function(http.Request request) handler,
) {
  return LaravelApiService(
    apiClient: ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient(handler),
    ),
  );
}

http.Response _json(Map<String, dynamic> payload, [int statusCode = 200]) {
  return http.Response(jsonEncode(payload), statusCode);
}

String? _mobileHeader(http.Request request) {
  return request.headers['X-Mobile-Session-Token'] ??
      request.headers['x-mobile-session-token'];
}

Map<String, dynamic> _quota({required bool canStart}) {
  return <String, dynamic>{
    'free_games_per_day': 5,
    'rewarded_grants_per_day': 5,
    'max_games_per_day': 10,
    'games_started_today': canStart ? 0 : 10,
    'reward_grants_today': 0,
    'daily_game_capacity': canStart ? 5 : 10,
    'remaining_games_today': canStart ? 5 : 0,
    'remaining_reward_grants_today': 5,
    'can_start_game': canStart,
    'can_grant_reward': true,
  };
}

Map<String, dynamic> _waitingPayload() {
  return <String, dynamic>{
    'ticket_id': 'ticket-1',
    'status': 'waiting',
    'server_time': DateTime.now().toIso8601String(),
    'search_deadline_at': DateTime.now()
        .add(const Duration(seconds: 45))
        .toIso8601String(),
    'poll_after_seconds': 5,
  };
}

Map<String, dynamic> _matchedPayload() {
  return <String, dynamic>{
    'ticket_id': 'ticket-1',
    'status': 'matched',
    'match_id': 'match-1',
    'session_id': 'session-1',
    'mode': 'solo_duel',
    'server_time': DateTime.now().toIso8601String(),
    'opponent': <String, dynamic>{'name': 'Igrac Dva', 'avatar_url': null},
    'rounds': <Map<String, dynamic>>[
      <String, dynamic>{
        'round_key': 'round-1',
        'round_order': 1,
        'duration_seconds': 99,
        'status': 'active',
        'payload_public': <String, dynamic>{
          'type': 'question',
          'question_source': 'quiz_questions',
          'question_id': 1,
          'question_text': 'Test pitanje?',
          'choices': <Map<String, String>>[
            <String, String>{'label': 'A', 'text': 'Tacno'},
            <String, String>{'label': 'B', 'text': 'Netacno'},
          ],
        },
      },
    ],
  };
}

const _authSession = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'Bearer',
  user: AuthUser(
    id: 1,
    email: 'igrac@example.test',
    firstName: 'Igrac',
    lastName: 'Jedan',
    avatarUrl: null,
    googleSub: 'google-sub-1',
  ),
);
