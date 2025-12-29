import 'package:equatable/equatable.dart';
import 'location_entity.dart';
import 'deviation_entity.dart';
import 'route_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 TripStatus - شرح حالات الرحلة للمبتدئين
/// ═══════════════════════════════════════════════════════════════════════════
/// الـ Enum هو طريقة لتعريف قائمة ثابتة من الاختيارات.
/// نستخدمه هنا لتمثيل "دورة حياة" الرحلة من البداية للنهاية.
enum TripStatus {
  pending,    // الرحلة تم إنشاؤها ولكن لم تبدأ الحركة بعد.
  active,     // المستخدم يتحرك حالياً والـ GPS يسجل موقعه.
  paused,     // المستخدم أوقف الرحلة مؤقتاً (مثلاً للاستراحة)، التتبع متوقف.
  completed,  // وصل المستخدم لوجهته بنجاح وتم إغلاق الرحلة.
  cancelled,  // المستخدم قرر إلغاء الرحلة لسبب ما.
  emergency,  // حدث طارئ أو خطر أدى لتحويل حالة الرحلة لاستغاثة.
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🏛️ TripEntity - الكيان الرئيسي للرحلة (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ❓ ما هو الـ Entity؟
/// هو "قلب" البيانات في التطبيق. تخيل أنه "موديل" نقي جداً لا يعرف شيئاً عن 
/// قواعد البيانات أو الإنترنت. هو فقط يصف "ما هي الرحلة" في عالمنا.
///
/// 💡 لماذا نستخدمه؟
/// لنفصل بين "منطق الأعمال" وبين "تكنولوجيا الحفظ". إذا قررنا مستقبلاً تغيير 
/// Firebase واستخدام MySQL، فهذا الملف لن يتغير أبداً!
///
/// 🛡️ Equatable:
/// نستخدمه لنجعل دارت تفهم أن رحلتين متساويتان إذا كان لهما نفس الـ ID، 
/// بدلاً من مقارنة مكانهم في ذاكرة الرام.
class TripEntity extends Equatable {
  final String id;                // رقم مميز فريد لكل رحلة (مثل رقم الهوية).
  final String userId;            // صاحب هذه الرحلة.
  final String routeId;           // المسار المخطط الذي يتبعه المستخدم.
  final String routeName;         // اسم المسار (للإظهار في العناوين).
  final TripStatus status;        // حالة الرحلة (نشطة، متوقفة، إلخ).
  final DateTime startTime;       // اللحظة الدقيقة التي ضغط فيها المستخدم "بدء".
  final DateTime? endTime;        // اللحظة التي انتهت فيها الرحلة (null لو لم تنتهِ).
  final LocationEntity startLocation; // إحداثيات نقطة البداية الحقيقية.
  final LocationEntity? endLocation;   // إحداثيات نقطة النهاية الحقيقية.
  final LocationEntity? currentLocation; // آخر مكان رصده الـ GPS للمستخدم.
  
  // سجل كامل لكل خطوة خطاها المستخدم (نقاط الخريطة) لرسم الخط لاحقاً.
  final List<LocationEntity> locationHistory; 
  
  // قائمة بأي مرة خرج فيها المستخدم عن المسار المسموح به.
  final List<DeviationEntity> deviations;     
  
  final int alertsTriggered;      // كم مرة أطلق التطبيق صافرة إنذار؟
  final double totalDistance;     // كم كيلومتر قطع المستخدم حتى الآن؟
  final double averageSpeed;      // متوسط سرعة المشي أو القيادة (كم/ساعة).
  final String? notes;            // أي كلام يحب المستخدم كتابته عن الرحلة.
  final RouteEntity? route;       // بيانات المسار الكاملة (الخريطة المخططة).

  const TripEntity({
    required this.id,
    required this.userId,
    required this.routeId,
    required this.routeName,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.startLocation,
    this.endLocation,
    this.currentLocation,
    this.locationHistory = const [],
    this.deviations = const [],
    this.alertsTriggered = 0,
    this.totalDistance = 0.0,
    this.averageSpeed = 0.0,
    this.notes,
    this.route,
  });

  /// 🔹 حساب مدة الرحلة (الفرق بين وقت البدء والنهاية)
  Duration? get duration => endTime?.difference(startTime);

  /// 🔹 دوال مساعدة للفحص السريع لحالة الرحلة (تسهل العمل في الواجهات)
  bool get isActive => status == TripStatus.active;
  bool get isPaused => status == TripStatus.paused;
  bool get isCompleted => status == TripStatus.completed;
  bool get isEmergency => status == TripStatus.emergency;

  /// 🔹 دالة الـ CopyWith (مهمة جداً للمبتدئين)
  /// في البرمجة الوظيفية، نحن لا نغير الكائن نفسه، بل ننشئ "نسخة جديدة" منه 
  /// مع تعديل الحقول التي نريدها فقط. هذا يمنع الأخطاء غير المتوقعة (Bugs).
  TripEntity copyWith({
    String? id,
    String? userId,
    String? routeId,
    String? routeName,
    TripStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    LocationEntity? startLocation,
    LocationEntity? endLocation,
    LocationEntity? currentLocation,
    List<LocationEntity>? locationHistory,
    List<DeviationEntity>? deviations,
    int? alertsTriggered,
    double? totalDistance,
    double? averageSpeed,
    String? notes,
    RouteEntity? route,
  }) {
    return TripEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      currentLocation: currentLocation ?? this.currentLocation,
      locationHistory: locationHistory ?? this.locationHistory,
      deviations: deviations ?? this.deviations,
      alertsTriggered: alertsTriggered ?? this.alertsTriggered,
      totalDistance: totalDistance ?? this.totalDistance,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      notes: notes ?? this.notes,
      route: route ?? this.route,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, routeId, routeName, status, startTime, endTime,
        startLocation, endLocation, currentLocation, locationHistory,
        deviations, alertsTriggered, totalDistance, averageSpeed, notes, route,
      ];
}
