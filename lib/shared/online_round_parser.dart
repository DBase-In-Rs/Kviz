import '../data/remote/integrity_flow_service.dart';
import '../domain/online_round_models.dart';

List<OnlineRound> parseOnlineRoundsFromPayload(Object? rawRounds) {
  if (rawRounds is! List) {
    throw const IntegrityFlowException(
      'Neispravan odgovor od servera pri pokretanju sesije.',
    );
  }

  return rawRounds.map((rawRound) {
    if (rawRound is! Map) {
      throw const IntegrityFlowException(
        'Neispravan odgovor od servera pri pokretanju sesije.',
      );
    }

    return OnlineRound.fromJson(Map<String, dynamic>.from(rawRound));
  }).toList();
}
