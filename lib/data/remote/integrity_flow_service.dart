import 'api_exception.dart';
import 'laravel_api_service.dart';
import 'play_integrity_service.dart';

class IntegrityFlowService {
  const IntegrityFlowService({
    required LaravelApiService api,
    required PlayIntegrityService playIntegrity,
  }) : _api = api,
       _playIntegrity = playIntegrity;

  final LaravelApiService _api;
  final PlayIntegrityService _playIntegrity;

  /// Runs: nonce → Play Integrity token → /mobile/integrity/verify
  /// Returns the short-lived mobile_session_token from the backend.
  Future<String> acquireMobileSessionToken({
    required String accessToken,
    required String deviceId,
    required String appVersion,
  }) async {
    final nonceResp = await _api.requestIntegrityNonce(
      accessToken: accessToken,
      deviceId: deviceId,
    );
    final nonce = (nonceResp['nonce'] as String?)?.trim() ?? '';
    if (nonce.isEmpty) {
      throw const IntegrityFlowException('Backend did not return nonce.');
    }

    final integrityToken = await _playIntegrity.requestIntegrityToken(nonce);

    final verifyResp = await _api.verifyIntegrity(
      accessToken: accessToken,
      integrityToken: integrityToken,
      nonce: nonce,
      deviceId: deviceId,
      appVersion: appVersion,
    );

    final token = (verifyResp['mobile_session_token'] as String?)?.trim() ?? '';
    if (token.isEmpty) {
      final reason = verifyResp['reason'] as String? ?? 'unknown';
      throw IntegrityFlowException('Integrity verification failed: $reason');
    }
    return token;
  }
}

class IntegrityFlowException implements Exception {
  const IntegrityFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Maps various integrity/server exceptions to user-visible Serbian messages.
String mapIntegrityError(Object error, bool cyrillic) {
  String t(String lat, String cyr) => cyrillic ? cyr : lat;

  if (error is IntegrityFlowException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('play integrity') || msg.contains('platform')) {
      return t(
        'Play Integrity nije dostupan na ovom uređaju. Pokušaj na fizičkom uređaju.',
        'Play Integrity није доступан на овом уређају. Покушај на физичком уређају.',
      );
    }
    if (msg.contains('nonce')) {
      return t(
        'Greška pri proveri integriteta (nonce). Pokušaj ponovo.',
        'Грешка при провери интегритета (nonce). Покушај поново.',
      );
    }
    return t(
      'Provera integriteta nije uspela. Pokušaj ponovo.',
      'Провера интегритета није успела. Покушај поново.',
    );
  }

  if (error is ApiException) {
    final endpoint = error.path == null ? '' : ' (${error.path})';
    if (error.statusCode == 502) {
      return t(
        'Server trenutno ne odgovara$endpoint. Pokušaj ponovo za minut.',
        'Сервер тренутно не одговара$endpoint. Покушај поново за минут.',
      );
    }
    if (error.statusCode >= 500) {
      return t(
        'Greška na serveru$endpoint. Pokušaj ponovo kasnije.',
        'Грешка на серверу$endpoint. Покушај поново касније.',
      );
    }
    if (error.statusCode == 403) {
      return t(
        'Uređaj nije prošao proveru integriteta.',
        'Уређај није прошао проверу интегритета.',
      );
    }
    if (error.statusCode == 409) {
      final msg = error.message.toLowerCase();
      if (msg.contains('daily_game_quota_exhausted')) {
        return t(
          'Danas si iskoristio dostupne partije. U Podešavanjima možeš da pogledaš nagrađenu reklamu za još jednu partiju.',
          'Данас си искористио доступне партије. У Подешавањима можеш да погледаш награђену рекламу за још једну партију.',
        );
      }
      if (msg.contains('reward_quota_exhausted')) {
        return t(
          'Danas si iskoristio sve bonus reklame.',
          'Данас си искористио све бонус рекламе.',
        );
      }
      if (msg.contains('premier_subscription_required')) {
        return t(
          'Premier kviz je dostupan samo aktivnim Premier korisnicima.',
          'Премијер квиз је доступан само активним Премијер корисницима.',
        );
      }
      return t(
        'Već imaš aktivnu partiju za ovaj mod.',
        'Већ имаш активну партију за овај мод.',
      );
    }
    return 'Server ${error.statusCode}: ${error.message}';
  }

  return error.toString();
}
