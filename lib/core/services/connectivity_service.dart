import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:psga_app/core/utils/logger.dart';

/// خدمة مراقبة الاتصال بالإنترنت
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _hasRealInternet = false;
  
  final List<VoidCallback> _onConnectedCallbacks = [];
  final List<VoidCallback> _onDisconnectedCallbacks = [];
  
  Timer? _internetCheckTimer;

  /// تهيئة الخدمة
  Future<void> init() async {
    if (_isInitialized) {
      AppLogger.warning('[ConnectivityService] الخدمة مُهيأة بالفعل');
      return;
    }

    try {
      AppLogger.info('[ConnectivityService] جاري تهيئة خدمة الاتصال');

      // التحقق من الحالة الحالية
      final result = await _connectivity.checkConnectivity();
      _isConnected = _isConnectedResult(result);
      
      // فحص حقيقي للإنترنت
      if (_isConnected) {
        _hasRealInternet = await _checkRealInternet();
        _isConnected = _hasRealInternet;
      }
      
      AppLogger.info('[ConnectivityService] الحالة الحالية: ${_isConnected ? "متصل" : "غير متصل"}');

      // الاستماع للتغييرات
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          AppLogger.error('[ConnectivityService] خطأ في مراقبة الاتصال', error);
        },
      );

      // بدء فحص دوري للإنترنت (كل 30 ثانية)
      _startPeriodicInternetCheck();

      _isInitialized = true;
      AppLogger.success('[ConnectivityService] تم تهيئة خدمة الاتصال بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[ConnectivityService] فشل تهيئة خدمة الاتصال', e, stackTrace);
      rethrow;
    }
  }

  /// معالجة تغيير الاتصال
  void _handleConnectivityChange(ConnectivityResult result) async {
    final wasConnected = _isConnected;
    final hasNetwork = _isConnectedResult(result);
    
    // إذا كان هناك network، نفحص الإنترنت الحقيقي
    if (hasNetwork) {
      _hasRealInternet = await _checkRealInternet();
      _isConnected = _hasRealInternet;
    } else {
      _isConnected = false;
      _hasRealInternet = false;
    }

    AppLogger.info('[ConnectivityService] تغيير الاتصال: ${_isConnected ? "متصل" : "غير متصل"}');
    
    // إرسال التحديث للمستمعين
    _connectionController.add(_isConnected);

    // تنفيذ Callbacks
    if (_isConnected && !wasConnected) {
      // اتصل من جديد
      AppLogger.success('[ConnectivityService] ✅ تم الاتصال بالإنترنت');
      _executeCallbacks(_onConnectedCallbacks);
    } else if (!_isConnected && wasConnected) {
      // انقطع الاتصال
      AppLogger.warning('[ConnectivityService] ⚠️ انقطع الاتصال بالإنترنت');
      _executeCallbacks(_onDisconnectedCallbacks);
    }
  }

  /// التحقق من نتيجة الاتصال
  bool _isConnectedResult(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  /// فحص حقيقي للإنترنت (ping google.com)
  Future<bool> _checkRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        AppLogger.info('[ConnectivityService] ✅ الإنترنت متاح (ping successful)');
        return true;
      }
      
      AppLogger.warning('[ConnectivityService] ⚠️ لا يوجد إنترنت فعلي (ping failed)');
      return false;
    } catch (e) {
      AppLogger.warning('[ConnectivityService] ⚠️ فشل فحص الإنترنت: $e');
      return false;
    }
  }

  /// بدء الفحص الدوري للإنترنت
  void _startPeriodicInternetCheck() {
    _internetCheckTimer?.cancel();
    
    _internetCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (_isConnected) {
          final hasInternet = await _checkRealInternet();
          
          // إذا تغيرت الحالة
          if (hasInternet != _hasRealInternet) {
            _hasRealInternet = hasInternet;
            final wasConnected = _isConnected;
            _isConnected = hasInternet;
            
            _connectionController.add(_isConnected);
            
            if (_isConnected && !wasConnected) {
              _executeCallbacks(_onConnectedCallbacks);
            } else if (!_isConnected && wasConnected) {
              _executeCallbacks(_onDisconnectedCallbacks);
            }
          }
        }
      },
    );
  }

  /// تنفيذ Callbacks
  void _executeCallbacks(List<VoidCallback> callbacks) {
    for (final callback in callbacks) {
      try {
        callback();
      } catch (e) {
        AppLogger.error('[ConnectivityService] خطأ في تنفيذ callback', e);
      }
    }
  }

  // ==================== Public API ====================

  /// هل الجهاز متصل بالإنترنت؟
  bool get isConnected => _isConnected;

  /// Stream للاستماع لتغييرات الاتصال
  Stream<bool> get connectionStream => _connectionController.stream;

  /// التحقق من الاتصال الآن
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasNetwork = _isConnectedResult(result);
      
      if (hasNetwork) {
        _hasRealInternet = await _checkRealInternet();
        _isConnected = _hasRealInternet;
      } else {
        _isConnected = false;
        _hasRealInternet = false;
      }
      
      AppLogger.info('[ConnectivityService] فحص الاتصال: ${_isConnected ? "متصل" : "غير متصل"}');
      return _isConnected;
    } catch (e) {
      AppLogger.error('[ConnectivityService] فشل فحص الاتصال', e);
      return false;
    }
  }

  /// فحص سريع للإنترنت (بدون تحديث الحالة)
  Future<bool> quickInternetCheck() async {
    try {
      return await _checkRealInternet();
    } catch (e) {
      return false;
    }
  }

  /// الحصول على نوع الاتصال
  Future<ConnectivityResult> getConnectionType() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result;
    } catch (e) {
      AppLogger.error('[ConnectivityService] فشل الحصول على نوع الاتصال', e);
      return ConnectivityResult.none;
    }
  }

  /// هل متصل بـ WiFi؟
  Future<bool> isWifi() async {
    try {
      final type = await getConnectionType();
      return type == ConnectivityResult.wifi;
    } catch (e) {
      AppLogger.error('[ConnectivityService] فشل التحقق من WiFi', e);
      return false;
    }
  }

  /// هل متصل بـ Mobile Data؟
  Future<bool> isMobile() async {
    try {
      final type = await getConnectionType();
      return type == ConnectivityResult.mobile;
    } catch (e) {
      AppLogger.error('[ConnectivityService] فشل التحقق من Mobile', e);
      return false;
    }
  }

  // ==================== Callbacks ====================

  /// تسجيل callback عند الاتصال
  void onConnected(VoidCallback callback) {
    _onConnectedCallbacks.add(callback);
    AppLogger.info('[ConnectivityService] تم تسجيل onConnected callback');
  }

  /// تسجيل callback عند انقطاع الاتصال
  void onDisconnected(VoidCallback callback) {
    _onDisconnectedCallbacks.add(callback);
    AppLogger.info('[ConnectivityService] تم تسجيل onDisconnected callback');
  }

  /// إزالة callback
  void removeConnectedCallback(VoidCallback callback) {
    _onConnectedCallbacks.remove(callback);
  }

  /// إزالة callback
  void removeDisconnectedCallback(VoidCallback callback) {
    _onDisconnectedCallbacks.remove(callback);
  }

  /// مسح جميع Callbacks
  void clearCallbacks() {
    _onConnectedCallbacks.clear();
    _onDisconnectedCallbacks.clear();
    AppLogger.info('[ConnectivityService] تم مسح جميع callbacks');
  }

  // ==================== Lifecycle ====================

  /// إيقاف الخدمة
  Future<void> dispose() async {
    try {
      AppLogger.info('[ConnectivityService] جاري إيقاف خدمة الاتصال');
      
      await _connectivitySubscription?.cancel();
      await _connectionController.close();
      
      _internetCheckTimer?.cancel();
      _internetCheckTimer = null;
      
      clearCallbacks();
      
      _isInitialized = false;
      
      AppLogger.success('[ConnectivityService] تم إيقاف خدمة الاتصال');
    } catch (e) {
      AppLogger.error('[ConnectivityService] خطأ في إيقاف الخدمة', e);
    }
  }

  // ==================== Utility ====================

  /// معلومات عن الخدمة
  Map<String, dynamic> getInfo() {
    return {
      'isInitialized': _isInitialized,
      'isConnected': _isConnected,
      'hasRealInternet': _hasRealInternet,
      'onConnectedCallbacks': _onConnectedCallbacks.length,
      'onDisconnectedCallbacks': _onDisconnectedCallbacks.length,
    };
  }

  /// طباعة معلومات الخدمة
  void printInfo() {
    final info = getInfo();
    AppLogger.info('[ConnectivityService] معلومات الخدمة:');
    info.forEach((key, value) {
      AppLogger.info('  $key: $value');
    });
  }
}
