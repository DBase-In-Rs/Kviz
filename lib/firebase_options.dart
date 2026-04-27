import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfiguredForCurrentPlatform {
    if (kIsWeb) {
      return web.appId.isNotEmpty;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (web.appId.isEmpty) {
        throw UnsupportedError(
          'Firebase web app nije podesen. Prosledi '
          'KVIZ_FIREBASE_WEB_APP_ID ili preskoci Firebase na web-u.',
        );
      }
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions nisu podesene za ovu platformu.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'KVIZ_FIREBASE_WEB_API_KEY',
      defaultValue: 'AIzaSyByucjlxNPCHt3HaDvE8Wp3twx3wIT2peQ',
    ),
    appId: String.fromEnvironment('KVIZ_FIREBASE_WEB_APP_ID'),
    messagingSenderId: String.fromEnvironment(
      'KVIZ_FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '224945393225',
    ),
    projectId: String.fromEnvironment(
      'KVIZ_FIREBASE_PROJECT_ID',
      defaultValue: 'kviz-dbase',
    ),
    authDomain: String.fromEnvironment(
      'KVIZ_FIREBASE_AUTH_DOMAIN',
      defaultValue: 'kviz-dbase.firebaseapp.com',
    ),
    storageBucket: String.fromEnvironment(
      'KVIZ_FIREBASE_STORAGE_BUCKET',
      defaultValue: 'kviz-dbase.firebasestorage.app',
    ),
    measurementId: String.fromEnvironment('KVIZ_FIREBASE_MEASUREMENT_ID'),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyByucjlxNPCHt3HaDvE8Wp3twx3wIT2peQ',
    appId: '1:224945393225:android:de6b013a9c42fc03c73998',
    messagingSenderId: '224945393225',
    projectId: 'kviz-dbase',
    storageBucket: 'kviz-dbase.firebasestorage.app',
  );
}
