class AuthFlowException implements Exception {
  AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.googleSub,
  });

  final int? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? googleSub;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _asInt(json['id']),
      email: _asString(json['email']),
      firstName: _asString(json['first_name']),
      lastName: _asString(json['last_name']),
      avatarUrl: _asString(json['avatar_url']),
      googleSub: _asString(json['google_sub']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'google_sub': googleSub,
    };
  }

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) {
      return full;
    }

    final mail = email?.trim() ?? '';
    if (mail.isNotEmpty) {
      return mail;
    }

    return 'Korisnik';
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final AuthUser user;

  factory AuthSession.fromLoginResponse(Map<String, dynamic> data) {
    final userMap = _asMap(data['user']) ?? <String, dynamic>{};

    return AuthSession(
      accessToken: _requiredString(data, 'access_token'),
      refreshToken: _requiredString(data, 'refresh_token'),
      tokenType: _asString(data['token_type']) ?? 'Bearer',
      user: AuthUser.fromJson(userMap),
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> data) {
    return AuthSession(
      accessToken: _requiredString(data, 'access_token'),
      refreshToken: _requiredString(data, 'refresh_token'),
      tokenType: _asString(data['token_type']) ?? 'Bearer',
      user: AuthUser.fromJson(_asMap(data['user']) ?? <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    AuthUser? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      user: user ?? this.user,
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = _asString(map[key]);
  if (value == null || value.isEmpty) {
    throw AuthFlowException('Missing required field: $key');
  }

  return value;
}

String? _asString(dynamic value) {
  if (value == null) {
    return null;
  }

  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, dynamic data) => MapEntry(key.toString(), data));
  }

  return null;
}
