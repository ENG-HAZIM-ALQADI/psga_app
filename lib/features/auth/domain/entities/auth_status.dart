/// حالة المصادقة
enum AuthStatus {
  /// لم يتم التحقق بعد
  initial,

  /// مصادق (مسجل دخول)
  authenticated,

  /// غير مصادق (غير مسجل دخول)
  unauthenticated,
}
