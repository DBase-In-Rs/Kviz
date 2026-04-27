class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.method,
    this.path,
    this.responseBody,
  });

  final int statusCode;
  final String message;
  final String? method;
  final String? path;
  final Object? responseBody;

  @override
  String toString() {
    final endpoint = path == null ? '' : ', endpoint: ${method ?? ''} $path';
    return 'ApiException(statusCode: $statusCode$endpoint, message: $message)';
  }
}
