import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// أدوات التحقق من صحة المدخلات
/// يدعم الترجمة عبر تمرير BuildContext اختيارياً
class Validators {
  Validators._();

  /// التحقق من أن الحقل غير فارغ
  static String? required(String? value, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.fieldRequired
          : 'This field is required';
    }
    return null;
  }

  /// التحقق من صحة البريد الإلكتروني
  static String? email(String? value, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.invalidEmail
          : 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return context != null
          ? AppLocalizations.of(context)!.invalidEmail
          : 'Invalid email address';
    }

    return null;
  }

  /// التحقق من قوة كلمة المرور
  static String? password(String? value, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.passwordRequired
          : 'Password is required';
    }

    if (value.length < 8) {
      return context != null
          ? AppLocalizations.of(context)!.passwordMinLength
          : 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return context != null
          ? AppLocalizations.of(context)!.passwordUppercase
          : 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return context != null
          ? AppLocalizations.of(context)!.passwordNumber
          : 'Password must contain at least one number';
    }

    return null;
  }

  /// التحقق من تطابق كلمتي المرور
  static String? confirmPassword(String? value, String? password, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.confirmPasswordRequired
          : 'Please confirm your password';
    }

    if (value != password) {
      return context != null
          ? AppLocalizations.of(context)!.passwordMismatch
          : 'Passwords do not match';
    }

    return null;
  }

  /// التحقق من صحة رقم الهاتف
  static String? phoneNumber(String? value, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.invalidPhone
          : 'Phone number is required';
    }

    // إزالة المسافات والشرطات
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');

    // التحقق من أن الرقم يحتوي على أرقام فقط
    if (!RegExp(r'^[+]?[0-9]+$').hasMatch(cleaned)) {
      return context != null
          ? AppLocalizations.of(context)!.invalidPhone
          : 'Invalid phone number format';
    }

    // التحقق من الطول (بين 10 و 15 رقم)
    if (cleaned.length < 10 || cleaned.length > 15) {
      return context != null
          ? AppLocalizations.of(context)!.invalidPhone
          : 'Phone number must be between 10 and 15 digits';
    }

    return null;
  }

  /// التحقق من الحد الأدنى للطول
  static String? minLength(String? value, int length, [BuildContext? context]) {
    if (value == null || value.isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.fieldRequired
          : 'This field is required';
    }

    if (value.length < length) {
      return 'Must be at least $length characters';
    }

    return null;
  }

  /// التحقق من الحد الأقصى للطول
  static String? maxLength(String? value, int length, [BuildContext? context]) {
    if (value != null && value.length > length) {
      return 'Must not exceed $length characters';
    }

    return null;
  }

  /// التحقق من أن القيمة رقم
  static String? number(String? value, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.fieldRequired
          : 'This field is required';
    }

    if (double.tryParse(value) == null) {
      return 'Must be a number';
    }

    return null;
  }

  /// التحقق من أن القيمة رقم صحيح
  static String? integer(String? value, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.fieldRequired
          : 'This field is required';
    }

    if (int.tryParse(value) == null) {
      return 'Must be an integer';
    }

    return null;
  }

  /// التحقق من أن الرقم ضمن نطاق محدد
  static String? range(
    String? value,
    double min,
    double max, [
    BuildContext? context,
  ]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.fieldRequired
          : 'This field is required';
    }

    final numValue = double.tryParse(value);
    if (numValue == null) {
      return 'Must be a number';
    }

    if (numValue < min || numValue > max) {
      return 'Must be between $min and $max';
    }

    return null;
  }

  /// حساب قوة كلمة المرور (0-4)
  static int passwordStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // الطول
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;

    // أحرف كبيرة
    if (password.contains(RegExp(r'[A-Z]'))) strength++;

    // أرقام
    if (password.contains(RegExp(r'[0-9]'))) strength++;

    // رموز خاصة
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    // الحد الأقصى 4
    return strength > 4 ? 4 : strength;
  }

  /// دمج عدة validators
  static String? combine(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) return result;
    }
    return null;
  }

  /// التحقق من صحة URL
  static String? url(String? value, [BuildContext? context]) {
    if (value == null || value.trim().isEmpty) {
      return context != null
          ? AppLocalizations.of(context)!.fieldRequired
          : 'URL is required';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value.trim())) {
      return 'Invalid URL';
    }

    return null;
  }

  /// التحقق من تطابق النمط (Regex)
  static String? pattern(String? value, String pattern, String message) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    if (!RegExp(pattern).hasMatch(value)) {
      return message;
    }

    return null;
  }
}
