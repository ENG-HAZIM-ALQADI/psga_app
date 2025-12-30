import '../utils/logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔐 AuthService - خدمة المصادقة (Authentication Service)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🎯 الموقع في Clean Architecture:
/// - الطبقة: Core Layer > Services
/// - النوع: Singleton Service (خدمة مفردة - نسخة واحدة فقط)
/// - الوظيفة: إدارة حالة المصادقة للمستخدم الحالي
///
/// 📌 ما هي خدمة المصادقة؟
/// AuthService هي "حارس البوابة" للتطبيق:
/// - تتحقق: هل المستخدم مسجل دخول؟
/// - تحفظ: معلومات المستخدم الحالي (ID، Email)
/// - تدير: عمليات تسجيل الدخول والخروج
/// - توفر: حالة المصادقة لباقي التطبيق
///
/// 💡 لماذا Singleton؟
/// نريد نسخة واحدة فقط من AuthService في كل التطبيق:
/// - تجنب التعارضات (مستخدم واحد فقط مسجل دخول في وقت واحد)
/// - سهولة الوصول من أي مكان: `AuthService.instance`
/// - توحيد حالة المصادقة (Single Source of Truth)
///
/// 🔄 دورة حياة المصادقة:
/// 1. **App Launch**: التطبيق يفتح → checkAuthStatus()
/// 2. **Login**: المستخدم يسجل دخول → login()
/// 3. **Authenticated**: المستخدم يستخدم التطبيق → isAuthenticated = true
/// 4. **Logout**: المستخدم يسجل خروج → logout()
/// 5. **Back to Login**: العودة لشاشة تسجيل الدخول
///
/// ⚠️ ملاحظة: هذا Implementation بسيط للتطوير!
/// في الإنتاج، يجب ربطه بـ:
/// - Firebase Authentication
/// - JWT Tokens
/// - Secure Storage للـ Tokens
/// - Session Management

class AuthService {
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏗️ Singleton Pattern Implementation
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 شرح Singleton Pattern للمبتدئين:
  ///
  /// Singleton = كائن واحد فقط في كل التطبيق
  ///
  /// مثال توضيحي:
  /// تخيل أن AuthService هو "مدير الأمن" في مبنى:
  /// - لا يمكن أن يكون هناك أكثر من مدير أمن واحد!
  /// - الجميع يتعامل مع نفس المدير
  /// - المدير يعرف من دخل المبنى ومن خرج
  ///
  /// 🔧 كيف يعمل التطبيق؟
  ///
  /// 1. Constructor خاص (Private):
  ///    ```dart
  ///    AuthService._();  // لا يمكن إنشاء كائن من خارج الكلاس!
  ///    ```
  ///
  /// 2. نسخة ثابتة (Static Instance):
  ///    ```dart
  ///    static final AuthService _instance = AuthService._();
  ///    ```
  ///    ننشئ نسخة واحدة فقط عند أول استخدام
  ///
  /// 3. Getter للوصول:
  ///    ```dart
  ///    static AuthService get instance => _instance;
  ///    ```
  ///    نرجع نفس النسخة دائماً
  ///
  /// 📝 الاستخدام في الكود:
  /// ```dart
  /// // ✅ صحيح:
  /// final auth = AuthService.instance;
  ///
  /// // ❌ خطأ (لا يعمل!):
  /// final auth = AuthService();  // Constructor خاص!
  /// ```

  /// Constructor خاص - لا يمكن استدعاؤه من خارج الكلاس
  AuthService._();

  /// النسخة الوحيدة من الخدمة (الـ Singleton)
  /// - final: لا يمكن تغييرها
  /// - static: تنتمي للكلاس نفسه (ليس لكائن معين)
  static final AuthService _instance = AuthService._();

  /// Getter للوصول للنسخة الوحيدة
  /// هذا ما نستخدمه في الكود: AuthService.instance
  static AuthService get instance => _instance;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📊 حالة المصادقة (Authentication State)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// هذه المتغيرات تحفظ معلومات المستخدم الحالي

  /// هل المستخدم مسجل دخول؟
  /// - true = مسجل دخول، يمكنه استخدام التطبيق
  /// - false = غير مسجل، يجب أن يذهب لشاشة Login
  ///
  /// 💡 استخدامه في التطبيق:
  /// ```dart
  /// if (AuthService.instance.isAuthenticated) {
  ///   navigateToHome();
  /// } else {
  ///   navigateToLogin();
  /// }
  /// ```
  bool _isAuthenticated = false;

  /// معرّف المستخدم الفريد (User ID)
  /// - null = لا يوجد مستخدم مسجل دخول
  /// - String = ID من Firebase أو Backend
  ///
  /// 💡 استخدامه:
  /// ```dart
  /// final userId = AuthService.instance.userId;
  /// if (userId != null) {
  ///   // جلب بيانات المستخدم من Firestore
  ///   final user = await usersCollection.doc(userId).get();
  /// }
  /// ```
  String? _userId;

  /// بريد المستخدم الإلكتروني
  /// - null = لا يوجد مستخدم
  /// - String = الإيميل المسجل به
  ///
  /// 💡 استخدامه:
  /// ```dart
  /// Text('مرحباً، ${AuthService.instance.userEmail}')
  /// ```
  String? _userEmail;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📖 Getters - للوصول للحالة من الخارج
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🔒 لماذا Getters وليس Public Variables؟
  ///
  /// ❌ لو استخدمنا متغيرات عامة:
  /// ```dart
  /// bool isAuthenticated = false;  // أي واحد يقدر يغيرها!
  /// ```
  ///
  /// ✅ باستخدام Getters:
  /// ```dart
  /// bool get isAuthenticated => _isAuthenticated;  // للقراءة فقط!
  /// ```
  ///
  /// الفائدة: نتحكم في من يقدر يغير الحالة
  /// فقط AuthService نفسها تقدر تغير _isAuthenticated

  /// للقراءة: هل مسجل دخول؟
  bool get isAuthenticated => _isAuthenticated;

  /// للقراءة: ما هو User ID؟
  String? get userId => _userId;

  /// للقراءة: ما هو Email؟
  String? get userEmail => _userEmail;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔍 checkAuthStatus() - فحص حالة المصادقة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 متى تُستدعى؟
  /// - عند فتح التطبيق (في main.dart أو SplashScreen)
  /// - بعد عودة التطبيق من الخلفية (resume)
  /// - بعد أي عملية قد تغير حالة المصادقة
  ///
  /// 💡 ماذا تفعل؟
  /// 1. تتحقق من Token المحفوظ (في الإنتاج)
  /// 2. تتحقق من صلاحية الـ Session
  /// 3. تحدّث الحالة الداخلية
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // في SplashScreen:
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   checkAuth();
  /// }
  ///
  /// Future<void> checkAuth() async {
  ///   await AuthService.instance.checkAuthStatus();
  ///
  ///   if (AuthService.instance.isAuthenticated) {
  ///     navigateToHome();
  ///   } else {
  ///     navigateToLogin();
  ///   }
  /// }
  /// ```
  ///
  /// ⚠️ في الإنتاج:
  /// ```dart
  /// Future<void> checkAuthStatus() async {
  ///   // 1. جلب Token من Secure Storage
  ///   final token = await SecureStorage.read('auth_token');
  ///
  ///   if (token == null) {
  ///     _isAuthenticated = false;
  ///     return;
  ///   }
  ///
  ///   // 2. التحقق من صلاحية Token
  ///   try {
  ///     final response = await dio.get('/auth/verify',
  ///       options: Options(headers: {'Authorization': 'Bearer $token'})
  ///     );
  ///
  ///     if (response.statusCode == 200) {
  ///       _isAuthenticated = true;
  ///       _userId = response.data['userId'];
  ///       _userEmail = response.data['email'];
  ///     } else {
  ///       _isAuthenticated = false;
  ///     }
  ///   } catch (e) {
  ///     _isAuthenticated = false;
  ///   }
  /// }
  /// ```
  Future<void> checkAuthStatus() async {
    AppLogger.info('[AuthService] Checking authentication status', name: 'AuthService');

    // تأخير بسيط لمحاكاة استدعاء API
    // في الإنتاج: هنا نتحقق من Token أو Session
    await Future.delayed(const Duration(milliseconds: 100));

    AppLogger.info('[AuthService] Auth status: $_isAuthenticated', name: 'AuthService');
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔓 login() - تسجيل الدخول
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// تسجيل دخول المستخدم بإيميل وكلمة مرور
  ///
  /// 📥 المدخلات:
  /// - email: البريد الإلكتروني
  /// - password: كلمة المرور
  ///
  /// 📤 المخرجات:
  /// - true: نجح تسجيل الدخول
  /// - false: فشل تسجيل الدخول
  ///
  /// 🔄 الخطوات:
  /// 1. إرسال Email + Password للـ Backend
  /// 2. استقبال Token من Backend
  /// 3. حفظ Token في Secure Storage
  /// 4. حفظ معلومات المستخدم محلياً
  /// 5. تحديث حالة المصادقة
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // في LoginPage:
  /// Future<void> handleLogin() async {
  ///   final email = emailController.text;
  ///   final password = passwordController.text;
  ///
  ///   setState(() => isLoading = true);
  ///
  ///   try {
  ///     final success = await AuthService.instance.login(email, password);
  ///
  ///     if (success) {
  ///       showSuccess('تم تسجيل الدخول بنجاح!');
  ///       navigateToHome();
  ///     } else {
  ///       showError('فشل تسجيل الدخول، تحقق من بياناتك');
  ///     }
  ///   } catch (e) {
  ///     showError('حدث خطأ: $e');
  ///   } finally {
  ///     setState(() => isLoading = false);
  ///   }
  /// }
  /// ```
  ///
  /// ⚠️ في الإنتاج - مع Firebase:
  /// ```dart
  /// Future<bool> login(String email, String password) async {
  ///   try {
  ///     // 1. تسجيل دخول في Firebase
  ///     final credential = await FirebaseAuth.instance
  ///         .signInWithEmailAndPassword(email: email, password: password);
  ///
  ///     // 2. جلب Token
  ///     final token = await credential.user?.getIdToken();
  ///
  ///     // 3. حفظ Token في Secure Storage
  ///     await SecureStorage.write('auth_token', token);
  ///
  ///     // 4. حفظ معلومات المستخدم
  ///     _isAuthenticated = true;
  ///     _userId = credential.user?.uid;
  ///     _userEmail = credential.user?.email;
  ///
  ///     // 5. حفظ User في Hive للاستخدام Offline
  ///     final user = await fetchUserFromFirestore(_userId!);
  ///     await userBox.put('current_user', user);
  ///
  ///     return true;
  ///   } on FirebaseAuthException catch (e) {
  ///     AppLogger.error('Login failed: ${e.code}', name: 'AuthService');
  ///
  ///     // معالجة أخطاء محددة
  ///     if (e.code == 'user-not-found') {
  ///       throw Exception('لا يوجد مستخدم بهذا الإيميل');
  ///     } else if (e.code == 'wrong-password') {
  ///       throw Exception('كلمة المرور خاطئة');
  ///     }
  ///
  ///     return false;
  ///   }
  /// }
  /// ```
  Future<bool> login(String email, String password) async {
    AppLogger.info('[AuthService] Attempting login for: $email', name: 'AuthService');

    // تأخير لمحاكاة استدعاء API
    // في الإنتاج: هنا نرسل للـ Backend أو Firebase
    await Future.delayed(const Duration(seconds: 1));

    // ✅ نجح تسجيل الدخول (في التطوير، نفترض النجاح دائماً)
    _isAuthenticated = true;
    _userEmail = email;

    // إنشاء User ID فريد بناءً على الوقت
    // في الإنتاج: نحصل عليه من Firebase/Backend
    _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.success('[AuthService] Login successful', name: 'AuthService');
    return true;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🚪 logout() - تسجيل الخروج
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// تسجيل خروج المستخدم ومسح جميع بياناته المحفوظة
  ///
  /// 🔄 الخطوات:
  /// 1. إلغاء الـ Token من الـ Backend (في الإنتاج)
  /// 2. مسح Token من Secure Storage
  /// 3. مسح بيانات المستخدم المحلية
  /// 4. إعادة تعيين حالة المصادقة
  /// 5. التوجيه لشاشة Login
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // في SettingsPage أو ProfilePage:
  /// Future<void> handleLogout() async {
  ///   // عرض تأكيد أولاً
  ///   final confirm = await showDialog<bool>(
  ///     context: context,
  ///     builder: (context) => AlertDialog(
  ///       title: Text('تسجيل الخروج'),
  ///       content: Text('هل أنت متأكد من تسجيل الخروج؟'),
  ///       actions: [
  ///         TextButton(
  ///           onPressed: () => Navigator.pop(context, false),
  ///           child: Text('إلغاء'),
  ///         ),
  ///         TextButton(
  ///           onPressed: () => Navigator.pop(context, true),
  ///           child: Text('تسجيل الخروج'),
  ///         ),
  ///       ],
  ///     ),
  ///   );
  ///
  ///   if (confirm == true) {
  ///     await AuthService.instance.logout();
  ///     navigateToLogin();
  ///   }
  /// }
  /// ```
  ///
  /// ⚠️ في الإنتاج:
  /// ```dart
  /// Future<void> logout() async {
  ///   try {
  ///     // 1. تسجيل خروج من Firebase
  ///     await FirebaseAuth.instance.signOut();
  ///
  ///     // 2. مسح Token من Secure Storage
  ///     await SecureStorage.delete('auth_token');
  ///
  ///     // 3. مسح بيانات المستخدم من Hive
  ///     final userBox = await Hive.openBox<UserModel>('user');
  ///     await userBox.delete('current_user');
  ///
  ///     // 4. اختياري: مسح جميع البيانات المحلية
  ///     // await Hive.deleteFromDisk();
  ///
  ///     // 5. إعادة تعيين الحالة
  ///     _isAuthenticated = false;
  ///     _userId = null;
  ///     _userEmail = null;
  ///
  ///     AppLogger.success('Logout successful', name: 'AuthService');
  ///   } catch (e) {
  ///     AppLogger.error('Logout failed: $e', name: 'AuthService');
  ///     rethrow;
  ///   }
  /// }
  /// ```
  ///
  /// 💡 نصيحة أمنية:
  /// عند تسجيل الخروج، تأكد من:
  /// - إلغاء جميع Timers النشطة
  /// - إيقاف جميع Streams
  /// - مسح أي Notifications معلقة
  /// - إلغاء أي Requests قيد التنفيذ
  Future<void> logout() async {
    AppLogger.info('[AuthService] Logging out', name: 'AuthService');

    // في الإنتاج: مسح Token، Firebase logout، إلخ

    // إعادة تعيين جميع المتغيرات
    _isAuthenticated = false;
    _userId = null;
    _userEmail = null;

    AppLogger.success('[AuthService] Logout successful', name: 'AuthService');
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⚙️ setAuthenticated() - تعيين حالة المصادقة يدوياً
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// ⚠️ تحذير: هذه الدالة للاستخدام الداخلي فقط!
  ///
  /// 🎯 متى تُستخدم؟
  /// - في الـ Testing (اختبار الوحدات)
  /// - في سيناريوهات تطوير خاصة
  /// - عند استعادة Session من Secure Storage
  ///
  /// 💡 مثال (Testing):
  /// ```dart
  /// // في ملف الاختبار:
  /// test('User can access home when authenticated', () {
  ///   // تعيين المستخدم كمسجل دخول
  ///   AuthService.instance.setAuthenticated(true);
  ///
  ///   // اختبار أن المستخدم يمكنه الوصول للصفحة الرئيسية
  ///   expect(canAccessHome(), true);
  /// });
  /// ```
  ///
  /// ⚠️ لا تستخدمها في كود الإنتاج!
  /// استخدم login() و logout() بدلاً منها
  void setAuthenticated(bool value) {
    _isAuthenticated = value;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 ملاحظات إضافية للمبتدئين:
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🔐 أمان المصادقة - Best Practices:
///
/// 1️⃣ **استخدم HTTPS دائماً:**
///    - كل Requests للـ Backend عبر HTTPS
///    - لا ترسل Passwords عبر HTTP أبداً!
///
/// 2️⃣ **احفظ Tokens بشكل آمن:**
///    ```dart
///    // ❌ خطأ:
///    SharedPreferences.setString('token', token);  // غير آمن!
///
///    // ✅ صحيح:
///    FlutterSecureStorage().write(key: 'token', value: token);
///    ```
///
/// 3️⃣ **استخدم Token Expiry:**
///    ```dart
///    class TokenData {
///      String token;
///      DateTime expiresAt;
///
///      bool get isExpired => DateTime.now().isAfter(expiresAt);
///    }
///    ```
///
/// 4️⃣ **Refresh Tokens:**
///    ```dart
///    if (tokenIsExpired) {
///      final newToken = await refreshToken(oldToken);
///      await saveToken(newToken);
///    }
///    ```
///
/// 5️⃣ **Handle 401 Errors:**
///    ```dart
///    // في Dio Interceptor:
///    onError: (error, handler) {
///      if (error.response?.statusCode == 401) {
///        // Token انتهى أو غير صالح
///        AuthService.instance.logout();
///        navigateToLogin();
///      }
///    }
///    ```
///
/// 🔄 حالات خاصة:
///
/// 1️⃣ **Remember Me:**
///    ```dart
///    if (rememberMe) {
///      // احفظ Token بدون expiry
///      await saveToken(token, expiry: null);
///    } else {
///      // احفظ Token مع expiry قصير (مثلاً 24 ساعة)
///      await saveToken(token, expiry: DateTime.now().add(Duration(hours: 24)));
///    }
///    ```
///
/// 2️⃣ **Social Login:**
///    ```dart
///    Future<bool> loginWithGoogle() async {
///      final googleUser = await GoogleSignIn().signIn();
///      final googleAuth = await googleUser.authentication;
///
///      final credential = GoogleAuthProvider.credential(
///        accessToken: googleAuth.accessToken,
///        idToken: googleAuth.idToken,
///      );
///
///      final userCredential = await FirebaseAuth.instance
///          .signInWithCredential(credential);
///
///      // نفس الخطوات بعد login عادي
///      _isAuthenticated = true;
///      _userId = userCredential.user?.uid;
///      // ...
///    }
///    ```
///
/// 3️⃣ **Biometric Auth:**
///    ```dart
///    final auth = LocalAuthentication();
///    final canAuthenticate = await auth.canCheckBiometrics;
///
///    if (canAuthenticate) {
///      final authenticated = await auth.authenticate(
///        localizedReason: 'مسح بصمة الإصبع لتسجيل الدخول',
///      );
///
///      if (authenticated) {
///        // جلب Token المحفوظ من Secure Storage
///        final token = await SecureStorage.read('auth_token');
///        // تسجيل دخول تلقائي
///      }
///    }
///    ```
/// ═══════════════════════════════════════════════════════════════════════════
