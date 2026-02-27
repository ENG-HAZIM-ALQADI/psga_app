import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:psga_app/core/utils/logger.dart';

/// حالات الثيم
enum ThemeState {
  light,
  dark,
  system, // تتبع إعدادات النظام
}

/// Cubit لإدارة الثيم
class ThemeCubit extends Cubit<ThemeState> {
  static const String _boxName = 'app_settings';
  static const String _themeKey = 'theme_mode';

  ThemeCubit() : super(ThemeState.dark) {
    _loadTheme();
  }

  /// تحميل الثيم المحفوظ
  Future<void> _loadTheme() async {
    try {
      final box = await Hive.openBox(_boxName);
      final savedTheme = box.get(_themeKey, defaultValue: 'dark');
      
      AppLogger.info('[ThemeCubit] تحميل الثيم المحفوظ: $savedTheme');
      
      switch (savedTheme) {
        case 'light':
          emit(ThemeState.light);
          break;
        case 'dark':
          emit(ThemeState.dark);
          break;
        case 'system':
          emit(ThemeState.system);
          break;
        default:
          emit(ThemeState.dark);
      }
    } catch (e) {
      AppLogger.error('[ThemeCubit] خطأ في تحميل الثيم', e);
      emit(ThemeState.dark);
    }
  }

  /// تغيير الثيم
  Future<void> setTheme(ThemeState theme) async {
    try {
      AppLogger.info('[ThemeCubit] تغيير الثيم إلى: $theme');
      
      final box = await Hive.openBox(_boxName);
      await box.put(_themeKey, theme.name);
      
      emit(theme);
      
      AppLogger.success('[ThemeCubit] تم حفظ الثيم بنجاح');
    } catch (e) {
      AppLogger.error('[ThemeCubit] خطأ في حفظ الثيم', e);
    }
  }

  /// الحصول على ThemeMode للاستخدام في MaterialApp
  ThemeMode get themeMode {
    switch (state) {
      case ThemeState.light:
        return ThemeMode.light;
      case ThemeState.dark:
        return ThemeMode.dark;
      case ThemeState.system:
        return ThemeMode.system;
    }
  }

  /// هل الثيم الحالي داكن؟ (للاستخدام مع system)
  bool isDark(BuildContext context) {
    if (state == ThemeState.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return state == ThemeState.dark;
  }
}
