import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kviz/data/remote/api_client.dart';
import 'package:kviz/data/remote/laravel_api_service.dart';
import 'package:kviz/domain/online_round_models.dart';
import 'package:kviz/presentation/online_session_page.dart';

void main() {
  group('OnlineRound', () {
    test('parses API choices with labels and text', () {
      final round = OnlineRound.fromJson({
        'round_key': 'round_1',
        'round_order': 1,
        'duration_seconds': 99,
        'payload_public': {
          'type': 'question',
          'question_source': 'quiz_questions',
          'question_id': 5001,
          'question_text': 'Koji je glavni grad Srbije?',
          'choices': [
            {'label': 'A', 'text': 'Beograd'},
            {'label': 'B', 'text': 'Novi Sad'},
            {'label': 'C', 'text': 'Kragujevac'},
            {'label': 'D', 'text': 'Nis'},
          ],
        },
      });

      expect(round.roundKey, 'round_1');
      expect(round.durationSeconds, 99);
      expect(round.questionSource, 'quiz_questions');
      expect(round.questionId, 5001);
      expect(round.choices, hasLength(4));
      expect(round.choices.first.label, 'A');
      expect(round.choices.first.text, 'Beograd');
    });

    test('parses moj broj payload for numeric answer rounds', () {
      final round = OnlineRound.fromJson({
        'round_key': 'round_2',
        'round_order': 2,
        'duration_seconds': 100,
        'payload_public': {
          'type': 'moj_broj',
          'question_source': 'quiz_my_number',
          'question_id': 1001,
          'target': 742,
          'numbers': [2, 4, 6, 8, 25, 50],
          'prompt': 'Upotrebi ponudjene brojeve.',
        },
      });

      expect(round.isMyNumber, isTrue);
      expect(round.questionSource, 'quiz_my_number');
      expect(round.target, 742);
      expect(round.numbers, [2, 4, 6, 8, 25, 50]);
      expect(round.prompt, 'Upotrebi ponudjene brojeve.');
    });

    test('parses tangram payload for completed answer rounds', () {
      final round = OnlineRound.fromJson({
        'round_key': 'round_3',
        'round_order': 3,
        'duration_seconds': 120,
        'payload_public': {
          'type': 'tangram',
          'question_source': 'quiz_tangram',
          'question_id': 2001,
          'title': 'Kuca',
          'difficulty': 'easy',
          'hint': 'Pocni od najveceg trougla.',
          'shape': {
            'canvas': {'width': 420, 'height': 420},
            'polygons': [
              [
                {'x': 10, 'y': 20},
                {'x': 110, 'y': 20},
                {'x': 10, 'y': 120},
              ],
            ],
          },
        },
      });

      expect(round.isTangram, isTrue);
      expect(round.questionSource, 'quiz_tangram');
      expect(round.title, 'Kuca');
      expect(round.difficulty, 'easy');
      expect(round.hint, 'Pocni od najveceg trougla.');
      expect(round.tangramShape?['polygons'], isA<List>());
    });

    test('parses association answer targets for column and final guesses', () {
      final round = OnlineRound.fromJson({
        'round_key': 'round_4',
        'round_order': 4,
        'duration_seconds': 90,
        'payload_public': {
          'type': 'asocijacije',
          'question_source': 'quiz_associations',
          'question_id': 6101,
          'max_answers': 999,
          'grid': {
            'a': ['Beograd', 'Nis', 'Kragujevac', 'Subotica'],
            'b': ['Sava', 'Dunav', 'Tisa', 'Morava'],
            'v': ['Tara', 'Zlatibor', 'Kopaonik', 'Rtanj'],
            'g': ['Sljiva', 'Malina', 'Kupina', 'Jabuka'],
          },
          'answer_targets': [
            {'key': 'a', 'label': 'A'},
            {'key': 'b', 'label': 'B'},
            {'key': 'v', 'label': 'V'},
            {'key': 'g', 'label': 'G'},
            {'key': 'final', 'label': 'Konačno'},
          ],
        },
      });

      expect(round.isAssociation, isTrue);
      expect(round.maxAnswers, 999);
      expect(round.associationTargets.map((target) => target.key), [
        'a',
        'b',
        'v',
        'g',
        'final',
      ]);
      expect(round.associationGrid?['a']?.first, 'Beograd');
    });

    test('parses question hint metadata including answer text', () {
      final round = OnlineRound.fromJson({
        'round_key': 'round_5',
        'round_order': 5,
        'duration_seconds': 60,
        'payload_public': {
          'type': 'question',
          'question_source': 'quiz_questions',
          'question_id': 5002,
          'question_text': 'Koji je glavni grad Srbije?',
          'answer_hint': {
            'answer': 'Beograd',
            'max_reveal_percent': 69,
            'char_count': 7,
          },
        },
      });

      expect(round.questionHintAnswer, 'Beograd');
      expect(round.questionAnswerCharCount, 7);
    });
  });

  group('OnlineSessionPage lifecycle anti-cheat', () {
    for (final state in <AppLifecycleState>[
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      testWidgets('$state blocks active online session and posts lifecycle', (
        tester,
      ) async {
        Map<String, dynamic>? capturedLifecycle;
        final api = _apiFor((request) async {
          if (request.url.path.endsWith('/quiz/sessions/session-1/lifecycle')) {
            capturedLifecycle =
                jsonDecode(request.body) as Map<String, dynamic>;
            return _json(<String, dynamic>{'ok': true});
          }
          return _json(<String, dynamic>{'message': 'unexpected'}, 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: OnlineSessionPage(
              modeKey: 'kviz',
              sessionId: 'session-1',
              mobileSessionToken: 'mobile-token',
              accessToken: 'access-token',
              deviceId: 'device-1',
              appVersion: '1.0.0',
              rounds: <OnlineRound>[_questionRound()],
              modeTitle: 'Kviz Duel',
              useCyrillic: false,
              api: api,
            ),
          ),
        );

        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();

        expect(
          find.text('Partija je završena zbog napuštanja aplikacije.'),
          findsOneWidget,
        );
        expect(capturedLifecycle?['event'], 'background');
        expect(capturedLifecycle?['event_time_client'], isA<String>());

        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('inactive state does not block active online session', (
      tester,
    ) async {
      var lifecycleRequests = 0;
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/lifecycle')) {
          lifecycleRequests += 1;
          return _json(<String, dynamic>{'ok': true});
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'kviz',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_questionRound()],
            modeTitle: 'Kviz Duel',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(
        find.text('Partija je završena zbog napuštanja aplikacije.'),
        findsNothing,
      );
      expect(lifecycleRequests, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('OnlineSessionPage associations', () {
    testWidgets('question report button saves editable draft', (tester) async {
      final api = _apiFor((request) async {
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'pitanja',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_questionRound()],
            modeTitle: 'Pitanja',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      expect(find.text('Prijavi'), findsOneWidget);
      expect(find.text('Beograd'), findsNothing);
      expect(find.textContaining('Pomoć se otkriva'), findsOneWidget);
      expect(find.textContaining('Tajni odgovor'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Upiši odgovor...',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Prijavi'));
      await tester.pumpAndSettle();
      final commentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'Zašto mislite da je loše ili pogrešno?',
      );
      await tester.enterText(commentField, 'Tacan odgovor nije dobar');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sačuvaj'));
      await tester.pumpAndSettle();

      expect(find.text('Prijavljeno'), findsOneWidget);
      expect(find.text('Sačuvano za kraj partije.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('selected association target is submitted to backend', (
      tester,
    ) async {
      Map<String, dynamic>? capturedBody;
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

          return _json(<String, dynamic>{
            'idempotent': false,
            'is_correct': true,
            'points_awarded': 7,
            'correct_answer': 'Reke',
            'correct_answers': <String>['Reke', 'Vode'],
            'association_target': 'b',
            'association_target_label': 'B',
            'session_score': 7,
            'round_time_left': 40,
            'next_step': 'continue',
            'association_progress': <String, dynamic>{
              'round_key': 'round_assoc',
              'round_finished': false,
              'targets': <Map<String, dynamic>>[
                <String, dynamic>{
                  'key': 'b',
                  'label': 'B',
                  'status': 'solved',
                  'owner': 'self',
                  'correct_answer': 'Reke',
                  'correct_answers': <String>['Reke', 'Vode'],
                },
              ],
            },
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'asocijacije',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_associationRound()],
            modeTitle: 'Asocijacije',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.enterText(find.byType(TextField), 'Reke');
      await tester.tap(find.text('Potvrdi polje B'));
      await tester.pump();

      expect(capturedBody?['answer_payload'], <String, dynamic>{
        'target': 'b',
        'answer': 'Reke',
      });
      expect(find.text('B: Tačno! +7 poena'), findsOneWidget);
      expect(find.text('B: Pogođeno - Reke / Vode'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('expired mobile session token is renewed before retry', (
      tester,
    ) async {
      var requestCount = 0;
      final mobileHeaders = <String?>[];
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          requestCount += 1;
          mobileHeaders.add(_mobileHeader(request));
          if (requestCount == 1) {
            return _json(<String, dynamic>{
              'message': 'mobile_session_token is required.',
            }, 401);
          }

          return _json(<String, dynamic>{
            'idempotent': false,
            'is_correct': true,
            'points_awarded': 7,
            'correct_answer': 'Reke',
            'association_target': 'b',
            'association_target_label': 'B',
            'session_score': 7,
            'round_time_left': 40,
            'next_step': 'continue',
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'asocijacije',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_associationRound()],
            modeTitle: 'Asocijacije',
            useCyrillic: false,
            api: api,
            mobileSessionTokenProvider: (_) async => 'mobile-token-2',
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.enterText(find.byType(TextField), 'Reke');
      await tester.tap(find.text('Potvrdi polje B'));
      await tester.pump();

      expect(requestCount, 2);
      expect(mobileHeaders, <String?>['mobile-token', 'mobile-token-2']);
      expect(find.text('B: Tačno! +7 poena'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('wrong association answer keeps target available', (
      tester,
    ) async {
      var requestCount = 0;
      final submittedAnswers = <Map<String, dynamic>>[];
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          requestCount += 1;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          submittedAnswers.add(body['answer_payload'] as Map<String, dynamic>);

          return _json(<String, dynamic>{
            'idempotent': false,
            'is_correct': false,
            'points_awarded': 0,
            'correct_answer': null,
            'association_target': 'a',
            'association_target_label': 'A',
            'session_score': 0,
            'round_time_left': 40,
            'next_step': 'continue',
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'asocijacije',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_associationRound()],
            modeTitle: 'Asocijacije',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pogresno');
      final submitA = find.widgetWithText(ElevatedButton, 'Potvrdi polje A');
      await tester.ensureVisible(submitA);
      await tester.tap(submitA);
      await tester.pump();

      expect(find.text('A: Pogrešno'), findsOneWidget);
      expect(find.textContaining('Tačan odgovor'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.enterText(find.byType(TextField), 'Opet pogresno');
      await tester.ensureVisible(submitA);
      await tester.tap(submitA);
      await tester.pump();

      expect(requestCount, 2);
      expect(submittedAnswers.first['target'], 'a');
      expect(submittedAnswers.last['target'], 'a');

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('opponent association lock disables solved target', (
      tester,
    ) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/state')) {
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'active',
            'score': 0,
            'current_round': 1,
            'round_key': 'round_assoc',
            'round_time_left': 40,
            'association_progress': <String, dynamic>{
              'round_key': 'round_assoc',
              'round_finished': false,
              'targets': <Map<String, dynamic>>[
                <String, dynamic>{
                  'key': 'a',
                  'label': 'A',
                  'status': 'solved',
                  'owner': 'opponent',
                  'correct_answer': 'Gradovi',
                },
              ],
            },
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'asocijacije',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_associationRound()],
            modeTitle: 'Asocijacije',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.pump();
      expect(find.text('Potvrdi polje B'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('Protivnik je pogodio polje A'), findsOneWidget);
      expect(find.text('A: Protivnik - Gradovi'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'A'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.text('Potvrdi polje B'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('server state can append missing Moj Broj round', (
      tester,
    ) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/state')) {
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'active',
            'score': 0,
            'current_round': 2,
            'round_key': 'round_moj',
            'round_time_left': 118,
            'duration_seconds': 120,
            'payload_public': <String, dynamic>{
              'type': 'moj_broj',
              'question_source': 'quiz_my_number',
              'question_id': 7001,
              'target': 523,
              'numbers': <int>[1, 3, 6, 9, 25, 50],
              'prompt': 'Koristi date brojeve.',
            },
            'association_progress': <String, dynamic>{
              'round_key': 'round_assoc',
              'round_finished': true,
            },
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'kviz',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_associationRound()],
            modeTitle: 'Kviz',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('Moj Broj'), findsOneWidget);
      expect(find.text('Traženi broj: 523'), findsOneWidget);
      expect(find.text('118s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('waiting answer polls server after result display delay', (
      tester,
    ) async {
      var stateCalls = 0;
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          return _json(<String, dynamic>{
            'is_correct': false,
            'points_awarded': 0,
            'session_score': 0,
            'next_step': 'wait',
            'round_key': 'round_question',
            'round_time_left': 20,
            'duration_seconds': 45,
            'payload_public': _questionRound().payload,
            'waiting_for_opponent': true,
          });
        }

        if (request.url.path.endsWith('/quiz/sessions/session-1/state')) {
          stateCalls += 1;
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'active',
            'score': 0,
            'current_round': 2,
            'round_key': 'round_moj',
            'round_time_left': 118,
            'duration_seconds': 120,
            'payload_public': <String, dynamic>{
              'type': 'moj_broj',
              'question_source': 'quiz_my_number',
              'question_id': 7001,
              'target': 523,
              'numbers': <int>[1, 3, 6, 9, 25, 50],
              'prompt': 'Koristi date brojeve.',
            },
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'kviz_plus',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_questionRound()],
            modeTitle: 'Kviz+',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      final answerField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Upiši odgovor...',
      );
      await tester.enterText(answerField, 'Srbija');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Potvrdi odgovor'));
      await tester.pump();
      expect(stateCalls, 0);

      await tester.pump(const Duration(milliseconds: 5500));
      await tester.pump();

      expect(stateCalls, greaterThanOrEqualTo(1));
      expect(find.text('Moj Broj'), findsOneWidget);
      expect(find.text('Traženi broj: 523'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('server state resyncs timer for the active round', (
      tester,
    ) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/state')) {
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'active',
            'score': 0,
            'current_round': 1,
            'round_key': 'round_moj',
            'round_time_left': 84,
            'duration_seconds': 120,
            'payload_public': <String, dynamic>{
              'type': 'moj_broj',
              'question_source': 'quiz_my_number',
              'question_id': 7001,
              'target': 523,
              'numbers': <int>[1, 3, 6, 9, 25, 50],
              'prompt': 'Koristi date brojeve.',
            },
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'kviz_plus',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_myNumberRound()],
            modeTitle: 'Kviz+',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('84s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('solo finish response ends without waiting for timer expiry', (
      tester,
    ) async {
      var finishCalls = 0;
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          return _json(<String, dynamic>{
            'idempotent': false,
            'is_correct': true,
            'points_awarded': 42,
            'correct_answer': '523',
            'session_score': 42,
            'round_key': 'round_moj',
            'round_time_left': 98,
            'next_step': 'finish',
          });
        }

        if (request.url.path.endsWith('/quiz/sessions/session-1/finish')) {
          finishCalls += 1;
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'finished',
            'final_score': 42,
          });
        }

        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'solo',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_myNumberRound()],
            modeTitle: 'Kviz Solo',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, '1').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '+'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '3').first);
      await tester.pump();
      final submitButton = find.widgetWithText(
        ElevatedButton,
        'Potvrdi postupak',
      );
      await tester.ensureVisible(submitButton);
      await tester.pump();
      await tester.tap(submitButton);
      await tester.pump();

      expect(finishCalls, 0);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();

      expect(finishCalls, 1);
      expect(find.text('Partija završena!'), findsWidgets);
      expect(find.text('Čeka se sledeća runda...'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'active state without round keeps polling instead of finishing',
      (tester) async {
        var stateCalls = 0;
        var finishCalls = 0;
        final api = _apiFor((request) async {
          if (request.url.path.endsWith('/quiz/sessions/session-1/state')) {
            stateCalls += 1;
            if (stateCalls == 1) {
              return _json(<String, dynamic>{
                'session_id': 'session-1',
                'status': 'active',
                'score': 0,
                'current_round': 2,
                'round_key': null,
                'round_time_left': 0,
                'payload_public': null,
              });
            }

            return _json(<String, dynamic>{
              'session_id': 'session-1',
              'status': 'active',
              'score': 0,
              'current_round': 3,
              'round_key': 'round_moj',
              'round_time_left': 118,
              'duration_seconds': 120,
              'payload_public': <String, dynamic>{
                'type': 'moj_broj',
                'question_source': 'quiz_my_number',
                'question_id': 7001,
                'target': 523,
                'numbers': <int>[1, 3, 6, 9, 25, 50],
                'prompt': 'Koristi date brojeve.',
              },
            });
          }

          if (request.url.path.endsWith('/quiz/sessions/session-1/finish')) {
            finishCalls += 1;
            return _json(<String, dynamic>{
              'session_id': 'session-1',
              'status': 'finished',
              'final_score': 0,
            });
          }

          return _json(<String, dynamic>{'message': 'unexpected'}, 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: OnlineSessionPage(
              modeKey: 'kviz',
              sessionId: 'session-1',
              mobileSessionToken: 'mobile-token',
              accessToken: 'access-token',
              deviceId: 'device-1',
              appVersion: '1.0.0',
              rounds: <OnlineRound>[_associationRound(durationSeconds: 1)],
              modeTitle: 'Kviz',
              useCyrillic: false,
              api: api,
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        expect(stateCalls, 1);
        expect(finishCalls, 0);
        expect(find.text('Partija završena!'), findsNothing);

        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        expect(stateCalls, 2);
        expect(finishCalls, 0);
        expect(find.text('Moj Broj'), findsOneWidget);
        expect(find.text('Traženi broj: 523'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('OnlineSessionPage tangram', () {
    testWidgets('dragging on tangram board does not scroll parent list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _apiFor((request) async {
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'tangram',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_tangramRound()],
            modeTitle: 'Tangram',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels, 0);

      final boardCenter = tester.getCenter(
        find.byKey(const ValueKey<String>('online_tangram_board')),
      );
      final gesture = await tester.startGesture(boardCenter);
      await gesture.moveBy(const Offset(0, -28));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -140));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(scrollable.position.pixels, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'tangram piece is selectable when dragged from any point within the figure',
      (tester) async {
        // This test proves that the expanded hit zone works: a piece can be
        // selected (and dragged) from a corner/edge point far from the centroid,
        // not only from the geometric center of the figure.
        tester.view.physicalSize = const Size(390, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api = _apiFor((request) async {
          return _json(<String, dynamic>{'message': 'unexpected'}, 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: OnlineSessionPage(
              modeKey: 'tangram',
              sessionId: 'session-1',
              mobileSessionToken: 'mobile-token',
              accessToken: 'access-token',
              deviceId: 'device-1',
              appVersion: '1.0.0',
              rounds: <OnlineRound>[_tangramRound()],
              modeTitle: 'Tangram',
              useCyrillic: false,
              api: api,
            ),
          ),
        );

        // No piece selected yet.
        expect(find.text('Izaberi deo'), findsOneWidget);

        // Compute the screen position of a non-center point inside large_triangle_1.
        // large_triangle_1: position=(24,24), base polygon [(0,0),(140,0),(0,140)]
        // → logical vertices at (24,24), (164,24), (24,164), centroid ≈ (71,71).
        // We tap at logical (148, 28) — near the top-right corner, far from centroid.
        // Verification: base coords (124,4), 124+4=128 ≤ 140 → inside the triangle.
        final boardFinder = find.byKey(
          const ValueKey<String>('online_tangram_board'),
        );
        final boardTopLeft = tester.getTopLeft(boardFinder);
        final boardSize = tester.getSize(boardFinder);

        final padding = boardSize.shortestSide * 0.08;
        final scale = (boardSize.width - 2 * padding) / 420;
        final transformDx = (boardSize.width - 420 * scale) / 2;
        final transformDy = (boardSize.height - 420 * scale) / 2;

        const logicalPoint = Offset(148, 28);
        final screenPoint =
            boardTopLeft +
            Offset(
              transformDx + logicalPoint.dx * scale,
              transformDy + logicalPoint.dy * scale,
            );

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );

        // Drag from the edge/corner point — piece must be selected, parent must
        // not scroll.
        final gesture = await tester.startGesture(screenPoint);
        await gesture.moveBy(const Offset(25, 15));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        // The large_triangle_1 piece was hit from a non-center point.
        expect(find.text('Veliki trougao'), findsOneWidget);
        expect(scrollable.position.pixels, 0);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('OnlineSessionPage content reports', () {
    testWidgets('association round shows report button that saves draft', (
      tester,
    ) async {
      final api = _apiFor((request) async {
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'asocijacije',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_associationRound()],
            modeTitle: 'Asocijacije',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      expect(find.text('Prijavi'), findsOneWidget);

      await tester.tap(find.text('Prijavi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sačuvaj'));
      await tester.pumpAndSettle();

      expect(find.text('Prijavljeno'), findsOneWidget);
      expect(find.text('Sačuvano za kraj partije.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('report draft can be edited on finish screen', (tester) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          return _json(<String, dynamic>{
            'idempotent': false,
            'is_correct': true,
            'points_awarded': 10,
            'correct_answer': 'Beograd',
            'session_score': 10,
            'round_time_left': 20,
            'next_step': 'finish',
          });
        }
        if (request.url.path.endsWith('/quiz/sessions/session-1/finish')) {
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'finished',
            'final_score': 10,
          });
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'pitanja',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_questionRound()],
            modeTitle: 'Pitanja',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      // Save a report draft (no comment) during the active round.
      await tester.tap(find.text('Prijavi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sačuvaj'));
      await tester.pumpAndSettle();
      expect(find.text('Prijavljeno'), findsOneWidget);

      // Submit a text answer; server signals 'finish'.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Upiši odgovor...',
        ),
        'Beograd',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Potvrdi odgovor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6200));
      await tester.pump();

      // Finish screen appears with the draft review section.
      expect(find.text('Pregled prijava'), findsOneWidget);
      expect(find.text('Izmeni'), findsOneWidget);

      // Edit the draft to add a comment.
      await tester.tap(find.text('Izmeni'));
      await tester.pumpAndSettle();

      final commentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Komentar',
      );
      await tester.enterText(commentField, 'Ispravljeni komentar');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sačuvaj'));
      await tester.pumpAndSettle();

      // The updated comment is now visible in the review card.
      expect(find.text('Ispravljeni komentar'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'second tap on same content opens existing draft without duplicating',
      (tester) async {
        final api = _apiFor((request) async {
          return _json(<String, dynamic>{'message': 'unexpected'}, 404);
        });

        await tester.pumpWidget(
          MaterialApp(
            home: OnlineSessionPage(
              modeKey: 'pitanja',
              sessionId: 'session-1',
              mobileSessionToken: 'mobile-token',
              accessToken: 'access-token',
              deviceId: 'device-1',
              appVersion: '1.0.0',
              rounds: <OnlineRound>[_questionRound()],
              modeTitle: 'Pitanja',
              useCyrillic: false,
              api: api,
            ),
          ),
        );

        // First report: enter a specific comment and save.
        await tester.tap(find.text('Prijavi'));
        await tester.pumpAndSettle();

        final commentFinder = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText ==
                  'Zašto mislite da je loše ili pogrešno?',
        );
        await tester.enterText(commentFinder, 'Originalni komentar');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Sačuvaj'));
        await tester.pumpAndSettle();
        expect(find.text('Prijavljeno'), findsOneWidget);

        // Second tap on the same content opens the EXISTING draft.
        await tester.tap(find.text('Prijavljeno'));
        await tester.pumpAndSettle();

        // The comment field is pre-filled — no blank new draft was created.
        expect(
          tester.widget<TextField>(commentFinder).controller?.text,
          'Originalni komentar',
        );

        await tester.tap(find.widgetWithText(OutlinedButton, 'Otkaži'));
        await tester.pumpAndSettle();
        expect(find.text('Prijavljeno'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('API error on report submit keeps draft available for retry', (
      tester,
    ) async {
      final api = _apiFor((request) async {
        if (request.url.path.endsWith('/quiz/sessions/session-1/answer')) {
          return _json(<String, dynamic>{
            'idempotent': false,
            'is_correct': true,
            'points_awarded': 10,
            'correct_answer': 'Beograd',
            'session_score': 10,
            'round_time_left': 20,
            'next_step': 'finish',
          });
        }
        if (request.url.path.endsWith('/quiz/sessions/session-1/finish')) {
          return _json(<String, dynamic>{
            'session_id': 'session-1',
            'status': 'finished',
            'final_score': 10,
          });
        }
        if (request.url.path.endsWith('/quiz/content-reports')) {
          return _json(<String, dynamic>{'message': 'Server error'}, 500);
        }
        return _json(<String, dynamic>{'message': 'unexpected'}, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSessionPage(
            modeKey: 'pitanja',
            sessionId: 'session-1',
            mobileSessionToken: 'mobile-token',
            accessToken: 'access-token',
            deviceId: 'device-1',
            appVersion: '1.0.0',
            rounds: <OnlineRound>[_questionRound()],
            modeTitle: 'Pitanja',
            useCyrillic: false,
            api: api,
          ),
        ),
      );

      // Save a report draft.
      await tester.tap(find.text('Prijavi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sačuvaj'));
      await tester.pumpAndSettle();

      // Submit a text answer; server signals 'finish'.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Upiši odgovor...',
        ),
        'Beograd',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Potvrdi odgovor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 6200));
      await tester.pump();

      expect(find.text('Pregled prijava'), findsOneWidget);
      expect(find.text('Pošalji prijave'), findsOneWidget);

      // Attempt to submit; API returns 500.
      await tester.tap(find.text('Pošalji prijave'));
      await tester.pump();

      // Error is displayed and the draft remains available for retry.
      expect(
        find.text('Slanje nije uspelo. Pokušajte ponovo.'),
        findsOneWidget,
      );
      expect(find.text('Pregled prijava'), findsOneWidget);
      expect(find.text('Pošalji prijave'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

OnlineRound _questionRound() {
  return OnlineRound.fromJson({
    'round_key': 'round_question',
    'round_order': 1,
    'duration_seconds': 45,
    'payload_public': {
      'type': 'question',
      'question_source': 'quiz_questions',
      'question_id': 5001,
      'question_text': 'Koji je glavni grad Srbije?',
      'answer_hint': {
        'answer': 'Tajni odgovor',
        'max_reveal_percent': 69,
        'char_count': 7,
      },
      'choices': [
        {'label': 'A', 'text': 'Beograd'},
        {'label': 'B', 'text': 'Novi Sad'},
      ],
    },
  });
}

OnlineRound _associationRound({int durationSeconds = 45}) {
  return OnlineRound.fromJson({
    'round_key': 'round_assoc',
    'round_order': 1,
    'duration_seconds': durationSeconds,
    'payload_public': {
      'type': 'asocijacije',
      'question_source': 'quiz_associations',
      'question_id': 6101,
      'max_answers': 999,
      'grid': {
        'a': ['Beograd', 'Nis', 'Kragujevac', 'Subotica'],
        'b': ['Sava', 'Dunav', 'Tisa', 'Morava'],
        'v': ['Tara', 'Zlatibor', 'Kopaonik', 'Rtanj'],
        'g': ['Sljiva', 'Malina', 'Kupina', 'Jabuka'],
      },
      'answer_targets': [
        {'key': 'a', 'label': 'A'},
        {'key': 'b', 'label': 'B'},
        {'key': 'v', 'label': 'V'},
        {'key': 'g', 'label': 'G'},
        {'key': 'final', 'label': 'Konačno'},
      ],
    },
  });
}

OnlineRound _myNumberRound() {
  return OnlineRound.fromJson({
    'round_key': 'round_moj',
    'round_order': 1,
    'duration_seconds': 120,
    'payload_public': {
      'type': 'moj_broj',
      'question_source': 'quiz_my_number',
      'question_id': 7001,
      'target': 523,
      'numbers': [1, 3, 6, 9, 25, 50],
      'prompt': 'Koristi date brojeve.',
    },
  });
}

OnlineRound _tangramRound() {
  return OnlineRound.fromJson({
    'round_key': 'round_tangram',
    'round_order': 1,
    'duration_seconds': 120,
    'payload_public': {
      'type': 'tangram',
      'question_source': 'quiz_tangram',
      'question_id': 2001,
      'title': 'Kuca',
      'difficulty': 'easy',
      'hint': 'Pocni od najveceg trougla.',
      'shape': {
        'canvas': {'width': 420, 'height': 420},
        'polygons': [
          [
            {'x': 140, 'y': 120},
            {'x': 280, 'y': 120},
            {'x': 280, 'y': 260},
            {'x': 140, 'y': 260},
          ],
        ],
      },
    },
  });
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
