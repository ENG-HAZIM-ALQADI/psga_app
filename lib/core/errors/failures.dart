import 'package:equatable/equatable.dart';

/// الفشل الأساسي
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// فشل في الخادم
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

/// فشل في الاتصال بالشبكة
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network connection failed']);
}

/// فشل في التخزين المحلي
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache operation failed']);
}

/// فشل في المصادقة
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

/// فشل في التحقق من الصلاحية
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed']);
}

/// فشل في الصلاحيات
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied']);
}

/// فشل في العثور على البيانات
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

/// فشل في العملية
class OperationFailure extends Failure {
  const OperationFailure([super.message = 'Operation failed']);
}

/// فشل غير معروف
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error occurred']);
}

/// فشل في الموقع
class LocationFailure extends Failure {
  const LocationFailure([super.message = 'Location service failed']);
}

/// فشل في المزامنة
class SyncFailure extends Failure {
  const SyncFailure([super.message = 'Synchronization failed']);
}

/// فشل في Firebase
class FirebaseFailure extends Failure {
  const FirebaseFailure([super.message = 'Firebase operation failed']);
}

/// فشل في الخرائط
class MapFailure extends Failure {
  const MapFailure([super.message = 'Map operation failed']);
}

/// فشل في الإشعارات
class NotificationFailure extends Failure {
  const NotificationFailure([super.message = 'Notification failed']);
}

/// فشل في ML
class MLFailure extends Failure {
  const MLFailure([super.message = 'ML operation failed']);
}

/// فشل في التخزين السحابي (Firebase Storage)
class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage operation failed']);
}

/// يوجد رحلة نشطة بالفعل
class ActiveTripExistsFailure extends Failure {
  final String activeTripId;

  const ActiveTripExistsFailure(
    super.message, {
    required this.activeTripId,
  });

  @override
  List<Object> get props => [message, activeTripId];
}
