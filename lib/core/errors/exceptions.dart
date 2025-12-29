class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({
    this.message = 'Server error occurred',
    this.statusCode,
  });

  @override
  String toString() => 'ServerException: $message (statusCode: $statusCode)';
}

class CacheException implements Exception {
  final String message;

  const CacheException({this.message = 'Cache error occurred'});

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException({this.message = 'Network error occurred'});

  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException({
    this.message = 'Authentication error occurred',
    this.code,
  });

  @override
  String toString() => 'AuthException: $message (code: $code)';
}

class LocationException implements Exception {
  final String message;

  const LocationException({this.message = 'Location error occurred'});

  @override
  String toString() => 'LocationException: $message';
}

class EncryptionException implements Exception {
  final String message;

  const EncryptionException({this.message = 'Encryption error occurred'});

  @override
  String toString() => 'EncryptionException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? errors;

  const ValidationException({
    this.message = 'Validation error occurred',
    this.errors,
  });

  @override
  String toString() => 'ValidationException: $message';
}

class PermissionException implements Exception {
  final String message;
  final String? permission;

  const PermissionException({
    this.message = 'Permission denied',
    this.permission,
  });

  @override
  String toString() => 'PermissionException: $message (permission: $permission)';
}
