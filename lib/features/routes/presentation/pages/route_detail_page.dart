import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/presentation/bloc/bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_state.dart';
import 'package:psga_app/features/trips/presentation/bloc/bloc.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/presentation/bloc/bloc.dart';
import 'package:psga_app/features/routes/presentation/widgets/waypoint_item.dart';
import 'package:psga_app/features/maps/presentation/widgets/map_widget.dart';
import 'package:psga_app/features/maps/presentation/widgets/map_helpers.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// صفحة تفاصيل المسار
class RouteDetailPage extends StatefulWidget {
  final String routeId;

  const RouteDetailPage({
    required this.routeId,
    super.key,
  });

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  bool _isStartingTrip = false; // لمنع الضغط المتكرر
  bool _hasNavigatedToActiveTrip = false; // منع التنقل المتكرر لشاشة الرحلة
  String _loadingMessage = ''; // رسالة التحميل الديناميكية - تُهيَّأ في didChangeDependencies

  @override
  void initState() {
    super.initState();
    // التحقق من وجود رحلة نشطة عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForActiveTrip();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadingMessage.isEmpty) {
      _loadingMessage = AppLocalizations.of(context)!.loadingCheckingMsg;
    }
  }

  void _checkForActiveTrip() {
    if (_hasNavigatedToActiveTrip) return;
    final tripState = context.read<TripBloc>().state;
    if (tripState is TripActive) {
      AppLogger.info('[RouteDetail] يوجد رحلة نشطة - الانتقال لصفحة الرحلة');
      _hasNavigatedToActiveTrip = true;
      Navigator.pushReplacementNamed(context, '/active-trip');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // الاستماع لحالة ContactBloc للتحقق من جهات الاتصال
        BlocListener<ContactBloc, ContactState>(
          listener: (context, contactState) {
            if (!_isStartingTrip) return;
            
            if (contactState is ContactsExistCheckState) {
              if (contactState.hasContacts) {
                AppLogger.success('[RouteDetail] تم العثور على ${contactState.contactCount} جهة اتصال');
                // ✅ تحديث رسالة التحميل للخطوة 2
                setState(() => _loadingMessage = AppLocalizations.of(context)!.loadingLocatingMsg);
                _validateLocationAndStartTrip();
              } else {
                AppLogger.warning('[RouteDetail] لا توجد جهات اتصال');
                setState(() => _isStartingTrip = false);
                _showNoContactsDialog();
              }
            }
          },
        ),
        // الاستماع لحالة TripBloc للتحقق من الموقع وبدء الرحلة
        BlocListener<TripBloc, TripState>(
          listener: (context, tripState) {
            // ✅ TripActive يُعالَج مرة واحدة فقط (يمنع التكرار من LoadActiveTripEvent)
            if (tripState is TripActive && !_hasNavigatedToActiveTrip) {
              AppLogger.success('[RouteDetail] تم بدء الرحلة بنجاح - الانتقال لشاشة الرحلة النشطة');
              _hasNavigatedToActiveTrip = true;
              _isStartingTrip = false;
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/active-trip');
              }
              return;
            }
            
            // بقية الحالات تحتاج _isStartingTrip = true
            if (!_isStartingTrip) return;
            
            if (tripState is TripLoading) {
              setState(() => _loadingMessage = AppLocalizations.of(context)!.loadingStartingTripMsg);
            } else if (tripState is TripUserFarFromStartPoint) {
              AppLogger.warning('[RouteDetail] المستخدم بعيد عن نقطة البداية');
              setState(() => _isStartingTrip = false);
              _showLocationValidationDialog(tripState);
            } else if (tripState is TripActiveTripExists) {
              AppLogger.warning('[RouteDetail] يوجد رحلة نشطة: ${tripState.activeTripId}');
              setState(() => _isStartingTrip = false);
              if (mounted) {
                _showActiveTripExistsDialog(
                  context,
                  activeTripId: tripState.activeTripId,
                  routeId: tripState.routeId,
                );
              }
            } else if (tripState is TripError) {
              setState(() {
                _isStartingTrip = false;
                _loadingMessage = AppLocalizations.of(context)!.loadingCheckingMsg;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tripState.message),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        ),
        // الاستماع لحذف المسار
        BlocListener<RoutesBloc, RoutesState>(
          listener: (context, state) {
            if (state is RouteDeleted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.routeDeleted),
                  backgroundColor: AppColors.green,
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<RoutesBloc, RoutesState>(
        builder: (context, state) {
          if (state is! RoutesLoaded) {
            return Scaffold(
              appBar: AppBar(title: Text(AppLocalizations.of(context)!.routes)),
              body: LoadingWidget(message: AppLocalizations.of(context)!.loadingGeneralMsg),
            );
          }

          final route = state.routes.firstWhere(
            (r) => r.id == widget.routeId,
            orElse: () => throw Exception('المسار غير موجود'),
          );

          return Scaffold(
          appBar: AppBar(
            title: Text(route.name),
            actions: [
              IconButton(
                icon: Icon(
                  route.isFavorite ? Icons.star : Icons.star_border,
                  color: route.isFavorite ? Colors.amber : null,
                ),
                onPressed: () {
                  context.read<RoutesBloc>().add(
                        ToggleFavoriteEvent(routeId: route.id),
                      );
                },
                tooltip: route.isFavorite ? AppLocalizations.of(context)!.removeFromFavorites : AppLocalizations.of(context)!.addToFavorites,
              ),
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(
                          route.status == RouteStatus.active
                              ? Icons.archive
                              : Icons.unarchive,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          route.status == RouteStatus.active
                              ? AppLocalizations.of(context)!.archiveRoute
                              : AppLocalizations.of(context)!.activateRoute,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(context, route);
                  } else if (value == 'edit') {
                    Navigator.pushNamed(
                      context,
                      '/create-route',
                      arguments: route,
                    );
                  } else if (value == 'status') {
                    _toggleStatus(context, route);
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // خريطة (Placeholder)
                _MapPlaceholder(route: route),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الوصف
                      if (route.description != null) ...[
                        Text(
                          route.description!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // بطاقة الإحصائيات
                      _StatsCard(route: route),

                      const SizedBox(height: 24),

                      // عنوان النقاط
                      Text(
                        AppLocalizations.of(context)!.routeWaypointsCount(route.waypoints.length.toString()),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),

                      // قائمة النقاط
                      ...route.waypoints.asMap().entries.map((entry) {
                        return WaypointItem(
                          waypoint: entry.value,
                          index: entry.key + 1,
                          isFirst: entry.key == 0,
                          isLast: entry.key == route.waypoints.length - 1,
                        );
                      }),

                      const SizedBox(height: 80), // مسافة للـ FAB
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: BlocBuilder<TripBloc, TripState>(
            builder: (context, tripState) {
              // إذا كانت هناك رحلة نشطة - إخفاء الزر
              if (tripState is TripActive) {
                return const SizedBox.shrink();
              }
              
              // ✅ تطوير 1: إظهار Loading أثناء عملية التحقق وبدء الرحلة
              if (_isStartingTrip || tripState is TripLoading) {
                return FloatingActionButton.extended(
                  heroTag: 'start_trip_loading_fab',
                  icon: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  label: Text(_loadingMessage),
                  backgroundColor: AppColors.green.withOpacity(0.7),
                  onPressed: null,
                );
              }
              
              return FloatingActionButton.extended(
                heroTag: 'start_trip_fab',
                icon: const Icon(Icons.play_arrow),
                label: Text(AppLocalizations.of(context)!.startTrip),
                backgroundColor: AppColors.green,
                onPressed: () {
                  _startTrip(context, route);
                },
              );
            },
          ),
        );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, RouteEntity route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteRoute),
        content: Text(AppLocalizations.of(context)!.deleteRouteConfirmMsg(route.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<RoutesBloc>().add(
                    DeleteRouteEvent(routeId: route.id),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(BuildContext context, RouteEntity route) {
    final newStatus = route.status == RouteStatus.active
        ? RouteStatus.archived
        : RouteStatus.active;

    context.read<RoutesBloc>().add(
          UpdateRouteEvent(route: route.copyWith(status: newStatus)),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == RouteStatus.active
              ? AppLocalizations.of(context)!.routeActivatedMsg
              : AppLocalizations.of(context)!.routeArchivedMsg,
        ),
        backgroundColor: AppColors.green,
      ),
    );
  }

  /// بدء رحلة - مع التحقق الشامل من جهات الاتصال والموقع
  /// Single Responsibility: إدارة عملية بدء الرحلة مع جميع التحققات المطلوبة
  Future<void> _startTrip(BuildContext context, RouteEntity route) async {
    // منع الضغط المتكرر
    if (_isStartingTrip) {
      AppLogger.info('[RouteDetail] عملية بدء الرحلة جارية بالفعل - تجاهل الطلب');
      return;
    }
    
    // التحقق من أن المسار يحتوي على نقطتين على الأقل
    if (route.waypoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.routeNeedsMinPoints),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // التحقق من المصادقة
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.loginRequired2),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final userId = authState.user.id;
    setState(() {
      _isStartingTrip = true;
      _loadingMessage = AppLocalizations.of(context)!.loadingCheckContactsMsg;
    });
    
    AppLogger.info('[RouteDetail] بدء عملية التحقق قبل بدء الرحلة: ${route.name}');
    
    // الخطوة 1: التحقق من وجود جهات اتصال
    AppLogger.info('[RouteDetail] الخطوة 1: التحقق من جهات الاتصال');
    context.read<ContactBloc>().add(CheckContactsExistEvent(userId: userId));
  }

  /// التحقق من الموقع وبدء الرحلة
  /// يتم استدعاؤها بعد التأكد من وجود جهات اتصال
  Future<void> _validateLocationAndStartTrip() async {
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      setState(() => _isStartingTrip = false);
      return;
    }

    final routesState = context.read<RoutesBloc>().state;
    if (routesState is! RoutesLoaded) {
      setState(() => _isStartingTrip = false);
      return;
    }

    final route = routesState.routes.firstWhere(
      (r) => r.id == widget.routeId,
      orElse: () {
        setState(() => _isStartingTrip = false);
        return throw Exception('المسار غير موجود');
      },
    );

    AppLogger.info('[RouteDetail] الخطوة 2: التحقق من الموقع');
    
    // إرسال event للتحقق من الموقع
    context.read<TripBloc>().add(
      ValidateUserLocationEvent(
        userId: authState.user.id,
        routeId: route.id,
      ),
    );
  }

  /// عرض dialog عندما لا يوجد جهات اتصال
  void _showNoContactsDialog() {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.contacts_rounded,
                  color: cs.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.contactRequiredTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contactRequiredBody,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.contactRequiredHint,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurface.withOpacity(0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogger.info('[RouteDetail] المستخدم اختار إلغاء');
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(l10n.addContactBtn),
            onPressed: () {
              AppLogger.info('[RouteDetail] الانتقال لصفحة جهات الاتصال');
              Navigator.pop(dialogContext);
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                Navigator.pushNamed(
                  context,
                  '/contacts',
                  arguments: authState.user.id,
                );
              }
            },
          ),
        ],
      );
      },
    );
  }

  /// عرض dialog عندما يوجد رحلة نشطة بالفعل
  /// يتيح للمستخدم الاختيار: متابعة الرحلة النشطة أو إنهائها وبدء رحلة جديدة
  void _showActiveTripExistsDialog(
    BuildContext context, {
    required String activeTripId,
    required String routeId,
  }) {
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    final userId = authState.user.id;

    final lActive = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF7C4A00).withOpacity(0.4)
                      : const Color(0xFFFFE0B2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_run_rounded,
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lActive.activeTripTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            lActive.activeTripBody,
            style: TextStyle(fontSize: 15, height: 1.6, color: cs.onSurface.withOpacity(0.85)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppLogger.info('[RouteDetail] المستخدم اختار إلغاء');
                Navigator.pop(dialogContext);
              },
              child: Text(
                lActive.cancel,
                style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text(lActive.continueActiveTrip),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary.withOpacity(0.5)),
              ),
              onPressed: () {
                AppLogger.info('[RouteDetail] الانتقال للرحلة النشطة الحالية');
                Navigator.pop(dialogContext);
                Navigator.pushReplacementNamed(context, '/active-trip');
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(lActive.startNewTrip),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[isDark ? 700 : 600],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                AppLogger.info('[RouteDetail] إنهاء الرحلة الحالية وبدء رحلة جديدة');
                Navigator.pop(dialogContext);
                setState(() => _isStartingTrip = true);
                context.read<TripBloc>().add(
                  StartTripEvent(
                    userId: userId,
                    routeId: routeId,
                    forceEndActiveTrip: true,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// عرض dialog عندما يكون المستخدم بعيداً عن نقطة البداية
  void _showLocationValidationDialog(TripUserFarFromStartPoint state) {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    final distanceKm = (state.distanceFromStart / 1000).toStringAsFixed(2);
    final distanceM = state.distanceFromStart.toStringAsFixed(0);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF7C4A00).withOpacity(0.4)
                      : const Color(0xFFFFE0B2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.locationFarTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم المسار
                Text(
                  l10n.routeLabel(state.routeName),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // بطاقة المسافة - لون برتقالي متكيف
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF7C4A00).withOpacity(0.2)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFFB74D).withOpacity(0.4)
                          : const Color(0xFFFFCC80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.straighten_rounded,
                        color: isDark
                            ? const Color(0xFFFFB74D)
                            : const Color(0xFFE65100),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.locationFarBody(distanceM, distanceKm),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // بطاقة المعلومات - لون أزرق متكيف
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.startFromCurrentLocation,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppLogger.info('[RouteDetail] المستخدم اختار إلغاء');
                Navigator.pop(dialogContext);
              },
              child: Text(
                l10n.cancel,
                style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(l10n.startFromHere),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[isDark ? 700 : 600],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                AppLogger.info('[RouteDetail] المستخدم اختار البدء من الموقع الحالي');
                _isStartingTrip = true;
                Navigator.pop(dialogContext);
                context.read<TripBloc>().add(
                  StartTripFromCurrentLocationEvent(
                    userId: state.userId,
                    routeId: state.routeId,
                  ),
                );
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: Text(l10n.newRoute),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              onPressed: () async {
                AppLogger.info('[RouteDetail] المستخدم اختار إنشاء مسار جديد');
                Navigator.pop(dialogContext);
                final locationService = LocationService.instance;
                final currentLocation = await locationService.getCurrentLocation();
                if (!mounted) return;
                if (currentLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.locationFailed),
                      backgroundColor: cs.error,
                    ),
                  );
                  return;
                }
                await Navigator.pushReplacementNamed(
                  context,
                  '/create-route',
                  arguments: {
                    'autoFillStartLocation': true,
                    'startLocation': currentLocation,
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// بطاقة الإحصائيات
class _StatsCard extends StatelessWidget {
  final RouteEntity route;

  const _StatsCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final distance = route.calculateTotalDistance();
    final distanceKm = (distance / 1000).toStringAsFixed(1);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(
              icon: Icons.location_on,
              label: AppLocalizations.of(context)!.statWaypoints,
              value: '${route.waypoints.length}',
              color: Theme.of(context).colorScheme.primary,
            ),
            const Divider(height: 24),
            _StatRow(
              icon: Icons.straighten,
              label: AppLocalizations.of(context)!.statTotalDistance,
              value: '$distanceKm ${AppLocalizations.of(context)!.distanceKmUnit}',
              color: Theme.of(context).colorScheme.primary,
            ),
            if (route.estimatedDuration != null) ...[
              const Divider(height: 24),
              _StatRow(
                icon: Icons.access_time,
                label: AppLocalizations.of(context)!.statEstimatedTime,
                value: '~${route.estimatedDuration} ${AppLocalizations.of(context)!.durationMinutes}',
                color: AppColors.green,
              ),
            ],
            if (route.checkpointCount > 0) ...[
              const Divider(height: 24),
              _StatRow(
                icon: Icons.flag,
                label: AppLocalizations.of(context)!.statCheckpoints,
                value: '${route.checkpointCount}',
                color: AppColors.gold,
              ),
            ],
            const Divider(height: 24),
            _StatRow(
              icon: Icons.circle,
              label: AppLocalizations.of(context)!.statRouteStatus,
              value: _getStatusLabel(context, route.status),
              color: _getStatusColor(context, route.status),
            ),
            const Divider(height: 24),
            _StatRow(
              icon: Icons.calendar_today,
              label: AppLocalizations.of(context)!.statCreatedAt,
              value: _formatDate(route.createdAt),
              color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(BuildContext context, RouteStatus status) {
    switch (status) {
      case RouteStatus.active:
        return AppLocalizations.of(context)!.statusActive;
      case RouteStatus.inactive:
        return AppLocalizations.of(context)!.statusInactive;
      case RouteStatus.archived:
        return AppLocalizations.of(context)!.statusArchived;
    }
  }

  Color _getStatusColor(BuildContext context, RouteStatus status) {
    switch (status) {
      case RouteStatus.active:
        return AppColors.green;
      case RouteStatus.inactive:
        return Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary;
      case RouteStatus.archived:
        return Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// صف إحصائية
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// عرض الخريطة مع المسار
class _MapPlaceholder extends StatefulWidget {
  final RouteEntity route;

  const _MapPlaceholder({required this.route});

  @override
  State<_MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<_MapPlaceholder> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _setupMapElements();
  }

  void _setupMapElements() {
    // إنشاء Markers والPolylines للمسار
    final helpers = MapHelpers.createRouteMarkers(
      start: widget.route.startLocation!,
      end: widget.route.endLocation!,
      waypoints: widget.route.waypoints.sublist(1, widget.route.waypoints.length - 1),
    );

    // إضافة Polyline
    final polyline = MapHelpers.createPlannedRoutePolyline(
      points: widget.route.waypoints.map((w) => w.location).toList(),
    );

    setState(() {
      _markers = helpers;
      _polylines = {polyline};
    });
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      Navigator.pop(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _FullscreenMap(
            route: widget.route,
            markers: _markers,
            polylines: _polylines,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.route.waypoints.length < 2) {
      return Container(
        height: 250,
        color: Colors.grey[200],
        child: Center(
          child: Text(AppLocalizations.of(context)!.routeNeedsPoints),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          MapWidget(
            initialLocation: widget.route.startLocation!,
            initialZoom: 13,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              // تكبير الخريطة لعرض جميع النقاط
              _fitBounds();
            },
          ),
          
          // زر ملء الشاشة - يتكيّف مع الثيم (فاتح/داكن)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              elevation: 4,
              child: InkWell(
                onTap: _toggleFullscreen,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.fullscreen,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

          // معلومات المسار - تتكيّف مع الثيم
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickInfo(
                    context,
                    Icons.route,
                    '${widget.route.waypoints.length} ${AppLocalizations.of(context)!.quickInfoPoints}',
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  if (widget.route.estimatedDistance != null)
                    _buildQuickInfo(
                      context,
                      Icons.straighten,
                      '${(widget.route.estimatedDistance! / 1000).toStringAsFixed(1)} ${AppLocalizations.of(context)!.distanceKmUnit}',
                    ),
                  if (widget.route.estimatedDuration != null) ...[
                    Container(
                      width: 1,
                      height: 20,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                    _buildQuickInfo(
                      context,
                      Icons.access_time,
                      '${widget.route.estimatedDuration} د',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _fitBounds() async {
    if (_controller == null) return;
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    final bounds = MapHelpers.calculateBounds(
      widget.route.waypoints.map((w) => w.location).toList(),
    );

    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    } catch (e) {
      // في حالة الخطأ، استخدم zoom ثابت
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            widget.route.startLocation!.latitude,
            widget.route.startLocation!.longitude,
          ),
          13,
        ),
      );
    }
  }
}

/// خريطة ملء الشاشة
class _FullscreenMap extends StatefulWidget {
  final RouteEntity route;
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  const _FullscreenMap({
    required this.route,
    required this.markers,
    required this.polylines,
  });

  @override
  State<_FullscreenMap> createState() => _FullscreenMapState();
}

class _FullscreenMapState extends State<_FullscreenMap> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMapTypeDialog,
            tooltip: AppLocalizations.of(context)!.mapType,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            initialLocation: widget.route.startLocation!,
            initialZoom: 13,
            markers: widget.markers,
            polylines: widget.polylines,
            mapType: _mapType,
            myLocationEnabled: true,
            onMapCreated: (controller) {
              _controller = controller;
              _fitBounds();
            },
          ),

          // معلومات المسار
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.route.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfo(
                          context,
                          Icons.route,
                          AppLocalizations.of(context)!.fsInfoPoints,
                          '${widget.route.waypoints.length}',
                        ),
                        if (widget.route.estimatedDistance != null)
                          _buildInfo(
                            context,
                            Icons.straighten,
                            AppLocalizations.of(context)!.fsInfoDistance,
                            '${(widget.route.estimatedDistance! / 1000).toStringAsFixed(1)} كم',
                          ),
                        if (widget.route.estimatedDuration != null)
                          _buildInfo(
                            context,
                            Icons.access_time,
                            AppLocalizations.of(context)!.fsInfoTime,
                            '${widget.route.estimatedDuration} د',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.mapType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeOption(AppLocalizations.of(context)!.mapTypeNormal, MapType.normal),
            _buildMapTypeOption(AppLocalizations.of(context)!.mapTypeSatellite, MapType.satellite),
            _buildMapTypeOption(AppLocalizations.of(context)!.mapTypeTerrain, MapType.terrain),
            _buildMapTypeOption(AppLocalizations.of(context)!.mapTypeHybrid, MapType.hybrid),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(String title, MapType type) {
    return ListTile(
      title: Text(title),
      leading: Radio<MapType>(
        value: type,
        groupValue: _mapType,
        onChanged: (value) {
          if (value != null) {
            setState(() => _mapType = value);
            Navigator.pop(context);
          }
        },
      ),
      onTap: () {
        setState(() => _mapType = type);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _fitBounds() async {
    if (_controller == null) return;
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    final bounds = MapHelpers.calculateBounds(
      widget.route.waypoints.map((w) => w.location).toList(),
    );

    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } catch (e) {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            widget.route.startLocation!.latitude,
            widget.route.startLocation!.longitude,
          ),
          13,
        ),
      );
    }
  }
}
