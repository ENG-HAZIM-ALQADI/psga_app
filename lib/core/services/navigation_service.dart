import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/routes.dart';
import '../utils/logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🧭 NavigationService - خدمة التنقل في التطبيق
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🎯 الموقع في Clean Architecture:
/// - الطبقة: Core Layer > Services
/// - النوع: Static Service (خدمة ثابتة - لا تحتاج Singleton)
/// - الوظيفة: إدارة التنقل بين الصفحات في التطبيق
///
/// 📌 ما هي خدمة التنقل؟
/// NavigationService هي "الملاح" في التطبيق:
/// - توفر طرق سهلة للانتقال بين الصفحات
/// - تدعم التنقل من خارج Widget Tree (مثل BLoC أو Service)
/// - تستخدم GoRouter (أحدث وأفضل من Navigator القديم)
/// - توفر logging لتتبع حركة المستخدم
///
/// 💡 لماذا نحتاج NavigationService؟
///
/// ❌ بدون NavigationService:
/// ```dart
/// // في BLoC أو UseCase - لا يعمل!
/// Navigator.of(context).push(...);  // ❌ لا يوجد context هنا!
/// ```
///
/// ✅ مع NavigationService:
/// ```dart
/// // من أي مكان في الكود!
/// NavigationService.navigateTo('/home');  // ✅ يعمل!
/// ```
///
/// 🔑 المكون الأساسي: GlobalKey<NavigatorState>
/// هذا هو "المفتاح السحري" الذي يعطينا وصول للـ Navigator من أي مكان:
/// ```dart
/// MaterialApp(
///   navigatorKey: NavigationService.navigatorKey,  // ربط المفتاح
///   // ...
/// );
/// ```
///
/// 🎯 حالات الاستخدام الشائعة:
/// 1. **من BLoC/Cubit**: بعد نجاح عملية، انتقل لصفحة أخرى
/// 2. **من UseCase**: بعد تسجيل دخول، اذهب للـ Home
/// 3. **من Service**: عند انقطاع الإنترنت، اعرض صفحة Offline
/// 4. **من Error Handler**: عند 401، اذهب للـ Login

class NavigationService {
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔧 Private Constructor
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 لماذا؟
  /// جميع الدوال static، لا نحتاج إنشاء كائن من NavigationService
  /// هذا يمنع الاستخدام الخاطئ: `NavigationService()`
  NavigationService._();

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔑 GlobalKey - المفتاح للوصول للـ Navigator
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 ما هو GlobalKey؟
  /// GlobalKey هو "مفتاح فريد" يربط Widget معين في شجرة الـ Widgets
  /// بحيث يمكننا الوصول له من أي مكان في الكود
  ///
  /// 🔗 كيف نستخدمه؟
  /// في main.dart أو app.dart:
  /// ```dart
  /// MaterialApp.router(
  ///   routerConfig: router,
  ///   // ربط المفتاح هنا! ✅
  ///   builder: (context, child) {
  ///     return Navigator(
  ///       key: NavigationService.navigatorKey,
  ///       observers: [/* ... */],
  ///       onGenerateRoute: /* ... */,
  ///     );
  ///   },
  /// );
  /// ```
  ///
  /// 📝 ملاحظة مهمة:
  /// GlobalKey<NavigatorState> يعطينا وصول لـ NavigatorState
  /// وهذا يسمح لنا باستخدام جميع دوال التنقل:
  /// - push, pop, pushReplacement, pushAndRemoveUntil, إلخ
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Getter للوصول السريع للـ Navigator
  ///
  /// 💡 الاستخدام:
  /// ```dart
  /// _navigator?.push(MaterialPageRoute(...));
  /// ```
  ///
  /// ⚠️ لماحظة: قد يكون null إذا لم يتم ربط المفتاح بعد!
  static NavigatorState? get _navigator => navigatorKey.currentState;

  /// Getter للوصول للـ BuildContext الحالي
  ///
  /// 💡 مفيد لـ:
  /// - استخدام Theme.of(context)
  /// - استخدام MediaQuery.of(context)
  /// - استخدام GoRouter.of(context)
  ///
  /// 📝 مثال:
  /// ```dart
  /// final isDark = Theme.of(NavigationService.context!).brightness == Brightness.dark;
  /// ```
  static BuildContext? get context => navigatorKey.currentContext;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🚀 navigateTo() - الانتقال لصفحة جديدة (Push)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// إضافة صفحة جديدة فوق الصفحة الحالية في الـ Stack
  ///
  /// 📥 المدخلات:
  /// - route: مسار الصفحة (مثل '/home', '/profile')
  /// - extra: بيانات إضافية لتمريرها للصفحة (optional)
  ///
  /// 💡 متى نستخدمها؟
  /// - الانتقال لصفحة تفاصيل
  /// - فتح صفحة إعدادات
  /// - عرض نموذج (Form)
  ///
  /// 📝 أمثلة:
  /// ```dart
  /// // بدون بيانات
  /// NavigationService.navigateTo('/settings');
  ///
  /// // مع بيانات
  /// NavigationService.navigateTo(
  ///   '/trip-details',
  ///   extra: {'tripId': 'trip_123'}
  /// );
  ///
  /// // في الصفحة المستقبلة:
  /// final args = GoRouterState.of(context).extra as Map<String, dynamic>;
  /// final tripId = args['tripId'];
  /// ```
  ///
  /// 🔄 Navigation Stack:
  /// ```
  /// Before: [Home]
  /// After:  [Home, Settings]  ← زر Back يرجع للـ Home
  /// ```
  static void navigateTo(String route, {Object? extra}) {
    AppLogger.info('Navigating to: $route', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).push(route, extra: extra);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔄 navigateAndReplace() - استبدال الصفحة الحالية
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// استبدال الصفحة الحالية بصفحة جديدة (بدون إضافتها للـ Stack)
  ///
  /// 💡 متى نستخدمها؟
  /// - بعد تسجيل الدخول: Login → Home (لا نريد العودة للـ Login!)
  /// - بعد Onboarding: Onboarding → Home
  /// - بعد SplashScreen: Splash → Login/Home
  ///
  /// 🔄 Navigation Stack:
  /// ```
  /// Before: [Splash, Login]
  /// After:  [Splash, Home]  ← Login تم استبدالها بـ Home
  /// ```
  ///
  /// 📝 مثال:
  /// ```dart
  /// // بعد نجاح Login:
  /// NavigationService.navigateAndReplace('/home');
  /// // الآن زر Back لن يرجع للـ Login ✅
  /// ```
  static void navigateAndReplace(String route, {Object? extra}) {
    AppLogger.info('Navigating and replacing with: $route', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).pushReplacement(route, extra: extra);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⬅️ goBack() - العودة للصفحة السابقة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// إزالة الصفحة الحالية من الـ Stack والعودة للصفحة السابقة
  ///
  /// 📥 المدخلات:
  /// - result: نتيجة اختيارية لإرجاعها للصفحة السابقة
  ///
  /// 💡 متى نستخدمها؟
  /// - عند الضغط على زر "رجوع"
  /// - بعد حفظ Form بنجاح
  /// - بعد اختيار عنصر من قائمة
  ///
  /// 📝 أمثلة:
  /// ```dart
  /// // رجوع بسيط
  /// NavigationService.goBack();
  ///
  /// // رجوع مع نتيجة
  /// NavigationService.goBack({'saved': true, 'itemId': '123'});
  ///
  /// // في الصفحة السابقة:
  /// final result = await Navigator.push(...);
  /// if (result != null && result['saved'] == true) {
  ///   showSuccess('تم الحفظ!');
  /// }
  /// ```
  ///
  /// ⚠️ ملاحظة:
  /// إذا كانت هذه آخر صفحة في الـ Stack (مثلاً الـ Home)،
  /// goBack() لن تفعل شيء (لمنع إغلاق التطبيق بالخطأ)
  static void goBack<T>([T? result]) {
    AppLogger.info('Going back', name: 'NavigationService');
    if (_navigator?.canPop() ?? false) {
      _navigator?.pop(result);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏠 navigateToAndClearStack() - التنقل ومسح الـ Stack
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// الذهاب لصفحة معينة ومسح جميع الصفحات السابقة من الـ Stack
  ///
  /// 💡 متى نستخدمها؟
  /// - بعد تسجيل الخروج: أي صفحة → Login (مسح كل شيء!)
  /// - بعد إتمام عملية: Checkout Steps → Home
  /// - Reset التطبيق: أي حالة → Initial State
  ///
  /// 🔄 Navigation Stack:
  /// ```
  /// Before: [Splash, Login, Home, Profile, Settings]
  /// After:  [Login]  ← تم مسح كل شيء!
  /// ```
  ///
  /// 📝 مثال:
  /// ```dart
  /// // بعد Logout:
  /// await AuthService.instance.logout();
  /// NavigationService.navigateToAndClearStack('/login');
  /// // الآن لا يمكن العودة للصفحات السابقة ✅
  /// ```
  ///
  /// ⚠️ تحذير:
  /// استخدم هذه الدالة بحذر! مسح الـ Stack يعني:
  /// - لا يمكن استخدام زر Back للعودة
  /// - أي بيانات غير محفوظة ستُفقد
  static void navigateToAndClearStack(String route, {Object? extra}) {
    AppLogger.info('Navigating to $route and clearing stack', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).go(route, extra: extra);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🎯 goTo() - الذهاب المباشر لصفحة (بدون Push)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// الانتقال المباشر لمسار معين (يستبدل الـ Stack الحالي)
  ///
  /// 💡 الفرق بين go() و push():
  /// - push(): يضيف صفحة فوق الموجودة (زر Back يرجع)
  /// - go(): يذهب مباشرة (يعيد بناء الـ Stack من الصفر)
  ///
  /// 📝 مثال:
  /// ```dart
  /// // استخدام go:
  /// GoRouter.of(context).go('/home');
  /// // → Stack يصبح: [Home]
  ///
  /// // استخدام push:
  /// GoRouter.of(context).push('/home');
  /// // → Stack يصبح: [CurrentPage, Home]
  /// ```
  ///
  /// 💡 متى نستخدم go()؟
  /// - Deep Links: فتح التطبيق من رابط خارجي
  /// - تحديث URL في Web App
  /// - Navigation Bars السفلية (BottomNavigationBar)
  static void goTo(String route, {Object? extra}) {
    AppLogger.info('Going to: $route', name: 'NavigationService');
    if (context != null) {
      GoRouter.of(context!).go(route, extra: extra);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ❓ canPop() - هل يمكن الرجوع؟
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// التحقق من وجود صفحات سابقة في الـ Stack يمكن الرجوع لها
  ///
  /// 📤 المخرجات:
  /// - true: يوجد صفحات سابقة، يمكن استخدام goBack()
  /// - false: هذه آخر صفحة، goBack() لن يعمل
  ///
  /// 💡 متى نستخدمها؟
  /// - لإخفاء/إظهار زر "رجوع" في الـ AppBar
  /// - لتنفيذ WillPopScope بشكل صحيح
  /// - لمنع إغلاق التطبيق بالخطأ
  ///
  /// 📝 أمثلة:
  /// ```dart
  /// // مثال 1: AppBar ديناميكي
  /// AppBar(
  ///   leading: NavigationService.canPop()
  ///       ? IconButton(
  ///           icon: Icon(Icons.arrow_back),
  ///           onPressed: () => NavigationService.goBack(),
  ///         )
  ///       : null,  // لا يوجد زر رجوع في الـ Home
  /// );
  ///
  /// // مثال 2: تأكيد الخروج
  /// WillPopScope(
  ///   onWillPop: () async {
  ///     if (!NavigationService.canPop()) {
  ///       // آخر صفحة، اسأل المستخدم
  ///       return await showExitDialog();
  ///     }
  ///     return true;  // يمكن الرجوع عادي
  ///   },
  ///   child: /* ... */,
  /// );
  /// ```
  static bool canPop() {
    return _navigator?.canPop() ?? false;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔙 popUntil() - الرجوع لصفحة معينة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 الوظيفة:
  /// إزالة جميع الصفحات حتى الوصول لصفحة معينة
  ///
  /// 💡 متى نستخدمها؟
  /// - بعد Multi-step Form: Step3 → Step2 → Step1 → Home
  /// - إلغاء عملية معقدة: Checkout → Cart → Home
  ///
  /// 📝 مثال:
  /// ```dart
  /// // لديك: [Home, Products, Cart, Checkout, Payment]
  /// // تريد: العودة لـ Home مباشرة
  /// NavigationService.popUntil('/home');
  /// // النتيجة: [Home] ✅
  /// ```
  ///
  /// ⚠️ ملاحظة:
  /// هذا Implementation بسيط، في GoRouter الحديث يفضل استخدام:
  /// ```dart
  /// context.go('/home');  // أبسط وأوضح!
  /// ```
  static void popUntil(String route) {
    AppLogger.info('Popping until: $route', name: 'NavigationService');
    if (context != null) {
      while (GoRouter.of(context!).canPop()) {
        GoRouter.of(context!).pop();
      }
      GoRouter.of(context!).go(route);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏠 دوال مختصرة للصفحات الشائعة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 هذه دوال helper لتسهيل الكود:
  /// بدلاً من: `NavigationService.goTo(AppRoutes.home)`
  /// نكتب: `NavigationService.goToHome()`
  ///
  /// 📝 يمكنك إضافة المزيد حسب الحاجة:
  /// ```dart
  /// static void goToProfile() => goTo(AppRoutes.profile);
  /// static void goToSettings() => goTo(AppRoutes.settings);
  /// static void goToTripDetails(String tripId) {
  ///   goTo('${AppRoutes.trips}/$tripId');
  /// }
  /// ```

  /// الذهاب للصفحة الرئيسية
  static void goToHome() {
    goTo(AppRoutes.home);
  }

  /// الذهاب لصفحة تسجيل الدخول
  static void goToLogin() {
    goTo(AppRoutes.login);
  }

  /// الذهاب لصفحة Splash
  static void goToSplash() {
    goTo(AppRoutes.splash);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 ملاحظات إضافية وأمثلة متقدمة:
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🔐 Navigation Guards (حماية المسارات):
///
/// ```dart
/// // في GoRouter configuration:
/// GoRoute(
///   path: '/profile',
///   builder: (context, state) => ProfilePage(),
///   redirect: (context, state) {
///     // إذا غير مسجل دخول، اذهب للـ Login
///     if (!AuthService.instance.isAuthenticated) {
///       return '/login';
///     }
///     return null;  // اسمح بالدخول
///   },
/// );
/// ```
///
/// 📱 Deep Linking:
///
/// ```dart
/// // في main.dart:
/// final router = GoRouter(
///   initialLocation: '/splash',
///   routes: [/* ... */],
/// );
///
/// // عند فتح التطبيق من رابط:
/// // psga://trips/trip_123
/// // يذهب مباشرة لصفحة تفاصيل الرحلة
/// ```
///
/// 🎨 Navigation Transitions (انتقالات مخصصة):
///
/// ```dart
/// GoRoute(
///   path: '/details',
///   pageBuilder: (context, state) {
///     return CustomTransitionPage(
///       child: DetailsPage(),
///       transitionsBuilder: (context, animation, secondaryAnimation, child) {
///         // Slide من اليمين
///         const begin = Offset(1.0, 0.0);
///         const end = Offset.zero;
///         final tween = Tween(begin: begin, end: end);
///         final offsetAnimation = animation.drive(tween);
///
///         return SlideTransition(
///           position: offsetAnimation,
///           child: child,
///         );
///       },
///     );
///   },
/// );
/// ```
///
/// 🔄 Navigation from BLoC:
///
/// ```dart
/// class LoginBloc extends Bloc<LoginEvent, LoginState> {
///   LoginBloc() : super(LoginInitial()) {
///     on<LoginButtonPressed>((event, emit) async {
///       emit(LoginLoading());
///
///       try {
///         final success = await AuthService.instance.login(
///           event.email,
///           event.password
///         );
///
///         if (success) {
///           emit(LoginSuccess());
///           // التنقل من BLoC! ✅
///           NavigationService.navigateAndReplace('/home');
///         } else {
///           emit(LoginFailure('فشل تسجيل الدخول'));
///         }
///       } catch (e) {
///         emit(LoginFailure(e.toString()));
///       }
///     });
///   }
/// }
/// ```
///
/// 🎯 Named Parameters في Navigation:
///
/// ```dart
/// // تعريف Route مع parameters:
/// GoRoute(
///   path: '/trip/:id',
///   builder: (context, state) {
///     final tripId = state.pathParameters['id']!;
///     return TripDetailsPage(tripId: tripId);
///   },
/// );
///
/// // الاستخدام:
/// NavigationService.navigateTo('/trip/trip_123');
/// ```
///
/// 📊 Navigation Analytics:
///
/// ```dart
/// class AnalyticsNavigationObserver extends NavigatorObserver {
///   @override
///   void didPush(Route route, Route? previousRoute) {
///     // تسجيل في Analytics
///     FirebaseAnalytics.instance.logScreenView(
///       screenName: route.settings.name,
///     );
///   }
/// }
///
/// // في MaterialApp:
/// MaterialApp(
///   navigatorObservers: [
///     AnalyticsNavigationObserver(),
///   ],
/// );
/// ```
/// ═══════════════════════════════════════════════════════════════════════════
