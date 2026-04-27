import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kviz/app/firebase_bootstrap.dart';
import 'package:kviz/data/remote/api_exception.dart';

void main() {
  group('isCrashlyticsFatalError', () {
    test('treats HTTP client failures as non-fatal', () {
      expect(
        isCrashlyticsFatalError(http.ClientException('network down')),
        isFalse,
      );
    });

    test('treats timeouts as non-fatal', () {
      expect(
        isCrashlyticsFatalError(TimeoutException('slow response')),
        isFalse,
      );
    });

    test('treats API failures as non-fatal', () {
      expect(
        isCrashlyticsFatalError(
          ApiException(
            statusCode: 401,
            method: 'POST',
            path: '/quiz/presence',
            message: 'Unauthenticated.',
          ),
        ),
        isFalse,
      );
    });

    test('keeps programming errors fatal', () {
      expect(isCrashlyticsFatalError(StateError('bad state')), isTrue);
    });
  });
}
