/// استثناء أساسي
class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

/// استثناء الخادم
class ServerException extends AppException {
  ServerException([super.message = 'Server error occurred']);
}

/// استثناء الشبكة
class NetworkException extends AppException {
  NetworkException([super.message = 'Network connection failed']);
}

/// استثناء التخزين المحلي
class CacheException extends AppException {
  CacheException([super.message = 'Cache operation failed']);
}

/// استثناء المصادقة
class AuthException extends AppException {
  AuthException([super.message = 'Authentication failed']);
}

/// استثناء التحقق
class ValidationException extends AppException {
  ValidationException([super.message = 'Validation failed']);
}

/// استثناء الصلاحيات
class PermissionException extends AppException {
  PermissionException([super.message = 'Permission denied']);
}

/// استثناء عدم العثور
class NotFoundException extends AppException {
  NotFoundException([super.message = 'Resource not found']);
}

/// استثناء العملية
class OperationException extends AppException {
  OperationException([super.message = 'Operation failed']);
}

/// استثناء غير معروف
class UnknownException extends AppException {
  UnknownException([super.message = 'Unknown error occurred']);
}

/// استثناء الموقع
class LocationException extends AppException {
  LocationException([super.message = 'Location service failed']);
}

/// استثناء المزامنة
class SyncException extends AppException {
  SyncException([super.message = 'Synchronization failed']);
}

/// استثناء Firebase
class FirebaseException extends AppException {
  FirebaseException([super.message = 'Firebase operation failed']);
}

/// استثناء الخرائط
class MapException extends AppException {
  MapException([super.message = 'Map operation failed']);
}

/// استثناء الإشعارات
class NotificationException extends AppException {
  NotificationException([super.message = 'Notification failed']);
}

/// استثناء ML
class MLException extends AppException {
  MLException([super.message = 'ML operation failed']);
}

/// استثناء التخزين السحابي (Firebase Storage)
class StorageException extends AppException {
  StorageException([super.message = 'Storage operation failed']);
}
