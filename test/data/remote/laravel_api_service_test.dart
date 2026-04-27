import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kviz/data/remote/api_client.dart';
import 'package:kviz/data/remote/laravel_api_service.dart';

void main() {
  group('LaravelApiService solo queue', () {
    test(
      'joinSoloQueue posts with bearer and mobile session headers',
      () async {
        late http.Request capturedRequest;
        final service = LaravelApiService(
          apiClient: ApiClient(
            baseUrl: 'https://api.example.test/api/v1',
            httpClient: MockClient((request) async {
              capturedRequest = request;
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'ticket_id': 'ticket-1',
                  'status': 'waiting',
                }),
                200,
              );
            }),
          ),
        );

        final payload = await service.joinSoloQueue(
          accessToken: 'access-token',
          mobileSessionToken: 'mobile-token',
        );

        expect(payload['status'], 'waiting');
        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.path, '/api/v1/quiz/queue/solo/join');
        expect(capturedRequest.headers['Accept'], 'application/json');
        expect(capturedRequest.headers['Content-Type'], 'application/json');
        expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
        expect(
          capturedRequest.headers['X-Mobile-Session-Token'],
          'mobile-token',
        );
        expect(capturedRequest.body, '{}');
      },
    );

    test('getSoloQueueStatus reads ticket status endpoint', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'ticket_id': 'ticket-1',
                'status': 'matched',
                'session_id': 'session-1',
                'rounds': <Object>[],
              }),
              200,
            );
          }),
        ),
      );

      final payload = await service.getSoloQueueStatus(
        accessToken: 'access-token',
        mobileSessionToken: 'mobile-token',
        ticketId: 'ticket-1',
      );

      expect(payload['status'], 'matched');
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/v1/quiz/queue/ticket-1/status');
      expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
      expect(capturedRequest.headers['X-Mobile-Session-Token'], 'mobile-token');
    });

    test('cancelSoloQueue posts to ticket cancel endpoint', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'ticket_id': 'ticket-1',
                'status': 'cancelled',
              }),
              200,
            );
          }),
        ),
      );

      final payload = await service.cancelSoloQueue(
        accessToken: 'access-token',
        mobileSessionToken: 'mobile-token',
        ticketId: 'ticket-1',
      );

      expect(payload['status'], 'cancelled');
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/quiz/queue/ticket-1/cancel');
      expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
      expect(capturedRequest.headers['X-Mobile-Session-Token'], 'mobile-token');
      expect(capturedRequest.body, '{}');
    });
  });

  group('LaravelApiService progression endpoints', () {
    test('submitContentReport posts protected report payload', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{'report_id': 10, 'status': 'new'}),
              201,
            );
          }),
        ),
      );

      final payload = await service.submitContentReport(
        accessToken: 'access-token',
        mobileSessionToken: 'mobile-token',
        clientReportId: 'report-1',
        sessionId: 'session-1',
        roundKey: 'r1_question',
        mode: 'pitanja',
        contentType: 'question',
        questionSource: 'quiz_questions',
        questionId: 123,
        reason: 'wrong_answer',
        userComment: 'Komentar',
        suggestedFix: 'Predlog',
        contentSnapshot: const <String, dynamic>{'question_text': 'Pitanje?'},
      );

      expect(payload['report_id'], 10);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/quiz/content-reports');
      expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
      expect(capturedRequest.headers['X-Mobile-Session-Token'], 'mobile-token');
      expect(jsonDecode(capturedRequest.body), <String, dynamic>{
        'client_report_id': 'report-1',
        'session_id': 'session-1',
        'round_key': 'r1_question',
        'mode': 'pitanja',
        'content_type': 'question',
        'question_source': 'quiz_questions',
        'question_id': 123,
        'reason': 'wrong_answer',
        'user_comment': 'Komentar',
        'suggested_fix': 'Predlog',
        'content_snapshot': <String, dynamic>{'question_text': 'Pitanje?'},
      });
    });

    test('syncAchievements posts to backend achievement endpoint', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'achievements': <Object>[],
                'unlocked_now': <String>['first_game'],
              }),
              200,
            );
          }),
        ),
      );

      final payload = await service.syncAchievements(
        accessToken: 'access-token',
        achievementKeys: const <String>['first_game'],
      );

      expect(payload['unlocked_now'], ['first_game']);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/achievements/sync');
      expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
      expect(jsonDecode(capturedRequest.body), <String, dynamic>{
        'achievement_keys': <String>['first_game'],
      });
    });

    test('season leaderboard uses current season endpoint shape', () async {
      final requests = <http.Request>[];
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(<String, dynamic>{'entries': <Object>[]}),
              200,
            );
          }),
        ),
      );

      await service.getSeasonLeaderboard(
        seasonId: 12,
        mode: 'solo_duel',
        accessToken: 'access-token',
      );

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/seasons/12/leaderboard');
      expect(requests.single.url.queryParameters['mode'], 'solo_duel');
      expect(requests.single.headers['Authorization'], 'Bearer access-token');
    });

    test('season leaderboard can request premier exclusion', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{'entries': <Object>[]}),
              200,
            );
          }),
        ),
      );

      await service.getSeasonLeaderboard(
        seasonId: 12,
        mode: 'solo_duel',
        accessToken: 'access-token',
        excludePremier: true,
      );

      expect(capturedRequest.url.queryParameters['mode'], 'solo_duel');
      expect(capturedRequest.url.queryParameters['exclude_premier'], '1');
    });

    test('leaderboard can request premier exclusion', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{'entries': <Object>[]}),
              200,
            );
          }),
        ),
      );

      await service.getLeaderboard(
        mode: 'kviz',
        accessToken: 'access-token',
        excludePremier: true,
      );

      expect(capturedRequest.url.path, '/api/v1/leaderboard/kviz');
      expect(capturedRequest.url.queryParameters['exclude_premier'], '1');
    });

    test('registerPushToken posts FCM token metadata', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{'registered': true}),
              200,
            );
          }),
        ),
      );

      await service.registerPushToken(
        accessToken: 'access-token',
        token: 'fcm-token',
        platform: 'android',
        deviceId: 'device-1',
        appVersion: '1.0.0',
      );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/push/register');
      expect(jsonDecode(capturedRequest.body), <String, dynamic>{
        'token': 'fcm-token',
        'platform': 'android',
        'device_id': 'device-1',
        'app_version': '1.0.0',
      });
    });

    test('pingPresence posts device metadata without mobile session', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'online_count': 1,
                'online_window_seconds': 60,
                'waiting_total': 0,
                'waiting_by_mode': <String, int>{},
                'active_match_count': 0,
              }),
              200,
            );
          }),
        ),
      );

      final payload = await service.pingPresence(
        accessToken: 'access-token',
        deviceId: 'device-1',
        appVersion: '1.0.0',
      );

      expect(payload['online_count'], 1);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/quiz/presence');
      expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
      expect(capturedRequest.headers['X-Mobile-Session-Token'], isNull);
      expect(jsonDecode(capturedRequest.body), <String, dynamic>{
        'device_id': 'device-1',
        'platform': 'android',
        'app_version': '1.0.0',
      });
    });

    test(
      'subscription verification posts product and purchase token',
      () async {
        late http.Request capturedRequest;
        final service = LaravelApiService(
          apiClient: ApiClient(
            baseUrl: 'https://api.example.test/api/v1',
            httpClient: MockClient((request) async {
              capturedRequest = request;
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'ok': true,
                  'active': true,
                  'entitlements': <String, dynamic>{
                    'has_no_ads': true,
                    'has_premier': false,
                    'ads_removed': true,
                    'unlimited_games': false,
                    'subscriptions': <Object>[],
                  },
                }),
                200,
              );
            }),
          ),
        );

        final snapshot = await service.verifySubscriptionPurchase(
          accessToken: 'access-token',
          mobileSessionToken: 'mobile-token',
          productId: 'kviz_no_ads_monthly',
          purchaseToken: 'purchase-token',
        );

        expect(snapshot.hasNoAds, isTrue);
        expect(snapshot.hasPremier, isFalse);
        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.path, '/api/v1/quiz/subscriptions/verify');
        expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
        expect(
          capturedRequest.headers['X-Mobile-Session-Token'],
          'mobile-token',
        );
        expect(jsonDecode(capturedRequest.body), <String, dynamic>{
          'product_id': 'kviz_no_ads_monthly',
          'purchase_token': 'purchase-token',
        });
      },
    );

    test('subscription status reads server entitlements', () async {
      late http.Request capturedRequest;
      final service = LaravelApiService(
        apiClient: ApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'entitlements': <String, dynamic>{
                  'has_no_ads': true,
                  'has_premier': true,
                  'ads_removed': true,
                  'unlimited_games': false,
                  'subscriptions': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'product_id': 'kviz_premier_monthly',
                      'entitlement': 'premier',
                      'status': 'active',
                      'active': true,
                    },
                  ],
                },
              }),
              200,
            );
          }),
        ),
      );

      final snapshot = await service.getQuizSubscriptions(
        accessToken: 'access-token',
        mobileSessionToken: 'mobile-token',
      );

      expect(snapshot.hasPremier, isTrue);
      expect(snapshot.unlimitedGames, isFalse);
      expect(snapshot.subscriptions.single.productId, 'kviz_premier_monthly');
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/v1/quiz/subscriptions/me');
      expect(capturedRequest.headers['Authorization'], 'Bearer access-token');
      expect(capturedRequest.headers['X-Mobile-Session-Token'], 'mobile-token');
    });
  });
}
