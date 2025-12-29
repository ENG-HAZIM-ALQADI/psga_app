import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/sync/sync_manager.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/usecases/create_route_usecase.dart';
import '../../domain/usecases/get_user_routes_usecase.dart';
import '../../domain/usecases/update_route_usecase.dart';
import '../../domain/usecases/delete_route_usecase.dart';
import '../../domain/repositories/route_repository.dart';
import 'route_event.dart';
import 'route_state.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ RouteBloc - إدارة حالة المسارات (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// إدارة دورة حياة المسارات (Routes):
/// - تحميل المسارات المحفوظة
/// - إنشاء مسار جديد
/// - تعديل مسار موجود
/// - حذف مسار
/// - وضع/إزالة مسار من المفضلة
/// - البحث عن مسار
/// - تحميل المسارات المفضلة فقط
///
/// العلاقة مع TripBloc:
/// ```
/// المستخدم يختار مسار → يضغط "ابدأ الرحلة"
///                      ↓
///                   TripBloc يبدأ الرحلة على هذا المسار
/// ```
///
/// التكامل مع SyncManager:
/// عند تحميل المسارات، يحاول الوصول للبيانات المحلية أولاً
/// ثم يمزامن مع Firebase في الخلفية (Offline-First Strategy)

class RouteBloc extends Bloc<RouteEvent, RouteState> {
  /// 🔗 الاعتماديات (Use Cases و Repository)
  final CreateRouteUseCase createRouteUseCase;           /// إنشاء مسار جديد
  final GetUserRoutesUseCase getUserRoutesUseCase;       /// جلب مسارات المستخدم
  final UpdateRouteUseCase updateRouteUseCase;           /// تعديل مسار
  final DeleteRouteUseCase deleteRouteUseCase;           /// حذف مسار
  final RouteRepository routeRepository;                 /// وصول مباشر للـ Repository

  /// Constructor - تهيئة RouteBloc
  RouteBloc({
    required this.createRouteUseCase,
    required this.getUserRoutesUseCase,
    required this.updateRouteUseCase,
    required this.deleteRouteUseCase,
    required this.routeRepository,
  }) : super(RoutesInitial()) {
    /// ربط الأحداث بمعالجاتها
    on<LoadRoutes>(_onLoadRoutes);              /// تحميل المسارات
    on<CreateRoute>(_onCreateRoute);            /// إنشاء مسار جديد
    on<UpdateRoute>(_onUpdateRoute);            /// تعديل مسار
    on<DeleteRoute>(_onDeleteRoute);            /// حذف مسار
    on<ToggleFavorite>(_onToggleFavorite);      /// إضافة/إزالة من المفضلة
    on<SearchRoutes>(_onSearchRoutes);          /// البحث عن مسار
    on<LoadFavoriteRoutes>(_onLoadFavoriteRoutes); /// تحميل المسارات المفضلة
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📥 معالج الحدث: تحميل جميع المسارات (_onLoadRoutes)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// استراتيجية Offline-First:
  /// 1️⃣ جلب البيانات المحلية من Hive (فوراً - بدون انتظار)
  /// 2️⃣ عرضها للمستخدم
  /// 3️⃣ مزامنة مع Firebase في الخلفية (إذا كان الإنترنت متوفر)
  /// 4️⃣ تحديث الواجهة بالبيانات الأحدث
  
  Future<void> _onLoadRoutes(LoadRoutes event, Emitter<RouteState> emit) async {
    /// تحسين الأداء: تجنب الوميض
    /// إذا كانت البيانات محملة بالفعل، لا نعرض حالة Loading
    if (state is! RoutesLoaded) {
      emit(RoutesLoading());
    }
    
    AppLogger.info('[RouteBloc] جاري تحميل المسارات...', name: 'RouteBloc');

    try {
      /// 1️⃣ محاولة جلب البيانات المحلية أولاً (Hive)
      /// هذا يجعل التطبيق يستجيب بسرعة حتى لو كان الإنترنت بطيء
      final localResult = await getUserRoutesUseCase(event.userId);
      localResult.fold(
        /// فشل تحميل من Hive (قد يكون Hive فارغ)
        (failure) => null,
        /// نجح تحميل من Hive
        (routes) {
          if (routes.isNotEmpty) {
            /// عرض البيانات المحلية للمستخدم فوراً
            emit(RoutesLoaded(routes: routes));
          }
        },
      );

      /// 2️⃣ مزامنة مع Firebase في الخلفية
      /// هذا يحدث فقط إذا كانت البيانات المحلية فارغة
      if (state is! RoutesLoaded) {
         /// البيانات المحلية فارغة، نقوم بمزامنة كاملة
         await SyncManager.instance.fullSync();
         final syncResult = await getUserRoutesUseCase(event.userId);
         syncResult.fold(
           (failure) => emit(RoutesError(failure.message)),
           (routes) => emit(RoutesLoaded(routes: routes)),
         );
      } else {
        /// البيانات المحلية موجودة بالفعل
        /// المزامنة ستحدث دورياً عبر SyncManager
        AppLogger.info('[RouteBloc] البيانات متوفرة محلياً، تخطي المزامنة الفورية', name: 'RouteBloc');
      }
    } catch (e) {
      /// خطأ غير متوقع
      AppLogger.error('[RouteBloc] خطأ: $e', name: 'RouteBloc');
      emit(RoutesError(e.toString()));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ✨ معالج الحدث: إنشاء مسار جديد (_onCreateRoute)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// ما يحدث:
  /// 1️⃣ حفظ المسار في Hive (محلياً فوراً)
  /// 2️⃣ محاولة حفظ في Firebase (في الخلفية)
  /// 3️⃣ تحديث قائمة المسارات في الواجهة
  
  Future<void> _onCreateRoute(CreateRoute event, Emitter<RouteState> emit) async {
    final currentState = state;
    emit(RoutesLoading());

    /// استدعاء useCase لإنشاء المسار
    final result = await createRouteUseCase(event.route);

    result.fold(
      /// ❌ فشل الإنشاء
      (failure) {
        AppLogger.error('[RouteBloc] فشل إنشاء المسار: ${failure.message}', name: 'RouteBloc');
        emit(RoutesError(failure.message));
      },
      /// ✅ نجح الإنشاء
      (route) {
        AppLogger.success('[RouteBloc] تم إنشاء المسار بنجاح', name: 'RouteBloc');
        
        /// إضافة المسار الجديد للقائمة الموجودة
        if (currentState is RoutesLoaded) {
          emit(RoutesLoaded(routes: [...currentState.routes, route]));
        }
        
        /// عرض رسالة نجاح
        emit(const RouteOperationSuccess('تم إنشاء المسار بنجاح'));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ✏️ معالج الحدث: تعديل مسار موجود (_onUpdateRoute)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// ما يحدث:
  /// 1️⃣ تحديث المسار في Hive
  /// 2️⃣ تحديث في Firebase في الخلفية
  /// 3️⃣ تحديث المسار في القائمة (استبدال القديم بالجديد)
  
  Future<void> _onUpdateRoute(UpdateRoute event, Emitter<RouteState> emit) async {
    final currentState = state;
    
    /// استدعاء useCase لتحديث المسار
    final result = await updateRouteUseCase(event.route);

    result.fold(
      /// ❌ فشل التحديث
      (failure) {
        emit(RoutesError(failure.message));
      },
      /// ✅ نجح التحديث
      (updatedRoute) {
        /// استبدال المسار القديم بالمسار المحدث في القائمة
        if (currentState is RoutesLoaded) {
          final updatedRoutes = currentState.routes.map((r) {
            return r.id == updatedRoute.id ? updatedRoute : r;
          }).toList();
          emit(RoutesLoaded(routes: updatedRoutes));
        }
        
        /// عرض رسالة نجاح
        emit(const RouteOperationSuccess('تم تحديث المسار بنجاح'));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🗑️ معالج الحدث: حذف مسار (_onDeleteRoute)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// تحذير ⚠️: الحذف نهائي!
  /// 1️⃣ حذف من Hive
  /// 2️⃣ حذف من Firebase
  /// 3️⃣ إزالة المسار من القائمة
  
  Future<void> _onDeleteRoute(DeleteRoute event, Emitter<RouteState> emit) async {
    final currentState = state;

    /// استدعاء useCase لحذف المسار
    final result = await deleteRouteUseCase(event.routeId, event.userId);

    result.fold(
      /// ❌ فشل الحذف
      (failure) {
        emit(RoutesError(failure.message));
      },
      /// ✅ نجح الحذف
      (_) {
        /// إزالة المسار من القائمة
        if (currentState is RoutesLoaded) {
          final updatedRoutes = currentState.routes
              .where((r) => r.id != event.routeId)
              .toList();
          emit(RoutesLoaded(routes: updatedRoutes));
        }
        
        /// عرض رسالة نجاح
        emit(const RouteOperationSuccess('تم حذف المسار بنجاح'));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⭐ معالج الحدث: إضافة/إزالة من المفضلة (_onToggleFavorite)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// السلوك:
  /// - إذا كان مفضل: أزله
  /// - إذا لم يكن مفضل: أضفه
  
  Future<void> _onToggleFavorite(ToggleFavorite event, Emitter<RouteState> emit) async {
    final currentState = state;

    /// استدعاء Repository لتبديل حالة المفضلة
    final result = await routeRepository.toggleFavorite(event.routeId);

    result.fold(
      /// ❌ فشل التبديل
      (failure) {
        emit(RoutesError(failure.message));
      },
      /// ✅ نجح التبديل
      (_) {
        /// تحديث حالة المسار في القائمة
        if (currentState is RoutesLoaded) {
          final updatedRoutes = currentState.routes.map((r) {
            if (r.id == event.routeId) {
              /// قلب حالة isFavorite (true ↔ false)
              return r.copyWith(isFavorite: !r.isFavorite);
            }
            return r;
          }).toList();
          emit(RoutesLoaded(routes: updatedRoutes));
        }
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔍 معالج الحدث: البحث عن مسار (_onSearchRoutes)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// هذه الدالة:
  /// ✅ لا تحتاج async (عملية سريعة جداً - بحث محلي)
  /// ✅ تبحث في البيانات الموجودة في الذاكرة
  /// ✅ لا تتصل بـ Firebase
  ///
  /// الخطوات:
  /// 1️⃣ إذا كان query فارغ: عرض جميع المسارات
  /// 2️⃣ إذا كان query فيه نص:
  ///    - البحث في اسم المسار
  ///    - البحث في الوصف
  ///    - عرض النتائج فقط
  
  void _onSearchRoutes(SearchRoutes event, Emitter<RouteState> emit) {
    final currentState = state;
    
    if (currentState is RoutesLoaded) {
      if (event.query.isEmpty) {
        /// إذا كان البحث فارغ: عرض جميع المسارات
        emit(RoutesLoaded(routes: currentState.routes));
      } else {
        /// تصفية المسارات بناءً على الاستعلام
        final filtered = currentState.routes.where((route) {
          /// البحث في الاسم أو الوصف
          return route.name.toLowerCase().contains(event.query.toLowerCase()) ||
              (route.description?.toLowerCase().contains(event.query.toLowerCase()) ?? false);
        }).toList();
        
        /// عرض النتائج المصفاة (مع الاحتفاظ بالقائمة الأصلية)
        emit(currentState.copyWith(filteredRoutes: filtered));
      }
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⭐ معالج الحدث: تحميل المسارات المفضلة فقط (_onLoadFavoriteRoutes)
  /// ═══════════════════════════════════════════════════════════════════════════
  /// تحميل قائمة تحتوي على المسارات المفضلة فقط
  
  Future<void> _onLoadFavoriteRoutes(LoadFavoriteRoutes event, Emitter<RouteState> emit) async {
    /// عرض حالة التحميل
    emit(RoutesLoading());

    /// استدعاء Repository للحصول على المسارات المفضلة
    final result = await routeRepository.getFavoriteRoutes(event.userId);

    result.fold(
      /// ❌ فشل التحميل
      (failure) => emit(RoutesError(failure.message)),
      /// ✅ نجح التحميل
      (routes) => emit(RoutesLoaded(routes: routes)),
    );
  }
}
