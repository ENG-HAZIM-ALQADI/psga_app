import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error occurred. Please try again later.',
    super.code,
  });
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache error occurred. Please try again.',
    super.code,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
  });
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed. Please login again.',
    super.code,
  });
}

class LocationFailure extends Failure {
  const LocationFailure({
    super.message = 'Unable to get your location. Please enable location services.',
    super.code,
  });
}

class EncryptionFailure extends Failure {
  const EncryptionFailure({
    super.message = 'Encryption error occurred. Please try again.',
    super.code,
  });
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'Validation error. Please check your input.',
    super.code,
  });
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission denied. Please grant the required permissions.',
    super.code,
  });
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unknown error occurred. Please try again.',
    super.code,
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Resource not found.',
    super.code,
  });
}
