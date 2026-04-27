import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart'
    show
        FlutterError,
        FlutterErrorDetails,
        TargetPlatform,
        defaultTargetPlatform,
        kDebugMode,
        kIsWeb,
        visibleForTesting;
import 'package:http/http.dart' as http;

import '../data/remote/analytics_service.dart';
import '../data/remote/api_exception.dart';
import '../firebase_options.dart';

Future<bool> initializeKvizFirebase() async {
  if (!DefaultFirebaseOptions.isConfiguredForCurrentPlatform) {
    return false;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    const recaptchaSiteKey = String.fromEnvironment(
      'KVIZ_APP_CHECK_RECAPTCHA_SITE_KEY',
    );
    if (recaptchaSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(recaptchaSiteKey),
      );
    }
    await _initializeFirebaseAnalytics();
    return true;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  }

  await _initializeFirebaseAnalytics();
  await _initializeCrashlytics();
  return true;
}

bool get _isFirebaseAnalyticsSupportedPlatform {
  if (kIsWeb) {
    return DefaultFirebaseOptions.web.measurementId?.isNotEmpty ?? false;
  }

  return defaultTargetPlatform == TargetPlatform.android;
}

Future<void> _initializeFirebaseAnalytics() async {
  await KvizAnalytics.initialize(
    enabled: _isFirebaseAnalyticsSupportedPlatform,
  );
}

Future<void> _initializeCrashlytics() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = _recordFlutterErrorWithSeverity;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: isCrashlyticsFatalError(error),
      ),
    );
    return true;
  };
}

void _recordFlutterErrorWithSeverity(FlutterErrorDetails details) {
  final error = details.exception;
  if (isCrashlyticsFatalError(error)) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    return;
  }

  FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false);
}

@visibleForTesting
bool isCrashlyticsFatalError(Object error) {
  if (error is TimeoutException ||
      error is http.ClientException ||
      error is ApiException) {
    return false;
  }

  return true;
}
