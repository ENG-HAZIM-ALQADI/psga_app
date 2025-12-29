import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static const String _tag = 'PSGA';

  static void log(String message, {String? name}) {
    final String logMessage = _formatMessage(message, name);
    if (kDebugMode) {
      developer.log(logMessage, name: _tag);
      debugPrint('[$_tag] $logMessage');
    }
  }

  static void info(String message, {String? name}) {
    final String logMessage = '🔵 INFO: ${_formatMessage(message, name)}';
    if (kDebugMode) {
      developer.log(logMessage, name: _tag);
      debugPrint('[$_tag] $logMessage');
    }
  }

  static void success(String message, {String? name}) {
    final String logMessage = '✅ SUCCESS: ${_formatMessage(message, name)}';
    if (kDebugMode) {
      developer.log(logMessage, name: _tag);
      debugPrint('[$_tag] $logMessage');
    }
  }

  static void warning(String message, {String? name}) {
    final String logMessage = '⚠️ WARNING: ${_formatMessage(message, name)}';
    if (kDebugMode) {
      developer.log(logMessage, name: _tag);
      debugPrint('[$_tag] $logMessage');
    }
  }

  static void error(String message, {String? name, Object? error, StackTrace? stackTrace}) {
    final String logMessage = '❌ ERROR: ${_formatMessage(message, name)}';
    if (kDebugMode) {
      developer.log(
        logMessage,
        name: _tag,
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('[$_tag] $logMessage');
      if (error != null) {
        debugPrint('[$_tag] Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('[$_tag] Stack trace: $stackTrace');
      }
    }
  }

  static void debug(String message, {String? name}) {
    if (kDebugMode) {
      final String logMessage = '🔍 DEBUG: ${_formatMessage(message, name)}';
      developer.log(logMessage, name: _tag);
      debugPrint('[$_tag] $logMessage');
    }
  }

  static String _formatMessage(String message, String? name) {
    if (name != null) {
      return '[$name] $message';
    }
    return message;
  }

  static void logMethodEntry(String className, String methodName) {
    debug('Entering $methodName', name: className);
  }

  static void logMethodExit(String className, String methodName) {
    debug('Exiting $methodName', name: className);
  }

  static void logApiCall(String endpoint, {String method = 'GET', Map<String, dynamic>? params}) {
    info('API Call: $method $endpoint', name: 'API');
    if (params != null && params.isNotEmpty) {
      debug('Params: $params', name: 'API');
    }
  }

  static void logApiResponse(String endpoint, int statusCode, {dynamic data}) {
    if (statusCode >= 200 && statusCode < 300) {
      success('API Response: $statusCode for $endpoint', name: 'API');
    } else {
      error('API Response: $statusCode for $endpoint', name: 'API');
    }
  }
}
