import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kviz/data/remote/api_client.dart';

void main() {
  test(
    'retries authenticated request once with refreshed bearer token',
    () async {
      final requests = <http.Request>[];
      var refreshCalls = 0;
      final client = ApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        accessTokenRefresher: (rejectedToken) async {
          refreshCalls += 1;
          expect(rejectedToken, 'old-token');
          return 'new-token';
        },
        httpClient: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            return http.Response(
              jsonEncode(<String, dynamic>{'message': 'Unauthenticated.'}),
              401,
            );
          }

          return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
        }),
      );

      final payload = await client.postJson(
        '/quiz/sessions/start',
        headers: const <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer old-token',
        },
        body: const <String, dynamic>{'mode': 'kviz'},
      );

      expect(payload['ok'], isTrue);
      expect(refreshCalls, 1);
      expect(requests, hasLength(2));
      expect(requests.first.headers['Authorization'], 'Bearer old-token');
      expect(requests.last.headers['Authorization'], 'Bearer new-token');
      expect(requests.last.body, jsonEncode(<String, dynamic>{'mode': 'kviz'}));
    },
  );
}
