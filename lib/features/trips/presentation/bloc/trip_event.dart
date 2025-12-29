import 'package:equatable/equatable.dart';
import '../../domain/entities/location_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎯 TripEvent - أحداث الرحلات (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// تعريف جميع الأحداث (Events) التي قد يفعلها المستخدم أو النظام أثناء الرحلة
/// 
/// ما هي الأحداث؟
/// → أي شيء يحدث في التطبيق يحتاج معالجة من قبل TripBloc
/// مثل: "المستخدم ضغط ابدأ الرحلة" أو "GPS حدث الموقع"
///
/// كل حدث يمثل إجراء محدد:
/// - StartTrip: بدء رحلة جديدة على مسار
/// - EndTrip: إنهاء رحلة (الوصول للوجهة)
/// - PauseTrip: توقف مؤقت (للراحة)
/// - ResumeTrip: استئناف الرحلة
/// - CancelTrip: إلغاء الرحلة
/// - UpdateLocation: تحديث GPS الموقع
/// - LoadTripHistory: تحميل السجل السابق
/// - LoadActiveTrip: تحميل الرحلة النشطة الحالية
///
/// الفائدة من استخدام Events:
/// ✅ فصل المنطق عن الواجهة
/// ✅ كل حدث يحمل البيانات المطلوبة فقط
/// ✅ سهل الاختبار والتتبع

abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🚗 StartTrip Event - بدء رحلة جديدة
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// متى يُستدعى؟
/// المستخدم اختار مسار وضغط "ابدأ الرحلة"
///
/// البيانات المطلوبة:
/// - routeId: معرف المسار الذي ستتم الرحلة عليه
/// - userId: معرف المستخدم (لربط الرحلة بحسابه)
/// - startLocation: إحداثيات نقطة البداية (GPS)
///
/// مثال الاستخدام:
/// ```
/// context.read<TripBloc>().add(StartTrip(
///   routeId: 'route_123',
///   userId: 'user_456',
///   startLocation: LocationEntity(latitude: 31.5, longitude: 74.3),
/// ));
/// ```

class StartTrip extends TripEvent {
  final String routeId;
  final String userId;
  final LocationEntity startLocation;

  const StartTrip({
    required this.routeId,
    required this.userId,
    required this.startLocation,
  });

  @override
  List<Object?> get props => [routeId, userId, startLocation];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🏁 EndTrip Event - إنهاء الرحلة
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// المستخدم وصل للوجهة وضغط "أنهِ الرحلة"
///
/// البيانات المطلوبة:
/// - tripId: معرف الرحلة الجارية
/// - endLocation: إحداثيات نقطة النهاية (GPS)
///
/// ما يحدث بعدها؟
/// TripBloc سيحسب: الزمن الكلي، المسافة، السرعة
/// ثم يحفظ الرحلة في Hive و Firebase

class EndTrip extends TripEvent {
  final String tripId;
  final LocationEntity endLocation;

  const EndTrip({
    required this.tripId,
    required this.endLocation,
  });

  @override
  List<Object?> get props => [tripId, endLocation];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ⏸️ PauseTrip Event - توقف الرحلة مؤقتاً
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// المستخدم يريد راحة أو إيقاف الرحلة مؤقتاً (دون إلغائها نهائياً)
///
/// البيانات المطلوبة:
/// - tripId: معرف الرحلة المراد إيقافها
///
/// النتيجة:
/// - تتوقف عملية تتبع الموقع
/// - يتوقف حساب الزمن المنقضي
/// - المستخدم يرى خيار "استأنف الرحلة"

class PauseTrip extends TripEvent {
  final String tripId;

  const PauseTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ▶️ ResumeTrip Event - استئناف الرحلة
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// المستخدم انتهى من الراحة وضغط "استأنف الرحلة"
///
/// البيانات المطلوبة:
/// - tripId: معرف الرحلة المُوقوفة
///
/// النتيجة:
/// - استئناف تتبع الموقع
/// - استئناف حساب الزمن
/// - عودة الرحلة للحالة النشطة

class ResumeTrip extends TripEvent {
  final String tripId;

  const ResumeTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ❌ CancelTrip Event - إلغاء الرحلة
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// المستخدم أراد إلغاء الرحلة نهائياً (تغيير خطط أو طارئ)
///
/// البيانات المطلوبة:
/// - tripId: معرف الرحلة المراد إلغاؤها
///
/// ملاحظة مهمة:
/// الرحلة ستُحذف وتبقى محفوظة فقط إذا كانت بحالة "مكتملة"
/// بدلاً من ذلك، الرحلات المرفوضة لن تظهر في السجل

class CancelTrip extends TripEvent {
  final String tripId;

  const CancelTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📍 UpdateLocation Event - تحديث موقع الرحلة
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// كل ثانية تقريباً، GPS يرسل إحداثيات موقع المستخدم الجديدة
///
/// البيانات المطلوبة:
/// - tripId: معرف الرحلة الجارية
/// - location: الموقع الحالي من GPS (الموقع الفعلي)
/// - expectedLocation: موقع النقطة المتوقعة على المسار (اختياري)
///
/// ما يحدث:
/// 1️⃣ حساب المسافة المقطوعة الجديدة
/// 2️⃣ كشف الانحراف عن المسار (إذا كان الموقع بعيد عن المسار)
/// 3️⃣ إذا اُكتُشِف انحراف كبير → emit(DeviationDetected)
///
/// ملاحظة الأداء:
/// ⚠️ هذا الحدث قد يُستدعى مئات المرات!
/// لذا يجب أن يكون معالجه سريع جداً

class UpdateLocation extends TripEvent {
  final String tripId;
  final LocationEntity location;
  final LocationEntity? expectedLocation;

  const UpdateLocation({
    required this.tripId,
    required this.location,
    this.expectedLocation,
  });

  @override
  List<Object?> get props => [tripId, location, expectedLocation];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📜 LoadTripHistory Event - تحميل سجل الرحلات السابقة
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// المستخدم فتح شاشة "السجل" (Trip History)
///
/// البيانات المطلوبة:
/// - userId: معرف المستخدم (لجلب رحلاته فقط)
/// - limit: عدد الرحلات المطلوبة (مثل: 20 رحلة آخيرة) - اختياري
/// - from: من تاريخ (لتصفية بنطاق زمني) - اختياري
/// - to: إلى تاريخ - اختياري
///
/// الترتيب:
/// الرحلات ستُرجع مرتبة من الأحدث للأقدم
///
/// مثال:
/// ```
/// LoadTripHistory(
///   userId: 'user_123',
///   limit: 20,  // آخر 20 رحلة
///   from: DateTime(2024, 1, 1),
///   to: DateTime(2024, 12, 31),
/// )
/// ```

class LoadTripHistory extends TripEvent {
  final String userId;
  final int? limit;
  final DateTime? from;
  final DateTime? to;

  const LoadTripHistory({
    required this.userId,
    this.limit,
    this.from,
    this.to,
  });

  @override
  List<Object?> get props => [userId, limit, from, to];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔄 LoadActiveTrip Event - تحميل الرحلة النشطة الحالية
/// ═══════════════════════════════════════════════════════════════════════════
///
/// متى يُستدعى؟
/// 1️⃣ عند فتح التطبيق (للتحقق: هل هناك رحلة نشطة من قبل؟)
/// 2️⃣ عند العودة من خلفية التطبيق
/// 3️⃣ عند تحديث الواجهة
///
/// البيانات المطلوبة:
/// - userId: معرف المستخدم
///
/// السيناريوهات المحتملة:
/// 1️⃣ لا توجد رحلة نشطة
///    → emit(NoActiveTrip)
///    → الواجهة تعرض: "لا توجد رحلة جارية"
/// 
/// 2️⃣ توجد رحلة نشطة
///    → emit(TripActive(trip))
///    → الواجهة تعرض شاشة الرحلة مع الخريطة
/// 
/// 3️⃣ توجد رحلة موقوفة مؤقتاً
///    → emit(TripPaused(trip))
///    → الواجهة تعرض: "رحلة موقوفة، تريد الاستئناف؟"

class LoadActiveTrip extends TripEvent {
  final String userId;

  const LoadActiveTrip(this.userId);

  @override
  List<Object?> get props => [userId];
}
