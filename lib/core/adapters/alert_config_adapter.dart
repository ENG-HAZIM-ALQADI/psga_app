import 'package:hive/hive.dart';
import '../../features/alerts/data/models/alert_config_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚙️ AlertConfigModelAdapter - المحوّل الخاص بإعدادات التنبيهات
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// 🎯 الموقع في Clean Architecture:
/// - الطبقة: Core Layer > Adapters
/// - الوظيفة: تحويل AlertConfigModel (إعدادات التنبيهات) من/إلى Binary
/// 
/// 📌 ما هو AlertConfig؟
/// AlertConfig هو "لوحة التحكم" في التنبيهات - يحدد:
/// - هل التنبيهات مفعلة أصلاً؟
/// - كم متر انحراف يستدعي تنبيه؟
/// - كم ثانية عد تنازلي قبل الإرسال؟
/// - هل نصعّد التنبيهات تلقائياً؟
/// - إعدادات الأصوات والاهتزاز
/// - أوقات الهدوء (لا تزعجني!)
/// 
/// 💡 مثال إعدادات كاملة:
/// ```
/// AlertConfigModel {
///   userId: "user_123",
///   isEnabled: true,                    // التنبيهات مفعلة
///   deviationThreshold: 300.0,          // تنبيه بعد 300 متر انحراف
///   countdownSeconds: 30,               // عد تنازلي 30 ثانية
///   autoEscalate: true,                 // تصعيد تلقائي
///   sosEnabled: true,                   // زر SOS متاح
///   sosCountdownSeconds: 10,            // SOS بعد 10 ثواني
///   inactivityTimeout: 900,             // تنبيه بعد 15 دقيقة عدم حركة
///   lowBatteryThreshold: 15,            // تنبيه عند 15% بطارية
///   quietHoursEnabled: true,            // أوقات هدوء مفعلة
///   quietHoursStart: "23:00",           // من 11 مساءً
///   quietHoursEnd: "07:00",             // إلى 7 صباحاً
///   soundEnabled: true,                 // صوت التنبيهات
///   vibrationEnabled: true              // اهتزاز التنبيهات
/// }
/// ```
/// 
/// 🔢 typeId = 8

class AlertConfigModelAdapter extends TypeAdapter<AlertConfigModel> {
  @override
  final int typeId = 8;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📖 read() - قراءة AlertConfigModel من Hive
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// 🎯 متى تُستدعى؟
  /// - عند فتح التطبيق (نحتاج نعرف الإعدادات الحالية)
  /// - عند رصد انحراف (كم متر threshold؟)
  /// - عند إرسال تنبيه (هل الأصوات مفعلة؟)
  /// - عند عرض صفحة الإعدادات
  @override
  AlertConfigModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AlertConfigModel.fromJson({
      'userId': fields[0] as String,
      
      /// Field 1: هل التنبيهات مفعلة؟
      /// - المفتاح الرئيسي: إذا false، كل شيء معطل!
      'isEnabled': fields[1] as bool,
      
      /// Field 2: حد الانحراف بالأمتار
      /// - مثال: 300.0 = تنبيه بعد 300 متر انحراف
      /// - الافتراضي: 200-500 متر
      'deviationThreshold': fields[2] as double,
      
      /// Field 3: العد التنازلي بالثواني
      /// - يعطي المستخدم فرصة لإلغاء التنبيه
      /// - مثال: 30 ثانية قبل إرسال التنبيه
      'countdownSeconds': fields[3] as int,
      
      /// Field 4: التصعيد التلقائي
      /// - إذا true: تنبيه medium يصبح high بعد فترة
      'autoEscalate': fields[4] as bool,
      
      /// Field 5: هل زر SOS متاح؟
      /// - بعض المستخدمين يفضلون إخفاءه (لمنع الضغط الخطأ!)
      'sosEnabled': fields[5] as bool,
      
      /// Field 6: عد تنازلي SOS
      /// - عادة قصير (5-10 ثواني)
      /// - يمنع الضغط الخطأ
      'sosCountdownSeconds': fields[6] as int,
      
      /// Field 7: مهلة عدم النشاط (بالثواني)
      /// - مثال: 900 = 15 دقيقة
      /// - إذا لم يتحرك المستخدم، نرسل تنبيه
      'inactivityTimeout': fields[7] as int,
      
      /// Field 8: حد البطارية المنخفضة (نسبة مئوية)
      /// - مثال: 15 = تنبيه عند 15% بطارية
      'lowBatteryThreshold': fields[8] as int,
      
      /// Field 9: هل أوقات الهدوء مفعلة؟
      /// - مفيد للنوم أو الاجتماعات
      'quietHoursEnabled': fields[9] as bool,
      
      /// Field 10: بداية أوقات الهدوء
      /// - صيغة: "HH:mm" مثل "23:00"
      'quietHoursStart': fields[10],
      
      /// Field 11: نهاية أوقات الهدوء
      /// - صيغة: "HH:mm" مثل "07:00"
      'quietHoursEnd': fields[11],
      
      /// Field 12: الصوت
      /// - هل نشغل صوت التنبيه؟
      'soundEnabled': fields[12] as bool,
      
      /// Field 13: الاهتزاز
      /// - هل نهتز عند التنبيه؟
      'vibrationEnabled': fields[13] as bool,
    });
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 💾 write() - حفظ AlertConfigModel في Hive
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// 🎯 متى تُستدعى؟
  /// - عند تغيير أي إعداد في صفحة الإعدادات
  /// - عند أول تشغيل (إنشاء الإعدادات الافتراضية)
  /// - عند استيراد إعدادات من السحابة
  @override
  void write(BinaryWriter writer, AlertConfigModel obj) {
    final json = obj.toJson();

    writer
      ..writeByte(14)  // 14 حقل
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.isEnabled)
      ..writeByte(2)
      ..write(obj.deviationThreshold)
      ..writeByte(3)
      ..write(obj.countdownSeconds)
      ..writeByte(4)
      ..write(obj.autoEscalate)
      ..writeByte(5)
      ..write(obj.sosEnabled)
      ..writeByte(6)
      ..write(obj.sosCountdownSeconds)
      ..writeByte(7)
      ..write(obj.inactivityTimeout)
      ..writeByte(8)
      ..write(obj.lowBatteryThreshold)
      ..writeByte(9)
      ..write(obj.quietHoursEnabled)
      ..writeByte(10)
      ..write(json['quietHoursStart'])
      ..writeByte(11)
      ..write(json['quietHoursEnd'])
      ..writeByte(12)
      ..write(obj.soundEnabled)
      ..writeByte(13)
      ..write(obj.vibrationEnabled);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 دليل استخدام AlertConfig:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ⚙️ إعدادات افتراضية موصى بها:
/// 
/// ```dart
/// final defaultConfig = AlertConfigModel(
///   userId: currentUser.id,
///   isEnabled: true,
///   deviationThreshold: 300.0,     // ✅ معقول للطرق الحضرية
///   countdownSeconds: 30,          // ✅ يعطي وقت كافي للإلغاء
///   autoEscalate: true,            // ✅ أمان إضافي
///   sosEnabled: true,              // ✅ ضروري!
///   sosCountdownSeconds: 10,       // ✅ قصير لكن آمن
///   inactivityTimeout: 900,        // ✅ 15 دقيقة معقولة
///   lowBatteryThreshold: 15,       // ✅ 15% وقت كافي للشحن
///   quietHoursEnabled: false,      // ⚠️ افتراضياً معطل (للأمان!)
///   quietHoursStart: "23:00",
///   quietHoursEnd: "07:00",
///   soundEnabled: true,            // ✅ صوت مهم للانتباه
///   vibrationEnabled: true,        // ✅ إضافة للصوت
/// );
/// 
/// await configBox.put('current_config', defaultConfig);
/// ```
/// 
/// 🔧 أمثلة على التخصيص:
/// 
/// 1️⃣ **المستخدم الحذر** (يريد أمان أكثر):
///    ```dart
///    deviationThreshold: 150.0,     // حساسية أعلى
///    countdownSeconds: 15,          // تنبيه سريع
///    autoEscalate: true,
///    ```
/// 
/// 2️⃣ **المستخدم المرن** (يثق بنفسه):
///    ```dart
///    deviationThreshold: 500.0,     // حساسية أقل
///    countdownSeconds: 60,          // وقت أطول للإلغاء
///    autoEscalate: false,
///    ```
/// 
/// 3️⃣ **الاستخدام الليلي**:
///    ```dart
///    quietHoursEnabled: true,
///    quietHoursStart: "22:00",
///    quietHoursEnd: "06:00",
///    soundEnabled: false,           // صامت
///    vibrationEnabled: true,        // اهتزاز فقط
///    ```
/// 
/// 🎯 كيف نستخدم AlertConfig في الكود؟
/// 
/// ```dart
/// // مثال: فحص قبل إرسال تنبيه انحراف
/// Future<void> checkDeviation(LocationModel currentLocation) async {
///   // 1. جلب الإعدادات
///   final config = configBox.get('current_config')!;
///   
///   // 2. تحقق: هل التنبيهات مفعلة؟
///   if (!config.isEnabled) return;
///   
///   // 3. تحقق: هل في أوقات الهدوء؟
///   if (config.quietHoursEnabled && isInQuietHours(config)) {
///     return;  // لا ترسل تنبيهات الآن!
///   }
///   
///   // 4. احسب الانحراف
///   final deviation = calculateDeviation(currentLocation);
///   
///   // 5. تحقق: هل تجاوز الحد؟
///   if (deviation > config.deviationThreshold) {
///     // 6. ابدأ عد تنازلي
///     showCountdown(
///       seconds: config.countdownSeconds,
///       onComplete: () {
///         // 7. أرسل التنبيه
///         sendAlert(
///           soundEnabled: config.soundEnabled,
///           vibrationEnabled: config.vibrationEnabled,
///         );
///       },
///     );
///   }
/// }
/// 
/// // مثال: فحص أوقات الهدوء
/// bool isInQuietHours(AlertConfigModel config) {
///   if (!config.quietHoursEnabled) return false;
///   
///   final now = DateTime.now();
///   final start = parseTime(config.quietHoursStart);
///   final end = parseTime(config.quietHoursEnd);
///   
///   // تعامل مع حالة عبور منتصف الليل
///   if (end.isBefore(start)) {
///     // مثال: 23:00 - 07:00
///     return now.isAfter(start) || now.isBefore(end);
///   } else {
///     // مثال: 14:00 - 16:00 (قيلولة!)
///     return now.isAfter(start) && now.isBefore(end);
///   }
/// }
/// ```
/// 
/// 💡 نصائح متقدمة:
/// 
/// 1️⃣ **Profiles** (ملفات تعريف):
///    دع المستخدم يحفظ عدة configs:
///    - "نهاري" (حساسية عالية)
///    - "ليلي" (صامت)
///    - "عمل" (أوقات هدوء محددة)
/// 
/// 2️⃣ **Smart Defaults** (افتراضيات ذكية):
///    اقترح إعدادات بناءً على:
///    - الوقت (ليل/نهار)
///    - الموقع (بيت/عمل/سفر)
///    - نمط الاستخدام (هل يخرج كثيراً؟)
/// 
/// 3️⃣ **تزامن مع السحابة**:
///    ```dart
///    // حفظ في Hive و Firebase
///    await configBox.put('current_config', newConfig);
///    await FirebaseFirestore.instance
///        .collection('users/${user.id}/settings')
///        .doc('alert_config')
///        .set(newConfig.toJson());
///    ```
/// ═══════════════════════════════════════════════════════════════════════════
