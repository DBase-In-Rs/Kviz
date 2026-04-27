import 'dart:async';

import 'package:flutter/material.dart';

import 'app/firebase_bootstrap.dart';
import 'app/kviz_app.dart';
import 'data/local/app_repositories.dart';
import 'presentation/admob_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReadyFuture = initializeKvizFirebase();
  unawaited(KvizAdMob.initialization);
  final repositories = createLocalRepositories();
  runApp(
    KvizApp(
      repositories: repositories,
      firebaseReadyFuture: firebaseReadyFuture,
    ),
  );
}
