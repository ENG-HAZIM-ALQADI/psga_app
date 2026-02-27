import 'package:flutter/foundation.dart';

/// خدمة تسجيل الرسائل
class AppLogger {
  AppLogger._();

  static const String _prefix = '[PSGA]';

  /// رسالة معلومات عامة
  static void info(String message, [dynamic data]) {
    if (kDebugMode) {
      print('$_prefix ℹ️ INFO: $message');
      if (data != null) {
        print('   Data: $data');
      }
    }
  }

  /// رسالة نجاح
  static void success(String message, [dynamic data]) {
    if (kDebugMode) {
      print('$_prefix ✅ SUCCESS: $message');
      if (data != null) {
        print('   Data: $data');
      }
    }
  }

  /// رسالة تحذير
  static void warning(String message, [dynamic data]) {
    if (kDebugMode) {
      print('$_prefix ⚠️ WARNING: $message');
      if (data != null) {
        print('   Data: $data');
      }
    }
  }

  /// رسالة خطأ
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('$_prefix ❌ ERROR: $message');
      if (error != null) {
        print('   Error: $error');
      }
      if (stackTrace != null) {
        print('   StackTrace: $stackTrace');
      }
    }
  }

  /// رسالة تصحيح (Debug)
  static void debug(String message, [dynamic data]) {
    if (kDebugMode) {
      print('$_prefix 🐛 DEBUG: $message');
      if (data != null) {
        print('   Data: $data');
      }
    }
  }

  /// رسالة بداية عملية
  static void start(String operation) {
    if (kDebugMode) {
      print('$_prefix 🚀 START: $operation');
    }
  }

  /// رسالة نهاية عملية
  static void end(String operation, [Duration? duration]) {
    if (kDebugMode) {
      if (duration != null) {
        print('$_prefix 🏁 END: $operation (${duration.inMilliseconds}ms)');
      } else {
        print('$_prefix 🏁 END: $operation');
      }
    }
  }

  /// قياس وقت تنفيذ عملية
  static Future<T> timed<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    start(operation);
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      end(operation, stopwatch.elapsed);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      error('$operation فشل', e, stackTrace);
      rethrow;
    }
  }

  /// رسالة مخصصة
  static void custom(String emoji, String tag, String message, [dynamic data]) {
    if (kDebugMode) {
      print('$_prefix $emoji $tag: $message');
      if (data != null) {
        print('   Data: $data');
      }
    }
  }

  /// تسجيل حالة الاتصال
  static void connectivity(bool isConnected) {
    if (isConnected) {
      success('[Connectivity] متصل بالإنترنت');
    } else {
      warning('[Connectivity] غير متصل بالإنترنت');
    }
  }

  /// تسجيل حالة المزامنة
  static void sync(String message) {
    info('[Sync] $message');
  }

  /// تسجيل عملية في الخريطة
  static void map(String message) {
    info('[Map] $message');
  }

  /// تسجيل عملية في الرحلة
  static void trip(String message) {
    info('[Trip] $message');
  }

  /// تسجيل عملية في التنبيهات
  static void alert(String message) {
    info('[Alert] $message');
  }

  /// تسجيل عملية في المصادقة
  static void auth(String message) {
    info('[Auth] $message');
  }

  /// تسجيل عملية في ML
  static void ml(String message) {
    info('[ML] $message');
  }
}
