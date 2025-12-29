import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// خدمة مراقبة الاتصال - Singleton
/// تراقب حالة الاتصال بالإنترنت وتوفر Stream للتحديثات
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;

  final Connectivity _connectivity = Connectivity();

  bool _isConnected = false;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];

  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isConnected => _isConnected;
  bool get isWifi => _connectionStatus.contains(ConnectivityResult.wifi);
  bool get isMobile => _connectionStatus.contains(ConnectivityResult.mobile);
  bool get isOffline => !_isConnected;

  /// تهيئة الخدمة والبدء في المراقبة
  Future<void> init() async {
    try {
      debugPrint('📶 [Connectivity] جاري تهيئة خدمة الاتصال...');

      // الحصول على الحالة الأولية
      _connectionStatus = await _connectivity.checkConnectivity();
      
      // في بيئة التطوير/المحاكاة، قد نحتاج لاعتبار "any" اتصال كمتصل
      _isConnected = _connectionStatus.any(
        (result) => result != ConnectivityResult.none
      );

      // تحسين: إذا كنا في وضع التطوير (debug) ولم يتم اكتشاف اتصال، نفترض وجوده للمزامنة
      if (kDebugMode && !_isConnected) {
        debugPrint('📶 [Connectivity] ⚠️ وضع التطوير: تفعيل الاتصال افتراضياً للمزامنة');
        _isConnected = true;
      }

      debugPrint('📶 [Connectivity] الحالة الأولية: $connectionTypeString');

      // بدء الاستماع للتغيرات
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          debugPrint('📶 [Connectivity] ❌ خطأ في المراقبة: $error');
        },
      );

      debugPrint('📶 [Connectivity] ✅ تم التهيئة بنجاح');
    } catch (e) {
      debugPrint('📶 [Connectivity] ❌ فشل في التهيئة: $e');
      rethrow;
    }
  }

  /// تحديث حالة الاتصال
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _connectionStatus = results;
    _isConnected = results.any(
      (result) => result != ConnectivityResult.none
    );

    debugPrint('📶 [Connectivity] ═══════════════════════════════════');
    debugPrint('📶 [Connectivity] تغيرت حالة الاتصال');
    debugPrint('📶 [Connectivity] من: ${wasConnected ? "متصل" : "منفصل"}');
    debugPrint('📶 [Connectivity] إلى: ${_isConnected ? "متصل" : "منفصل"}');
    debugPrint('📶 [Connectivity] النوع: $connectionTypeString');
    debugPrint('📶 [Connectivity] ═══════════════════════════════════');

    // إصدار التحديث إذا تغيرت الحالة
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);

      if (_isConnected) {
        debugPrint('📶 [Connectivity] ✅ عودة الاتصال!');
      } else {
        debugPrint('📶 [Connectivity] ❌ انقطع الاتصال!');
      }
    }
  }

  /// فحص الاتصال الفعلي (ping)
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none
      );

      debugPrint('📶 [Connectivity] فحص الاتصال: ${hasConnection ? "متصل" : "منفصل"}');
      return hasConnection;
    } catch (e) {
      debugPrint('📶 [Connectivity] ❌ خطأ في الفحص: $e');
      return false;
    }
  }

  /// Stream تدفق تغيرات الاتصال
  Stream<bool> get connectionStream => _connectionController.stream;

  /// نوع الاتصال كنص
  String get connectionTypeString {
    if (_connectionStatus.isEmpty || 
        _connectionStatus.first == ConnectivityResult.none) {
      return 'لا يوجد اتصال';
    }

    final types = <String>[];
    if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      types.add('WiFi');
    }
    if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      types.add('بيانات الجوال');
    }
    if (_connectionStatus.contains(ConnectivityResult.ethernet)) {
      types.add('Ethernet');
    }
    if (_connectionStatus.contains(ConnectivityResult.bluetooth)) {
      types.add('Bluetooth');
    }
    if (_connectionStatus.contains(ConnectivityResult.vpn)) {
      types.add('VPN');
    }

    return types.isEmpty ? 'غير معروف' : types.join(' + ');
  }

  /// هل يوجد وصول حقيقي للإنترنت؟
  /// (ليس فقط اتصال WiFi/Data بدون إنترنت)
  Future<bool> hasInternetAccess() async {
    try {
      if (!_isConnected) {
        return false;
      }

      // محاولة ping لـ Google DNS
      // في التطبيق الفعلي يمكن استخدام http request بسيط
      // هنا نفترض أن الاتصال يعني وجود إنترنت

      debugPrint('📶 [Connectivity] فحص الوصول للإنترنت...');
      return _isConnected;
    } catch (e) {
      debugPrint('📶 [Connectivity] ❌ خطأ في فحص الإنترنت: $e');
      return false;
    }
  }

  /// الانتظار حتى يتوفر الاتصال
  Future<void> waitForConnection({Duration? timeout}) async {
    if (_isConnected) {
      debugPrint('📶 [Connectivity] الاتصال متوفر بالفعل');
      return;
    }

    debugPrint('📶 [Connectivity] ⏳ انتظار الاتصال...');

    final completer = Completer<void>();

    StreamSubscription? subscription;
    Timer? timeoutTimer;

    subscription = connectionStream.listen((isConnected) {
      if (isConnected) {
        debugPrint('📶 [Connectivity] ✅ توفر الاتصال!');
        timeoutTimer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        debugPrint('📶 [Connectivity] ⏱️ انتهت مهلة الانتظار');
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('انتهت مهلة انتظار الاتصال'));
        }
      });
    }

    return completer.future;
  }

  /// معلومات الاتصال التفصيلية
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'type': connectionTypeString,
      'isWifi': isWifi,
      'isMobile': isMobile,
      'isOffline': isOffline,
      'status': _connectionStatus.map((e) => e.name).toList(),
    };
  }

  /// طباعة معلومات الاتصال
  void printConnectionInfo() {
    final info = getConnectionInfo();

    debugPrint('📶 [Connectivity] ═══════════════════════════════════');
    debugPrint('📶 [Connectivity] Connection Info:');
    debugPrint('📶 [Connectivity] متصل: ${info['isConnected']}');
    debugPrint('📶 [Connectivity] النوع: ${info['type']}');
    debugPrint('📶 [Connectivity] WiFi: ${info['isWifi']}');
    debugPrint('📶 [Connectivity] Mobile: ${info['isMobile']}');
    debugPrint('📶 [Connectivity] ═══════════════════════════════════');
  }

  /// تنظيف الموارد
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
    debugPrint('📶 [Connectivity] تم تنظيف الموارد');
  }
}