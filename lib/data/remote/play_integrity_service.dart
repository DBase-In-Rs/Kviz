import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlayIntegrityService {
  const PlayIntegrityService({
    MethodChannel channel = const MethodChannel(
      'rs.in.dbase.kviz/play_integrity',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<String> requestIntegrityToken(String nonce) async {
    final trimmedNonce = nonce.trim();
    if (trimmedNonce.isEmpty) {
      throw const PlayIntegrityException('nonce is required');
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const PlayIntegrityException(
        'Play Integrity token can be requested only on Android.',
      );
    }

    try {
      final token = await _channel.invokeMethod<String>(
        'requestIntegrityToken',
        <String, String>{'nonce': trimmedNonce},
      );
      final trimmedToken = token?.trim();
      if (trimmedToken == null || trimmedToken.isEmpty) {
        throw const PlayIntegrityException('Play Integrity token was empty.');
      }
      return trimmedToken;
    } on PlatformException catch (error) {
      throw PlayIntegrityException(error.message ?? error.code);
    }
  }
}

class PlayIntegrityException implements Exception {
  const PlayIntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}
