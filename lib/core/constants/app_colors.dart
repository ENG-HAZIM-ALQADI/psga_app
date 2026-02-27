import 'package:flutter/material.dart';

/// ألوان التطبيق الأساسية
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════
  // ألوان التصميم الجديد (Dark Theme - GitHub Style)
  // ══════════════════════════════════════════════════════════
  
  // الخلفيات الداكنة
  static const Color darkBg = Color(0xFF0D1117);        // الخلفية الرئيسية الداكنة
  static const Color darkCard = Color(0xFF161B22);      // خلفية البطاقات الداكنة
  static const Color darkBorder = Color(0xFF30363D);    // الحدود الداكنة
  static const Color darkShimmer = Color(0xFF21262D);   // لون التحميل المتدرج
  
  // الألوان الأساسية الجديدة
  static const Color blue = Color(0xFF1F6FEB);          // أزرق رئيسي
  static const Color green = Color(0xFF238636);         // أخضر للنجاح
  static const Color gold = Color(0xFFE3B341);          // ذهبي للتحذير
  static const Color red = Color(0xFFDA3633);           // أحمر للخطر
  
  // النصوص الداكنة
  static const Color darkTextPrimary = Color(0xFFE6EDF3);   // نص رئيسي فاتح
  static const Color darkTextSecondary = Color(0xFF8B949E); // نص ثانوي رمادي
  static const Color darkTextMuted = Color(0xFF484F58);     // نص باهت

  // ══════════════════════════════════════════════════════════
  // الألوان الأساسية القديمة (للتوافق مع الثيم الفاتح)
  // ══════════════════════════════════════════════════════════
  
  static const Color primary = Color(0xFF1F6FEB);       // تحديث للأزرق الجديد
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color primaryDark = Color(0xFF0D47A1);

  static const Color accent = Color(0xFFE3B341);        // تحديث للذهبي الجديد
  static const Color accentLight = Color(0xFFFFD54F);
  static const Color accentDark = Color(0xFFB8860B);

  // الألوان الدلالية
  static const Color success = Color(0xFF238636);       // تحديث للأخضر الجديد
  static const Color successLight = Color(0xFF3FB950);
  static const Color successDark = Color(0xFF1A7F37);

  static const Color warning = Color(0xFFE3B341);       // استخدام الذهبي للتحذير
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color warningDark = Color(0xFFB8860B);

  static const Color error = Color(0xFFDA3633);         // تحديث للأحمر الجديد
  static const Color errorLight = Color(0xFFFF6B68);
  static const Color errorDark = Color(0xFFB62324);

  static const Color info = Color(0xFF1F6FEB);          // استخدام الأزرق للمعلومات
  static const Color infoLight = Color(0xFF58A6FF);
  static const Color infoDark = Color(0xFF0D47A1);

  // الألوان الحيادية
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF8B949E);
  static const Color greyLight = Color(0xFFD0D7DE);
  static const Color greyDark = Color(0xFF484F58);

  // الخلفيات
  static const Color background = Color(0xFFF6F8FA);         // فاتح
  static const Color backgroundDark = Color(0xFF0D1117);     // داكن
  static const Color surface = Color(0xFFFFFFFF);            // فاتح
  static const Color surfaceDark = Color(0xFF161B22);        // داكن

  // النصوص
  static const Color textPrimary = Color(0xFF1F2328);
  static const Color textSecondary = Color(0xFF656D76);
  static const Color textDisabled = Color(0xFF8C959F);
  static const Color textPrimaryDark = Color(0xFFE6EDF3);
  static const Color textSecondaryDark = Color(0xFF8B949E);

  // الحدود
  static const Color border = Color(0xFFD0D7DE);
  static const Color borderDark = Color(0xFF30363D);

  // الظلال
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);

  // ألوان خاصة بالتطبيق
  static const Color sosRed = Color(0xFFDA3633);
  static const Color deviationOrange = Color(0xFFE3B341);
  static const Color routeBlue = Color(0xFF1F6FEB);
  static const Color activeGreen = Color(0xFF238636);

  // ألوان الخريطة
  static const Color mapStartMarker = Color(0xFF238636);      // أخضر
  static const Color mapEndMarker = Color(0xFFDA3633);        // أحمر
  static const Color mapWaypointMarker = Color(0xFFE3B341);   // ذهبي
  static const Color mapRouteLine = Color(0xFF1F6FEB);        // أزرق
  static const Color mapActualPathLine = Color(0xFF8250DF);   // بنفسجي
  static const Color mapDeviationMarker = Color(0xFFDA3633);  // أحمر

  // الشفافيات
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  // التدرجات
  static LinearGradient primaryGradient = const LinearGradient(
    colors: [blue, Color(0xFF58A6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient accentGradient = const LinearGradient(
    colors: [gold, Color(0xFFFFD54F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient successGradient = const LinearGradient(
    colors: [green, Color(0xFF3FB950)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient errorGradient = const LinearGradient(
    colors: [red, Color(0xFFFF6B68)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
