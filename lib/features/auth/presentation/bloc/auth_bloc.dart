import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 AuthBloc - منطق إدارة حالة المصادقة (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// هذا الملف هو **الوسيط بين الواجهة والمنطق**
/// مسؤولياته:
/// 1. استقبال أحداث من المستخدم (Events):
///    - ضغط على زر "تسجيل الدخول"
///    - ضغط على زر "إنشاء حساب"
///    - ضغط على زر "تسجيل الخروج"
/// 2. استدعاء Use Cases (من Domain Layer) لتنفيذ الأحداث
/// 3. إصدار حالات جديدة (States) لتحديث الواجهة
/// 4. التعامل مع الأخطاء وإظهارها للمستخدم
///
/// تدفق البيانات (Data Flow):
/// ```
/// UI (LoginPage)
///   ↓ ضغط الزر
/// AuthBloc.add(AuthLoginRequested(...))
///   ↓ يستدعي handler
/// _onLoginRequested()
///   ↓ emit(AuthLoading) → الواجهة تعرض spinner
/// loginUseCase.call()
///   ↓ استدعاء Repository
/// AuthRepository.login()
///   ↓ استدعاء DataSource
/// Firebase/Mock
///   ↓ النتيجة
/// emit(AuthSuccess) أو emit(AuthFailure)
///   ↓ تحديث الواجهة
/// HomePage أو LoginPage + Error
/// ```
///
/// الفرق بين Event و State:
/// - **Event (الحدث)**: ما يفعله المستخدم
///   - AuthLoginRequested: اضغط على زر الدخول
///   - AuthRegisterRequested: اضغط على زر التسجيل
/// 
/// - **State (الحالة)**: حالة التطبيق الحالية
///   - AuthLoading: جاري التحميل
///   - AuthSuccess: نجح الدخول
///   - AuthFailure: فشل الدخول
///   - AuthUnauthenticated: المستخدم غير مسجل دخول
///
/// مثال عملي:
/// ```
/// // الواجهة تضغط الزر
/// context.read<AuthBloc>().add(
///   AuthLoginRequested(email: 'user@example.com', password: 'pass')
/// );
/// 
/// // AuthBloc يستدعي handler
/// _onLoginRequested → emit(AuthLoading) → UI تعرض spinner
/// 
/// // الحصول على النتيجة
/// loginUseCase() → User أو Error
/// 
/// // تحديث الواجهة
/// emit(AuthSuccess(user)) → UI تنتقل للصفحة الرئيسية
/// ```

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// 🔗 الاعتماديات (Dependencies) - Use Cases
  /// كل Use Case يتعامل مع عملية محددة
  final LoginUseCase loginUseCase;           /// 🔐 تسجيل الدخول
  final RegisterUseCase registerUseCase;     /// 📝 إنشاء حساب جديد
  final LogoutUseCase logoutUseCase;         /// 🚪 تسجيل الخروج
  final ResetPasswordUseCase resetPasswordUseCase;  /// 🔑 إعادة تعيين كلمة المرور
  final GetCurrentUserUseCase getCurrentUserUseCase; /// 👤 الحصول على بيانات المستخدم

  /// ═══════════════════════════════════════════════════════════════════════════
  /// Constructor - تهيئة BLoC
  /// ═══════════════════════════════════════════════════════════════════════════
  /// super(const AuthInitial())
  ///   → تعيين الحالة الأولية: "لم يحدث شيء بعد"
  /// 
  /// on<AuthLoginRequested>(_onLoginRequested)
  ///   → ربط الحدث (Event) بالدالة التي تتعامل معه
  ///   → هذا يسمى "Event Mapping" أو "Event Routing"
  /// 
  /// كل سطر يقول: "إذا وصل هذا الحدث، استدعِ هذه الدالة"

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.resetPasswordUseCase,
    required this.getCurrentUserUseCase,
  }) : super(const AuthInitial()) {
    /// 🔗 ربط الأحداث بمعالجاتها (Event Handlers)
    /// هذا نمط يسمى: "Event-Driven Architecture"
    /// 
    /// الفكرة:
    /// - كل حدث له handler خاص
    /// - عندما يأتي الحدث، استدعِ الـ handler
    /// - الـ handler يعالج الحدث ويصدر States
    
    on<AuthLoginRequested>(_onLoginRequested);        /// تسجيل الدخول
    on<AuthRegisterRequested>(_onRegisterRequested);  /// التسجيل (إنشاء حساب)
    on<AuthLogoutRequested>(_onLogoutRequested);      /// تسجيل الخروج
    on<AuthResetPasswordRequested>(_onResetPasswordRequested); /// إعادة تعيين كلمة المرور
    on<AuthCheckRequested>(_onCheckRequested);        /// التحقق من حالة المصادقة
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔐 معالج الحدث: تسجيل الدخول (_onLoginRequested)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// معاملات الدالة:
  /// [event]: البيانات التي أرسلتها الواجهة (email و password)
  /// [emit]: دالة لإرسال حالات جديدة للواجهة
  ///
  /// كلمة مفتاحية: async
  /// معناه: هذه الدالة بطيئة وقد تأخذ وقتاً (Future)
  /// لماذا؟ لأننا نحتاج الاتصال بـ Firebase أو Mock
  ///
  /// مراحل الدالة:
  /// 1️⃣ أرسل حالة "جاري التحميل" (Loading)
  ///    - الواجهة تعرض spinner
  /// 2️⃣ استدعِ loginUseCase
  ///    - Use Case يتحقق من البيانات
  ///    - Use Case يستدعي Repository
  ///    - Repository يستدعي DataSource
  /// 3️⃣ معالجة النتيجة بـ fold
  ///    - إذا فشل: أرسل AuthFailure
  ///    - إذا نجح: أرسل AuthSuccess
  
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] تم طلب تسجيل الدخول للبريد: ${event.email}', name: 'AuthBloc');
    
    /// 1️⃣ أرسل حالة تحميل للواجهة
    /// emit(state) = إرسال state جديد لجميع المستمعين (Listeners)
    /// الواجهة (BlocBuilder) ستستقبل هذا State وتحدث نفسها
    emit(const AuthLoading());

    /// 2️⃣ استدعِ loginUseCase
    /// 
    /// LoginUseCase = class يحتوي على منطق تسجيل الدخول
    /// نمرر: email و password (من المستخدم)
    /// النتيجة: Either<Failure, User>
    ///   - Left (الفشل): الخطأ
    ///   - Right (النجاح): بيانات المستخدم
    /// 
    /// await = انتظر النتيجة (قد تأخذ من الإنترنت)
    final result = await loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );

    /// 3️⃣ معالجة النتيجة باستخدام fold
    /// 
    /// fold = دالة من مكتبة dartz
    /// تتعامل مع النوعين:
    /// - failure (Left): إذا فشلت العملية
    /// - success (Right): إذا نجحت العملية
    /// 
    /// الصيغة: result.fold(onFailure, onSuccess)
    result.fold(
      /// ❌ الحالة الأولى: فشل العملية (Left)
      /// failure = object يحتوي على رسالة الخطأ
      (failure) {
        AppLogger.error('[AuthBloc] فشل تسجيل الدخول: ${failure.message}', name: 'AuthBloc');
        
        /// أرسل حالة فشل مع رسالة الخطأ
        /// الواجهة ستعرض الخطأ (SnackBar أو Dialog)
        emit(AuthFailure(message: failure.message));
      },
      
      /// ✅ الحالة الثانية: نجحت العملية (Right)
      /// user = بيانات المستخدم (UserEntity)
      (user) {
        AppLogger.success('[AuthBloc] نجح تسجيل الدخول', name: 'AuthBloc');
        
        /// أرسل حالة النجاح مع بيانات المستخدم
        /// الواجهة ستنتقل للصفحة الرئيسية (Home Page)
        /// لأن GoRouter يراقب هذه الحالة!
        emit(AuthSuccess(user: user));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📝 معالج الحدث: إنشاء حساب جديد (_onRegisterRequested)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// نفس الفكرة مثل تسجيل الدخول، لكن:
  /// - نمرر: name و email و password و confirmPassword
  /// - نستدعي: registerUseCase (بدل loginUseCase)
  /// - registerUseCase يتحقق من:
  ///   - صحة البريد الإلكتروني
  ///   - قوة كلمة المرور
  ///   - تطابق كلمات المرور
  ///   - عدم وجود بريد موجود بالفعل

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] تم طلب التسجيل للبريد: ${event.email}', name: 'AuthBloc');
    emit(const AuthLoading());

    /// استدعاء registerUseCase مع بيانات التسجيل
    final result = await registerUseCase(
      RegisterParams(
        name: event.name,
        email: event.email,
        password: event.password,
        confirmPassword: event.confirmPassword,
      ),
    );

    /// معالجة النتيجة (نفس الطريقة)
    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل التسجيل: ${failure.message}', name: 'AuthBloc');
        emit(AuthFailure(message: failure.message));
      },
      (user) {
        AppLogger.success('[AuthBloc] نجح التسجيل', name: 'AuthBloc');
        /// بعد التسجيل، سجل المستخدم دخول فوراً
        emit(AuthSuccess(user: user));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🚪 معالج الحدث: تسجيل الخروج (_onLogoutRequested)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// الهدف: حذف بيانات المستخدم من Hive و Firebase
  /// 
  /// خطوات الخروج:
  /// 1. حذف Token من التخزين المحلي
  /// 2. حذف بيانات المستخدم
  /// 3. تسجيل الخروج من Firebase
  /// 4. إرسال حالة: AuthUnauthenticated (لا يوجد مستخدم مسجل)
  /// 5. GoRouter ستنقل المستخدم لـ Login Page

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] تم طلب تسجيل الخروج', name: 'AuthBloc');
    emit(const AuthLoading());

    /// استدعاء logoutUseCase
    final result = await logoutUseCase();

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل تسجيل الخروج: ${failure.message}', name: 'AuthBloc');
        emit(AuthFailure(message: failure.message));
      },
      /// (_) = ignoring the result (لا نحتاج النتيجة، فقط نريد تنفيذ العملية)
      (_) {
        AppLogger.success('[AuthBloc] نجح تسجيل الخروج', name: 'AuthBloc');
        /// أرسل حالة: "لا يوجد مستخدم مسجل دخول"
        /// GoRouter سترى هذه الحالة وتنقل للـ Login Page
        emit(const AuthUnauthenticated());
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔑 معالج الحدث: إعادة تعيين كلمة المرور (_onResetPasswordRequested)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// الهدف: إرسال رابط تعيين كلمة المرور إلى بريد المستخدم
  /// 
  /// الخطوات:
  /// 1. أرسل رابط reset password لـ Firebase
  /// 2. Firebase يرسل البريد الإلكتروني
  /// 3. المستخدم ينقر على الرابط في البريد
  /// 4. يعيد تعيين كلمة المرور

  Future<void> _onResetPasswordRequested(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] تم طلب إعادة تعيين كلمة المرور للبريد: ${event.email}', name: 'AuthBloc');
    emit(const AuthLoading());

    /// استدعاء resetPasswordUseCase مع البريد الإلكتروني
    final result = await resetPasswordUseCase(event.email);

    result.fold(
      (failure) {
        AppLogger.error('[AuthBloc] فشل إعادة تعيين كلمة المرور: ${failure.message}', name: 'AuthBloc');
        emit(AuthFailure(message: failure.message));
      },
      (_) {
        AppLogger.success('[AuthBloc] تم إرسال رابط إعادة التعيين', name: 'AuthBloc');
        /// أرسل حالة خاصة: تم إرسال البريد
        /// الواجهة ستعرض رسالة: "تحقق من بريدك الإلكتروني"
        emit(AuthPasswordResetSent(email: event.email));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 👤 معالج الحدث: التحقق من المصادقة (_onCheckRequested)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// الهدف: التحقق من وجود مستخدم مسجل دخول
  /// 
  /// السيناريوهات:
  /// 1. هناك token في Hive ولا يزال صحيحاً → AuthSuccess
  /// 2. هناك token لكنه انتهى صلاحيته → AuthUnauthenticated
  /// 3. لا يوجد token أصلاً → AuthUnauthenticated
  /// 
  /// متى يتم استدعاء هذه الدالة؟
  /// - عند بدء التطبيق (في main.dart)
  /// - عند تحديث الواجهة (Pull to refresh)

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.info('[AuthBloc] التحقق من حالة المصادقة', name: 'AuthBloc');
    emit(const AuthLoading());

    /// استدعاء getCurrentUserUseCase
    /// هذا الـ Use Case:
    /// 1. يتحقق من وجود Token في Hive
    /// 2. إذا موجود: يتحقق من صلاحيته في Firebase
    /// 3. إذا صحيح: يعيد بيانات المستخدم
    /// 4. إذا انتهت الصلاحية: يعيد خطأ
    final result = await getCurrentUserUseCase();

    result.fold(
      /// ❌ الفشل: لا يوجد مستخدم أو انتهت صلاحية Token
      (failure) {
        AppLogger.info('[AuthBloc] لا يوجد مستخدم مسجل دخول', name: 'AuthBloc');
        /// أرسل حالة: "لا يوجد مستخدم مصرح"
        /// GoRouter ستعرض Login Page
        emit(const AuthUnauthenticated());
      },
      /// ✅ النجاح: يوجد مستخدم مسجل دخول وToken صحيح
      (user) {
        AppLogger.success('[AuthBloc] المستخدم مصرح: ${user.email}', name: 'AuthBloc');
        /// أرسل حالة: "المستخدم مسجل دخول"
        /// GoRouter ستعرض Home Page
        emit(AuthSuccess(user: user));
      },
    );
  }
}
