import 'dart:async';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/trips/presentation/bloc/bloc.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/presentation/widgets/deviation_alert_widget.dart';
import 'package:psga_app/features/trips/presentation/widgets/deviation_countdown_widget.dart';
import 'package:psga_app/features/trips/presentation/widgets/trip_controls_widget.dart';
import 'package:psga_app/features/trips/presentation/widgets/trip_info_card.dart';
import 'package:psga_app/features/trips/presentation/widgets/trip_stats_widget.dart';
import 'package:psga_app/features/trips/presentation/widgets/waypoint_progress_widget.dart';
import 'package:psga_app/features/maps/presentation/widgets/trip_map_widget.dart';
import 'package:psga_app/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:psga_app/shared/widgets/empty_state_widget.dart';
import 'package:psga_app/shared/widgets/error_widget.dart' as custom;
import 'package:psga_app/shared/widgets/loading_widget.dart';
import 'package:psga_app/shared/widgets/offline_banner.dart';
// إضافة Contacts Integration للتحقق من جهات الاتصال
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_state.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/services/ml_analysis_service.dart';
import 'package:psga_app/features/trips/presentation/widgets/ml_analysis_widget.dart';

/// صفحة الرحلة النشطة
class ActiveTripPage extends StatefulWidget {
  final RouteEntity? routeToStart; // المسار لبدء رحلة جديدة

  const ActiveTripPage({
    this.routeToStart,
    super.key,
  });

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage>
    with WidgetsBindingObserver {
  bool _hasStartedTrip = false;
  bool _isCheckingContacts = false;
  bool _hasShownContactDialog = false;
  bool _wasInCountdown = false;
  String? _activeTripId; // تخزين ID الرحلة النشطة لإنهائها عند إغلاق التطبيق
  
  // 🤖 متغيرات ML Analysis
  ComprehensiveAnalysisResult? _mlAnalysis;
  bool _isAnalyzing = false;
  Timer? _mlAnalysisTimer;

  @override
  void initState() {
    super.initState();
    // ✅ تسجيل مراقب دورة حياة التطبيق لإنهاء الرحلة عند الإغلاق
    WidgetsBinding.instance.addObserver(this);
    
    // إذا تم تمرير مسار، ابدأ رحلة جديدة
    if (widget.routeToStart != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startNewTrip();
      });
    } else {
      // وإلا، حمل الرحلة النشطة الحالية
      _loadActiveTrip();
    }
    
    // 🤖 بدء التحليل الذكي الدوري (كل 30 ثانية)
    _mlAnalysisTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performMLAnalysis(),
    );
    
    // تنفيذ التحليل الأول بعد 10 ثوانٍ من البداية
    Future.delayed(const Duration(seconds: 10), _performMLAnalysis);
  }

  /// ✅ مراقبة دورة حياة التطبيق لإنهاء الرحلة عند الإغلاق أو المسح
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      // إنهاء الرحلة النشطة عند إغلاق أو تعليق التطبيق
      _endTripOnAppClose();
    }
  }

  /// إنهاء الرحلة عند إغلاق التطبيق
  void _endTripOnAppClose() {
    final tripId = _activeTripId;
    if (tripId == null) return;
    AppLogger.warning('[ActiveTripPage] التطبيق يُغلق - إنهاء الرحلة: $tripId');
    try {
      context.read<TripBloc>().add(EndTripEvent(tripId: tripId));
    } catch (e) {
      AppLogger.error('[ActiveTripPage] فشل إنهاء الرحلة عند الإغلاق', e);
    }
  }
  
  @override
  void dispose() {
    // ✅ إلغاء تسجيل مراقب دورة الحياة
    WidgetsBinding.instance.removeObserver(this);
    // 🤖 إلغاء Timer عند الخروج
    _mlAnalysisTimer?.cancel();
    super.dispose();
  }

  void _startNewTrip() {
    if (_hasStartedTrip) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && widget.routeToStart != null) {
      // التحقق من وجود جهات اتصال قبل بدء الرحلة
      AppLogger.info('[ActiveTripPage] التحقق من وجود جهات اتصال قبل بدء الرحلة');
      _checkContactsBeforeStarting(authState.user.id);
    }
  }

  /// التحقق من وجود جهات اتصال قبل بدء الرحلة
  /// Single Responsibility: مسؤول فقط عن التحقق من جهات الاتصال وإظهار التنبيه المناسب
  void _checkContactsBeforeStarting(String userId) {
    // منع الاستدعاء المتكرر
    if (_isCheckingContacts) {
      AppLogger.info('[ActiveTripPage] فحص جهات الاتصال جارٍ بالفعل - تجاهل الطلب المكرر');
      return;
    }
    
    _isCheckingContacts = true;
    AppLogger.info('[ActiveTripPage] بدء فحص جهات الاتصال للمستخدم: $userId');
    
    // إرسال event للتحقق من جهات الاتصال
    context.read<ContactBloc>().add(CheckContactsExistEvent(userId: userId));
  }

  /// بدء الرحلة فعلياً بعد التحقق من جهات الاتصال
  /// يقوم أولاً بالتحقق من موقع المستخدم
  void _proceedWithStartTrip(String userId) {
    if (_hasStartedTrip) return;
    
    _hasStartedTrip = true;
    AppLogger.info('[ActiveTripPage] التحقق من الموقع قبل بدء الرحلة: ${widget.routeToStart!.id}');
    
    // استخدام ValidateUserLocationEvent بدلاً من StartTripEvent مباشرة
    context.read<TripBloc>().add(
      ValidateUserLocationEvent(
        userId: userId,
        routeId: widget.routeToStart!.id,
      ),
    );
  }

  void _loadActiveTrip() {
    // ✅ إذا كانت الرحلة نشطة بالفعل في الـ state → لا نُعيد التحميل
    // (يمنع إعادة بناء TripMapWidget وإعادة ضبط _isMapLoading)
    final currentState = context.read<TripBloc>().state;
    if (currentState is TripActive) {
      AppLogger.info('[ActiveTripPage] الرحلة نشطة بالفعل - لا حاجة للتحميل');
      return;
    }
    
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<TripBloc>().add(
        LoadActiveTripEvent(userId: authState.user.id),
      );
    }
  }

  /// 🤖 تنفيذ التحليل الذكي للرحلة
  /// Single Responsibility: مسؤول فقط عن استدعاء ML Service وتحديث الحالة
  Future<void> _performMLAnalysis() async {
    // منع التحليلات المتعددة المتزامنة
    if (_isAnalyzing || !mounted) return;
    
    final tripState = context.read<TripBloc>().state;
    
    // التحقق من وجود رحلة نشطة
    if (tripState is! TripActive) {
      AppLogger.info('[ActiveTrip] لا توجد رحلة نشطة - تخطي التحليل');
      return;
    }
    
    setState(() => _isAnalyzing = true);
    
    try {
      final currentTrip = tripState.trip;
      
      // التحقق من وجود نقاط GPS كافية للتحليل
      if (currentTrip.locationHistory.length < 3) {
        AppLogger.info('[ActiveTrip] عدد النقاط غير كافٍ للتحليل (${currentTrip.locationHistory.length}/3)');
        return;
      }
      
      AppLogger.info('[ActiveTrip] بدء التحليل الذكي للرحلة: ${currentTrip.id} (${currentTrip.locationHistory.length} نقطة)');
      
      // الحصول على سجل الرحلات السابقة (من Hive/Firebase)
      // ملاحظة: هذا يحتاج UseCase مخصص - حالياً سنستخدم قائمة فارغة
      final tripHistory = <TripEntity>[]; // TODO: جلب من TripRepository
      
      // استدعاء التحليل الشامل
      final result = await MLAnalysisService.instance.comprehensiveAnalysis(
        currentTrip: currentTrip,
        tripHistory: tripHistory,
      );
      
      if (result != null && mounted) {
        setState(() {
          _mlAnalysis = result;
        });
        
        AppLogger.success('[ActiveTrip] تم التحليل - خطر: ${result.overallRiskScore.toStringAsFixed(1)}/100 (${result.alertLevel})');
        
        // إذا كان الخطر عالي أو حرج، تنبيه فوري
        if (result.alertLevel == 'high' || result.alertLevel == 'critical') {
          _handleHighRiskAlert(result);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('[ActiveTrip] فشل التحليل الذكي', e, stackTrace);
      
      // عرض رسالة خطأ خفيفة (لا نوقف التطبيق)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.mlAnalysisFailed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  /// معالجة تنبيه الخطر العالي
  /// يعرض SnackBar مع إمكانية تنفيذ الإجراء الموصى به
  void _handleHighRiskAlert(ComprehensiveAnalysisResult analysis) {
    if (!mounted) return;
    
    AppLogger.warning('[ActiveTrip] خطر عالي مكتشف: ${analysis.alertMessage}');
    
    // عرض تنبيه مرئي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.onError),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                analysis.alertMessage,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.action,
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () => _handleMLAction(analysis),
        ),
      ),
    );
    
    // تشغيل اهتزاز للتنبيه
    HapticFeedback.vibrate();
  }

  /// تنفيذ الإجراء الموصى به من التحليل
  void _handleMLAction(ComprehensiveAnalysisResult analysis) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    
    AppLogger.info('[ActiveTrip] تنفيذ الإجراء الموصى به: ${analysis.recommendedAction}');
    
    switch (analysis.recommendedAction) {
      case 'emergency_alert':
        // تفعيل SOS فوري
        AppLogger.warning('[ActiveTrip] تفعيل SOS - حالة طوارئ!');
        // TODO: تفعيل AlertBloc مع SOS
        // context.read<AlertBloc>().add(SendSOSEvent(userId: userId));
        
        // عرض dialog تأكيد
        _showEmergencyDialog(analysis);
        break;
        
      case 'notify_user':
        // إرسال تنبيه لجهات الاتصال
        AppLogger.info('[ActiveTrip] إرسال تنبيه لجهات الاتصال');
        // TODO: تفعيل AlertBloc مع تنبيه
        // context.read<AlertBloc>().add(
        //   TriggerAlertEvent(
        //     userId: userId,
        //     alertType: AlertType.deviation,
        //     message: analysis.alertMessage,
        //   ),
        // );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sendingAlert),
            duration: const Duration(seconds: 3),
          ),
        );
        break;
        
      case 'monitor':
        // زيادة تردد التحليل (كل 15 ثانية بدلاً من 30)
        AppLogger.info('[ActiveTrip] زيادة تردد التحليل إلى كل 15 ثانية');
        _mlAnalysisTimer?.cancel();
        _mlAnalysisTimer = Timer.periodic(
          const Duration(seconds: 15),
          (_) => _performMLAnalysis(),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.preciseTrackingEnabled),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      default:
        // متابعة عادية
        AppLogger.info('[ActiveTrip] لا يوجد إجراء مطلوب - متابعة عادية');
        break;
    }
  }

  /// عرض dialog تأكيد حالة الطوارئ
  void _showEmergencyDialog(ComprehensiveAnalysisResult analysis) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.emergency, color: Theme.of(context).colorScheme.error, size: 48),
        title: Text(AppLocalizations.of(context)!.emergency),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(analysis.alertMessage),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.sosConfirmMsg,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: تفعيل SOS
              AppLogger.warning('[ActiveTrip] تم تفعيل SOS من قبل المستخدم');
            },
            icon: const Icon(Icons.sos),
            label: Text(AppLocalizations.of(context)!.sos),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! Authenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.tripActive)),
        body: Center(child: Text(AppLocalizations.of(context)!.pleaseLogin)),
      );
    }

    final userId = authState.user.id;
    
    return MultiBlocListener(
      listeners: [
        // الاستماع لحالة التحقق من جهات الاتصال
        BlocListener<ContactBloc, ContactState>(
          listener: (context, contactState) {
            if (contactState is ContactsExistCheckState) {
              // إعادة تعيين flag الفحص
              _isCheckingContacts = false;
              
              if (contactState.hasContacts) {
                // يوجد جهات اتصال - يمكن بدء الرحلة
                AppLogger.success('[ActiveTripPage] تم العثور على ${contactState.contactCount} جهة اتصال - المتابعة لبدء الرحلة');
                _hasShownContactDialog = false; // إعادة تعيين flag
                _proceedWithStartTrip(userId);
              } else {
                // لا يوجد جهات اتصال - عرض تنبيه مرة واحدة فقط
                if (!_hasShownContactDialog) {
                  AppLogger.warning('[ActiveTripPage] لا يوجد جهات اتصال - يجب إضافة جهة اتصال واحدة على الأقل');
                  _hasShownContactDialog = true;
                  _showNoContactsDialog(context, userId);
                } else {
                  AppLogger.info('[ActiveTripPage] Dialog جهات الاتصال معروض بالفعل - تجاهل');
                }
              }
            }
          },
        ),
      ],
      child: OfflineBanner(
        child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.tripActive),
          actions: [
            const SizedBox(width: 8),
            // زر تحديث
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<TripBloc>().add(
                      RefreshActiveTripEvent(userId: userId),
                    );
              },
            ),
          ],
        ),
        body: BlocConsumer<TripBloc, TripState>(
        listener: (context, state) {
          // معالجة حالة المستخدم بعيد عن نقطة البداية
          if (state is TripUserFarFromStartPoint) {
            _showUserFarFromStartDialog(
              routeId: state.routeId,
              routeName: state.routeName,
              distance: state.distanceFromStart,
              userId: state.userId,
            );
          }
          
          // معالجة وجود رحلة نشطة - عرض dialog للاختيار
          if (state is TripActiveTripExists) {
            _showActiveTripDialog(
              context,
              activeTripId: state.activeTripId,
              routeId: state.routeId,
              userId: userId,
            );
          }
          
          // تتبع ID الرحلة النشطة لإنهائها عند إغلاق التطبيق
          if (state is TripActive) {
            _activeTripId = state.trip.id;
          } else if (state is TripPaused) {
            _activeTripId = state.trip.id;
          } else if (state is TripCompleted || state is NoActiveTrip) {
            _activeTripId = null;
          }
          
          // عرض رسالة عند إنهاء الرحلة وانتقال لصفحة التفاصيل
          if (state is TripCompleted) {
            _activeTripId = null;
            // ✅ تطوير 4: تحديث سجل الرحلات فوراً بعد إتمام الرحلة
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              context.read<TripBloc>().add(
                LoadTripHistoryEvent(userId: authState.user.id),
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.tripEndedSuccess),
                backgroundColor: AppColors.green,
              ),
            );
            // الانتقال لصفحة تفاصيل الرحلة المكتملة
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailPage(tripId: state.trip.id),
              ),
            );
          }

          // عرض رسالة عند نجاح العملية
          if (state is TripOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.green,
              ),
            );
            // إذا تم إلغاء الرحلة، أعد تحميل الحالة ثم عد للصفحة السابقة
            if (state.message.contains('إلغاء')) {
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                context.read<TripBloc>().add(LoadActiveTripEvent(userId: authState.user.id));
              }
              Navigator.pop(context);
            }
          }

          // عرض رسالة عند إضافة انحراف
          if (state is DeviationAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.deviationDetected),
                backgroundColor: AppColors.gold,
              ),
            );
          }

          // عرض رسالة عند حل انحراف
          if (state is DeviationResolved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.alertCancelled),
                backgroundColor: AppColors.green,
              ),
            );
          }

          // عرض تنبيه انحراف مكتشف
          if (state is DeviationDetectedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.deviationDetected),
                backgroundColor: AppColors.gold,
                duration: const Duration(seconds: 5),
              ),
            );
          }

          // ✅ عرض Dialog العد التنازلي عند حدوث انحراف
          if (state is DeviationCountdownState) {
            _wasInCountdown = true;
            // إغلاق أي dialog سابق
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            
            // عرض Dialog جديد
            DeviationCountdownWidget.showDeviationAlert(
              context: context,
              deviation: state.deviation,
              secondsRemaining: state.secondsRemaining,
              tripId: state.trip.id,
            );
          }

          // إغلاق Dialog العد التنازلي عند حل الانحراف
          // نستخدم _wasInCountdown لتتبع الحالة السابقة
          if (state is TripActive && _wasInCountdown) {
            _wasInCountdown = false;
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }

          // عرض تحذير SOS
          if (state is TripEmergencyState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.activeEmergencyFull),
                backgroundColor: AppColors.red,
                duration: const Duration(seconds: 10),
              ),
            );
          }

          // عرض رسالة الخطأ
          if (state is TripError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          // جاري التحميل
          if (state is TripLoading) {
            return LoadingWidget(message: AppLocalizations.of(context)!.loading);
          }

          // خطأ
          if (state is TripError) {
            return custom.ErrorDisplayWidget(
              message: state.message,
              onRetry: () {
                context.read<TripBloc>().add(
                      LoadActiveTripEvent(userId: userId),
                    );
              },
            );
          }

          // لا توجد رحلة نشطة
          if (state is NoActiveTrip) {
            return EmptyStateWidget(
              icon: Icons.route,
              message: AppLocalizations.of(context)!.noActiveTrip2,
            );
          }

          // رحلة نشطة أو متوقفة أو حالات مرتبطة
          if (state is TripActive || 
              state is TripPaused || 
              state is DeviationAdded ||
              state is DeviationResolved ||
              state is WaypointProgressUpdated ||
              state is TripStatsUpdated ||
              state is DeviationDetectedState ||
              state is DeviationCountdownState ||
              state is TripEmergencyState) {
            final trip = state is TripActive
                ? state.trip
                : state is TripPaused
                    ? state.trip
                    : state is DeviationAdded
                        ? state.trip
                        : state is DeviationResolved
                            ? state.trip
                            : state is WaypointProgressUpdated
                                ? state.trip
                                : state is TripStatsUpdated
                                    ? state.trip
                                    : state is DeviationDetectedState
                                        ? state.trip
                                        : state is DeviationCountdownState
                                            ? state.trip
                                            : (state as TripEmergencyState).trip;

            return Stack(
              children: [
                // المحتوى
                RefreshIndicator(
                  onRefresh: () async {
                    context.read<TripBloc>().add(
                          RefreshActiveTripEvent(userId: userId),
                        );
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // خريطة الرحلة النشطة مع التتبع التلقائي
                        TripMapWidget(
                          trip: trip,
                          autoCenter: true, // ✅ تفعيل التتبع التلقائي
                        ),

                        // معلومات الرحلة
                        TripInfoCard(trip: trip),

                        // ✅ تم إزالة DeviationCountdownWidget من هنا
                        // لأنه أصبح يُعرض كـ Dialog منبثق

                        // تقدم النقاط
                        WaypointProgressWidget(trip: trip),

                        // الإحصائيات
                        TripStatsWidget(trip: trip),

                        // 🤖 التحليل الذكي بالـ ML
                        if (_mlAnalysis != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: MLAnalysisCard(
                              analysis: _mlAnalysis!,
                              onActionPressed: () => _handleMLAction(_mlAnalysis!),
                            ),
                          ),
                        
                        // مؤشر التحليل النشط
                        if (_isAnalyzing)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, // ignore: prefer_const_constructors
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    AppLocalizations.of(context)!.smartAnalyzingMsg,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // الانحرافات
                        if (trip.deviations.isNotEmpty)
                          DeviationAlertWidget(
                            deviations: trip.deviations,
                            userId: userId,
                            tripId: trip.id,
                          ),

                        // مساحة للتحكمات
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

                // أزرار التحكم
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: TripControlsWidget(trip: trip),
                ),
              ],
            );
          }

          // حالة مكتملة - عرض loading أثناء الانتقال التلقائي لصفحة التفاصيل
          if (state is TripCompleted) {
            return LoadingWidget(message: AppLocalizations.of(context)!.tripEndedSuccess);
          }

          // حالات إضافية تظهر بعد إنهاء الرحلة أو تحميل البيانات - عرض شاشة لا توجد رحلة نشطة
          if (state is TripHistoryLoaded ||
              state is TripOperationSuccess ||
              state is TripDetailsLoaded ||
              state is TripLocationUpdating ||
              state is TripTrackingActive) {
            return EmptyStateWidget(
              icon: Icons.route,
              message: AppLocalizations.of(context)!.noActiveTrip2,
            );
          }

          // حالة غير معروفة - لا توجد رحلة نشطة
          return EmptyStateWidget(
            icon: Icons.route,
            message: AppLocalizations.of(context)!.noActiveTrip2,
          );
        },
      ),
      ),
      ),
    );
  }

  /// عرض حوار اختيار عند وجود رحلة نشطة
  void _showActiveTripDialog(
    BuildContext context, {
    required String activeTripId,
    required String routeId,
    required String userId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.gold, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.activeExistingTrip,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.existingTripOptions,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // الرجوع للصفحة السابقة
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility),
            label: Text(AppLocalizations.of(context)!.viewActiveTrip),
            onPressed: () {
              Navigator.pop(dialogContext);
              // تحميل الرحلة النشطة
              context.read<TripBloc>().add(
                LoadActiveTripEvent(userId: userId),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(AppLocalizations.of(context)!.startNewTripBtn),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              // إنهاء الرحلة الحالية وبدء رحلة جديدة
              _hasStartedTrip = true;
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
      ),
    );
  }

  /// عرض حوار تنبيه عند عدم وجود جهات اتصال
  /// Open/Closed Principle: قابل للتوسع لإضافة المزيد من الخيارات دون تعديل
  void _showNoContactsDialog(BuildContext context, String userId) {
    AppLogger.warning('[ActiveTripPage] عرض dialog - لا توجد جهات اتصال');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.contactsRequiredDialog,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.addContactFirst,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.contactsNecessary,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogger.info('[ActiveTripPage] المستخدم اختار إلغاء بدء الرحلة');
              
              // إعادة تعيين الـ flags
              _hasShownContactDialog = false;
              _isCheckingContacts = false;
              _hasStartedTrip = false;
              
              Navigator.pop(dialogContext);
              // العودة للصفحة السابقة
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: Text(AppLocalizations.of(context)!.addContact),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              AppLogger.info('[ActiveTripPage] الانتقال لصفحة إضافة جهات الاتصال');
              Navigator.pop(dialogContext);
              
              // إعادة تعيين الـ flags قبل الانتقال
              _hasShownContactDialog = false;
              
              // الانتقال لصفحة جهات الاتصال
              Navigator.pushNamed(
                context,
                '/contacts',
                arguments: userId,
              ).then((_) {
                // عند العودة، إعادة التحقق من جهات الاتصال
                AppLogger.info('[ActiveTripPage] العودة من صفحة جهات الاتصال - إعادة التحقق');
                
                // إعادة تعيين flag الفحص قبل الفحص الجديد
                _isCheckingContacts = false;
                
                // إعادة الفحص
                _checkContactsBeforeStarting(userId);
              });
            },
          ),
        ],
      ),
    );
  }

  /// عرض نافذة منبثقة عند كون المستخدم بعيد عن نقطة البداية
  /// Single Responsibility: مسؤول فقط عن عرض النافذة المنبثقة وتوجيه المستخدم
  /// عرض نافذة حوار للمستخدم البعيد عن نقطة البداية
  /// 
  /// السيناريو:
  /// 1. المستخدم يحاول بدء رحلة
  /// 2. TripBloc يكتشف أن المستخدم بعيد عن نقطة البداية المحفوظة
  /// 3. يعرض هذا الـ Dialog مع خيارات:
  ///    - إلغاء (الرجوع)
  ///    - البدء من الموقع الحالي (تجاهل المسافة)
  ///    - إنشاء مسار جديد
  /// 
  /// ملاحظة: لا نمرر BuildContext كمعامل لتجنب async gap warning
  Future<void> _showUserFarFromStartDialog({
    required String routeId,
    required String routeName,
    required double distance,
    required String userId,
  }) async {
    // إعادة تعيين flag لبدء الرحلة
    _hasStartedTrip = false;
    
    final distanceKm = (distance / 1000).toStringAsFixed(2);
    final distanceM = distance.toStringAsFixed(0);
    
    // الحصول على الموقع الحالي لعرضه على الخريطة
    final locationService = LocationService.instance;
    final currentLocation = await locationService.getCurrentLocation();
    
    // التحقق من mounted قبل استخدام context
    if (!mounted) return;
    
    // استخدام context من State مباشرة (آمن لأننا تحققنا من mounted)
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off,
                color: AppColors.gold,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.locationFarTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                AppLocalizations.of(context)!.routeNameLabel(routeName),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.straighten, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.locationFarMsg(distanceM.toString(), distanceKm),
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // زر لعرض الخريطة
              if (currentLocation != null)
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map, size: 18),
                    label: Text(AppLocalizations.of(context)!.viewOnMap),
                    onPressed: () {
                      _showLocationMapDialog(
                        context,
                        currentLocation: currentLocation,
                        routeId: routeId,
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.startFromCurrentLocation,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // زر الإلغاء
          TextButton(
            onPressed: () {
              AppLogger.info('[ActiveTripPage] المستخدم اختار إلغاء');
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          // زر البدء من الموقع الحالي
          ElevatedButton.icon(
            icon: const Icon(Icons.my_location, size: 18),
            label: Text(AppLocalizations.of(context)!.startTrip),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              AppLogger.info(
                '[ActiveTripPage] المستخدم اختار البدء من الموقع الحالي',
              );
              Navigator.pop(dialogContext);
              
              context.read<TripBloc>().add(
                StartTripFromCurrentLocationEvent(
                  userId: userId,
                  routeId: routeId,
                ),
              );
            },
          ),
          // زر إضافة مسار جديد
          ElevatedButton.icon(
            icon: const Icon(Icons.add_location, size: 18),
            label: Text(AppLocalizations.of(context)!.newRoute),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () async {
              AppLogger.info(
                '[ActiveTripPage] المستخدم اختار إضافة مسار جديد من الموقع الحالي',
              );
              Navigator.pop(dialogContext);
              
              // التحقق من mounted قبل العمليات async
              if (!mounted) return;
              
              final locationService = LocationService.instance;
              final currentLocation = await locationService.getCurrentLocation();
              
              // التحقق من mounted بعد await
              if (!mounted) return;
              
              if (currentLocation == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.locationFailed),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
                return;
              }
              
              // التنقل بدون await
              unawaited(Navigator.pushReplacementNamed(
                context,
                '/create-route',
                arguments: {
                  'autoFillStartLocation': true,
                  'startLocation': currentLocation,
                },
              ));
            },
          ),
        ],
      ),
    ));
  }
  
  /// عرض نافذة الخريطة لإظهار الموقع الحالي ونقطة البداية
  void _showLocationMapDialog(
    BuildContext context, {
    required Location currentLocation,
    required String routeId,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.currentLocationAndStart,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<dynamic>(
                  future: context.read<TripBloc>().tripsRepository.getRouteById(routeId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Center(
                        child: Text(AppLocalizations.of(context)!.routeInfoLoadFailed),
                      );
                    }
                    
                    return snapshot.data!.fold(
                      (failure) => Center(
                        child: Text('${AppLocalizations.of(context)!.error}: ${failure.message}'),
                      ),
                      (route) {
                        if (route == null || route.waypoints.isEmpty) {
                          return Center(
                            child: Text(AppLocalizations.of(context)!.invalidRoute),
                          );
                        }
                        
                        return TripMapWidget(
                          currentLocation: currentLocation,
                          route: route,
                          showFullRoute: true,
                          autoCenter: true,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.currentLocationLabel, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 24),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.startPointLabel, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
