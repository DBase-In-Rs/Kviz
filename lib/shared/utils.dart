import '../data/remote/auth_models.dart';
import 'serbian_script.dart';

export 'serbian_script.dart';

String tr(bool cyrillic, String latin, [String? cyrillicText]) {
  return cyrillic
      ? cyrillicText ?? toSerbianCyrillic(latin)
      : toSerbianLatin(latin);
}

String? achievementUserKeyForSession(AuthSession session) {
  final user = session.user;
  final googleSub = user.googleSub?.trim();
  if (googleSub != null && googleSub.isNotEmpty) {
    return 'google:$googleSub';
  }

  final id = user.id;
  if (id != null) {
    return 'user:$id';
  }

  final email = user.email?.trim();
  if (email != null && email.isNotEmpty) {
    return 'email:$email';
  }

  return null;
}
