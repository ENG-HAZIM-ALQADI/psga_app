import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:psga_app/core/utils/logger.dart';

/// Cubit لإدارة لغة التطبيق
class LocaleCubit extends Cubit<Locale> {
  static const String _boxName = 'app_settings';
  static const String _localeKey = 'app_locale';

  /// اللغة الافتراضية: العربية
  LocaleCubit() : super(const Locale('ar')) {
    _loadLocale();
  }

  /// تحميل اللغة المحفوظة من Hive
  Future<void> _loadLocale() async {
    try {
      final box = await Hive.openBox(_boxName);
      final savedLocale = box.get(_localeKey, defaultValue: 'ar') as String;

      AppLogger.info('[LocaleCubit] تحميل اللغة المحفوظة: $savedLocale');
      emit(Locale(savedLocale));
    } catch (e) {
      AppLogger.error('[LocaleCubit] خطأ في تحميل اللغة', e);
      emit(const Locale('ar'));
    }
  }

  /// تغيير اللغة وحفظها
  Future<void> setLocale(Locale locale) async {
    try {
      AppLogger.info('[LocaleCubit] تغيير اللغة إلى: ${locale.languageCode}');

      final box = await Hive.openBox(_boxName);
      await box.put(_localeKey, locale.languageCode);

      emit(locale);

      AppLogger.success('[LocaleCubit] تم حفظ اللغة بنجاح: ${locale.languageCode}');
    } catch (e) {
      AppLogger.error('[LocaleCubit] خطأ في حفظ اللغة', e);
    }
  }

  /// هل اللغة الحالية عربية؟
  bool get isArabic => state.languageCode == 'ar';

  /// اتجاه النص بناءً على اللغة
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;
}
