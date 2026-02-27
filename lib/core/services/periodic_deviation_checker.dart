import 'dart:async';
import 'package:psga_app/core/services/deviation_detector.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart' as route_entity;
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// خدمة الفحص الدوري للانحراف
class PeriodicDeviationChecker {
  static final PeriodicDeviationChecker instance = PeriodicDeviationChecker._();
  PeriodicDeviationChecker._();

  Timer? _checkTimer;
  bool _isChecking = false;
  
  final DeviationDetector _detector = DeviationDetector.instance;
  
  // إعدادات الفحص
  Duration checkInterval = const Duration(seconds: 10);
  
  // Callbacks
  Function(Deviation)? onDeviationDetected;
  Function(Deviation)? onDeviationResolved;
  Function(DeviationSeverity, DeviationSeverity)? onSeverityChanged;

  /// بدء الفحص الدوري
  void startChecking({
    required route_entity.RouteEntity route,
    required Stream<Location> locationStream,
    Function(Deviation)? onDeviation,
    Function(Deviation)? onResolved,
    Function(DeviationSeverity, DeviationSeverity)? onSeverityChange,
  }) {
    if (_isChecking) {
      AppLogger.warning('[PeriodicChecker] الفحص نشط بالفعل');
      return;
    }

    AppLogger.info('[PeriodicChecker] بدء الفحص الدوري كل ${checkInterval.inSeconds}ث');
    
    _isChecking = true;
    onDeviationDetected = onDeviation;
    onDeviationResolved = onResolved;
    onSeverityChanged = onSeverityChange;

    Location? lastLocation;
    Deviation? lastDeviation;

    // الاستماع للموقع
    locationStream.listen((location) {
      lastLocation = location;
    });

    // بدء Timer للفحص الدوري
    _checkTimer = Timer.periodic(checkInterval, (timer) {
      if (lastLocation == null) {
        AppLogger.debug('[PeriodicChecker] لا يوجد موقع حالي');
        return;
      }

      _checkDeviation(
        currentLocation: lastLocation!,
        route: route,
        lastDeviation: lastDeviation,
        onUpdate: (deviation) {
          lastDeviation = deviation;
        },
      );
    });

    AppLogger.success('[PeriodicChecker] تم بدء الفحص الدوري');
  }

  /// فحص الانحراف
  void _checkDeviation({
    required Location currentLocation,
    required route_entity.RouteEntity route,
    required Function(Deviation?) onUpdate,
    Deviation? lastDeviation,
  }) {
    try {
      // كشف الانحراف
      final deviation = _detector.detectDeviation(
        currentLocation: currentLocation,
        route: route,
      );

      // حالة 1: لا يوجد انحراف الآن
      if (deviation == null) {
        // إذا كان هناك انحراف سابق، معناها تم حله
        if (lastDeviation != null && !lastDeviation.isResolved) {
          AppLogger.info('[PeriodicChecker] تم حل الانحراف');
          
          final resolved = lastDeviation.copyWith(
            isResolved: true,
            resolvedAt: DateTime.now(),
            duration: DateTime.now().difference(lastDeviation.detectedAt),
          );
          
          onDeviationResolved?.call(resolved);
          onUpdate(null);
        }
        return;
      }

      // حالة 2: يوجد انحراف جديد
      if (lastDeviation == null) {
        AppLogger.warning(
          '[PeriodicChecker] انحراف جديد: ${deviation.severity.name} - ${deviation.distanceFromRoute.toStringAsFixed(0)}م',
        );
        
        onDeviationDetected?.call(deviation);
        onUpdate(deviation);
        return;
      }

      // حالة 3: الانحراف مستمر لكن الشدة تغيرت
      if (deviation.severity != lastDeviation.severity) {
        AppLogger.warning(
          '[PeriodicChecker] تغير شدة الانحراف: ${lastDeviation.severity.name} → ${deviation.severity.name}',
        );
        
        onSeverityChanged?.call(lastDeviation.severity, deviation.severity);
        onDeviationDetected?.call(deviation); // إعادة إطلاق callback
        onUpdate(deviation);
        return;
      }

      // حالة 4: الانحراف مستمر بنفس الشدة
      AppLogger.debug(
        '[PeriodicChecker] الانحراف مستمر: ${deviation.severity.name} - ${deviation.distanceFromRoute.toStringAsFixed(0)}م',
      );
      
      onUpdate(deviation);
    } catch (e, stackTrace) {
      AppLogger.error('[PeriodicChecker] خطأ في فحص الانحراف', e, stackTrace);
    }
  }

  /// إيقاف الفحص
  void stopChecking() {
    if (!_isChecking) {
      return;
    }

    AppLogger.info('[PeriodicChecker] إيقاف الفحص الدوري');
    
    _checkTimer?.cancel();
    _checkTimer = null;
    _isChecking = false;
    
    onDeviationDetected = null;
    onDeviationResolved = null;
    onSeverityChanged = null;

    AppLogger.success('[PeriodicChecker] تم إيقاف الفحص');
  }

  /// هل الفحص نشط؟
  bool get isChecking => _isChecking;

  /// تحديث فترة الفحص
  void updateInterval(Duration newInterval) {
    checkInterval = newInterval;
    
    if (_isChecking) {
      AppLogger.info('[PeriodicChecker] تحديث فترة الفحص إلى ${newInterval.inSeconds}ث');
      // إعادة تشغيل Timer بالفترة الجديدة
      // يتطلب حفظ المعلومات وإعادة البدء
    }
  }

  /// فحص يدوي (خارج الجدول الدوري)
  Deviation? checkNow({
    required Location currentLocation,
    required route_entity.RouteEntity route,
  }) {
    return _detector.detectDeviation(
      currentLocation: currentLocation,
      route: route,
    );
  }

  /// الحصول على إحصائيات الفحص
  Map<String, dynamic> getStatistics() {
    return {
      'isChecking': _isChecking,
      'checkInterval': checkInterval.inSeconds,
      'hasCallbacks': {
        'onDeviation': onDeviationDetected != null,
        'onResolved': onDeviationResolved != null,
        'onSeverityChange': onSeverityChanged != null,
      },
    };
  }

  /// التنظيف
  void dispose() {
    stopChecking();
  }
}
