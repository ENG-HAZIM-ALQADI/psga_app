/// أداة للتحقق من صحة وتنسيق أرقام الهواتف
class PhoneValidator {
  /// التحقق من صحة رقم الهاتف
  static bool isValid(String phone) {
    if (phone.isEmpty) return false;

    // تنظيف الرقم
    final cleaned = _clean(phone);

    // التحقق من الطول والنمط
    // يجب أن يكون بين 10-15 رقم
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    return regex.hasMatch(cleaned);
  }

  /// تنسيق رقم الهاتف
  static String format(String phone, {String defaultCountryCode = '+966'}) {
    if (phone.isEmpty) return '';

    // تنظيف الرقم
    String cleaned = _clean(phone);

    // إذا كان يبدأ بـ 0، استبدله برمز الدولة
    if (cleaned.startsWith('0')) {
      cleaned = defaultCountryCode + cleaned.substring(1);
    }

    // إذا لم يكن لديه رمز دولة، أضف الافتراضي
    if (!cleaned.startsWith('+')) {
      cleaned = defaultCountryCode + cleaned;
    }

    return cleaned;
  }

  /// تنسيق رقم للعرض (مع فواصل)
  static String formatForDisplay(String phone) {
    final formatted = format(phone);
    
    // مثال: +966 50 123 4567
    if (formatted.startsWith('+966')) {
      final number = formatted.substring(4); // إزالة +966
      if (number.length == 9) {
        return '+966 ${number.substring(0, 2)} ${number.substring(2, 5)} ${number.substring(5)}';
      }
    }

    // مثال: +1 234 567 8900
    if (formatted.startsWith('+1') && formatted.length == 12) {
      final number = formatted.substring(2);
      return '+1 ${number.substring(0, 3)} ${number.substring(3, 6)} ${number.substring(6)}';
    }

    return formatted;
  }

  /// الحصول على رمز الدولة
  static String? getCountryCode(String phone) {
    final cleaned = _clean(phone);

    if (cleaned.startsWith('+966')) return '+966'; // السعودية
    if (cleaned.startsWith('+971')) return '+971'; // الإمارات
    if (cleaned.startsWith('+965')) return '+965'; // الكويت
    if (cleaned.startsWith('+973')) return '+973'; // البحرين
    if (cleaned.startsWith('+974')) return '+974'; // قطر
    if (cleaned.startsWith('+968')) return '+968'; // عمان
    if (cleaned.startsWith('+1')) return '+1';     // أمريكا/كندا
    if (cleaned.startsWith('+44')) return '+44';   // بريطانيا
    if (cleaned.startsWith('+20')) return '+20';   // مصر
    if (cleaned.startsWith('+213')) return '+213'; // الجزائر
    if (cleaned.startsWith('+216')) return '+216'; // تونس
    if (cleaned.startsWith('+212')) return '+212'; // المغرب

    if (cleaned.startsWith('+')) {
      // محاولة استخراج رمز الدولة (1-4 أرقام)
      for (int i = 2; i <= 5 && i <= cleaned.length; i++) {
        final code = cleaned.substring(0, i);
        if (RegExp(r'^\+[0-9]{1,4}$').hasMatch(code)) {
          return code;
        }
      }
    }

    return null;
  }

  /// الحصول على اسم الدولة
  static String? getCountryName(String phone) {
    final code = getCountryCode(phone);

    switch (code) {
      case '+966':
        return 'السعودية';
      case '+971':
        return 'الإمارات';
      case '+965':
        return 'الكويت';
      case '+973':
        return 'البحرين';
      case '+974':
        return 'قطر';
      case '+968':
        return 'عمان';
      case '+1':
        return 'أمريكا/كندا';
      case '+44':
        return 'بريطانيا';
      case '+20':
        return 'مصر';
      case '+213':
        return 'الجزائر';
      case '+216':
        return 'تونس';
      case '+212':
        return 'المغرب';
      default:
        return null;
    }
  }

  /// مقارنة رقمين (بعد التنسيق)
  static bool areEqual(String phone1, String phone2) {
    if (phone1.isEmpty || phone2.isEmpty) return false;

    final formatted1 = format(phone1);
    final formatted2 = format(phone2);

    return formatted1 == formatted2;
  }

  /// التحقق من رقم سعودي
  static bool isSaudiNumber(String phone) {
    final cleaned = _clean(phone);
    return cleaned.startsWith('+966') || cleaned.startsWith('966');
  }

  /// استخراج الرقم بدون رمز الدولة
  static String getNumberWithoutCountryCode(String phone) {
    final formatted = format(phone);
    final code = getCountryCode(formatted);

    if (code != null) {
      return formatted.substring(code.length);
    }

    return formatted;
  }

  /// تنظيف رقم الهاتف (إزالة كل شيء ما عدا + والأرقام)
  static String _clean(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// رسائل التحقق
  static String? validate(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }

    final cleaned = _clean(phone);

    if (cleaned.length < 10) {
      return 'رقم الهاتف قصير جداً';
    }

    if (cleaned.length > 15) {
      return 'رقم الهاتف طويل جداً';
    }

    if (!isValid(phone)) {
      return 'رقم الهاتف غير صحيح';
    }

    return null; // صالح
  }

  /// التحقق مع رمز دولة محدد
  static bool isValidForCountry(String phone, String countryCode) {
    if (!isValid(phone)) return false;

    final formatted = format(phone);
    return formatted.startsWith(countryCode);
  }
}
