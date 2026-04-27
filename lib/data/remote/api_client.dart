import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import 'analytics_service.dart';
import 'api_exception.dart';

typedef AccessTokenRefresher =
    Future<String?> Function(String rejectedAccessToken);

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.accessTokenRefresher,
    this.timeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final AccessTokenRefresher? accessTokenRefresher;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> headers = const <String, String>{},
    Map<String, String>? queryParameters,
  }) async {
    final stopwatch = Stopwatch()..start();
    final requestHeaders = Map<String, String>.from(headers);
    var response = await _httpClient
        .get(_buildUri(path, queryParameters), headers: requestHeaders)
        .timeout(timeout);
    response = await _retryAfterUnauthorized(
      response,
      requestHeaders,
      (retryHeaders) => _httpClient
          .get(_buildUri(path, queryParameters), headers: retryHeaders)
          .timeout(timeout),
    );

    stopwatch.stop();
    _logResponse('GET', path, response.statusCode, stopwatch.elapsed);

    return _parseResponse(response, method: 'GET', path: path);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final stopwatch = Stopwatch()..start();
    final requestHeaders = Map<String, String>.from(headers);
    final encodedBody = jsonEncode(body);
    var response = await _httpClient
        .post(_buildUri(path, null), headers: requestHeaders, body: encodedBody)
        .timeout(timeout);
    response = await _retryAfterUnauthorized(
      response,
      requestHeaders,
      (retryHeaders) => _httpClient
          .post(_buildUri(path, null), headers: retryHeaders, body: encodedBody)
          .timeout(timeout),
    );

    stopwatch.stop();
    _logResponse('POST', path, response.statusCode, stopwatch.elapsed);

    return _parseResponse(response, method: 'POST', path: path);
  }

  Uri _buildUri(String path, Map<String, String>? queryParameters) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    final uri = Uri.parse('$normalizedBase/$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Future<http.Response> _retryAfterUnauthorized(
    http.Response response,
    Map<String, String> headers,
    Future<http.Response> Function(Map<String, String> headers) retry,
  ) async {
    if (response.statusCode != 401 || accessTokenRefresher == null) {
      return response;
    }

    final rejectedToken = _bearerToken(headers['Authorization']);
    if (rejectedToken == null) {
      return response;
    }

    try {
      final nextToken = (await accessTokenRefresher!(rejectedToken))?.trim();
      if (nextToken == null ||
          nextToken.isEmpty ||
          nextToken == rejectedToken) {
        return response;
      }

      final retryHeaders = Map<String, String>.from(headers);
      retryHeaders['Authorization'] = 'Bearer $nextToken';

      return await retry(retryHeaders);
    } catch (_) {
      return response;
    }
  }

  String? _bearerToken(String? header) {
    if (header == null) {
      return null;
    }

    final value = header.trim();
    const prefix = 'Bearer ';
    if (!value.startsWith(prefix)) {
      return null;
    }

    final token = value.substring(prefix.length).trim();
    return token.isEmpty ? null : token;
  }

  Map<String, dynamic> _parseResponse(
    http.Response response, {
    required String method,
    required String path,
  }) {
    final dynamic decoded = _tryDecodeJson(response.body);
    final bodyMap = _asMap(decoded);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (bodyMap != null) {
        return bodyMap;
      }

      return <String, dynamic>{'data': decoded};
    }

    final message =
        bodyMap?['message'] as String? ??
        bodyMap?['error'] as String? ??
        (response.body.isEmpty
            ? 'Request failed with status ${response.statusCode}'
            : response.body);

    KvizAnalytics.apiErrorOccurred(
      statusCode: response.statusCode,
      endpoint: path,
    );
    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      method: method,
      path: path,
      responseBody: decoded,
    );
  }

  void _logResponse(
    String method,
    String path,
    int statusCode,
    Duration elapsed,
  ) {
    if (!kDebugMode) {
      return;
    }

    developer.log(
      '$method $path -> $statusCode (${elapsed.inMilliseconds} ms)',
      name: 'KvizApi',
    );
  }

  dynamic _tryDecodeJson(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{'raw': body};
    }
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
}
