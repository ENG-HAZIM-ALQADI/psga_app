import 'dart:async';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/services/geocoding_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/services/route_calculator_service.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';
import 'package:psga_app/features/routes/presentation/bloc/bloc.dart';
import 'package:psga_app/features/routes/presentation/widgets/waypoint_item.dart';
import 'package:psga_app/features/maps/presentation/pages/location_picker_screen.dart';
import 'package:psga_app/shared/widgets/custom_button.dart';
import 'package:psga_app/shared/widgets/loading_widget.dart';

/// صفحة إنشاء مسار جديد
class CreateRoutePage extends StatefulWidget {
  final RouteEntity? route; // للتعديل

  const CreateRoutePage({
    this.route,
    super.key,
  });

  @override
  State<CreateRoutePage> createState() => _CreateRoutePageState();
}

class _CreateRoutePageState extends State<CreateRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationService = LocationService.instance;
  final _geocodingService = GeocodingService.instance;
  final _calculatorService = RouteCalculatorService.instance;
  
  List<Waypoint> _waypoints = [];
  bool _isSubmitting = false;
  bool _isCalculating = false;
  bool _isLocationLoading = false; // حالة تحميل تحديد الموقع (full-screen overlay)
  String _locationLoadingMessage = ''; // رسالة تحميل الموقع
  double? _estimatedDistance;
  int? _estimatedDuration;
  Timer? _debounceTimer; // لتجنب الحسابات المتكررة

  bool get _isEditMode => widget.route != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.route!.name;
      _descriptionController.text = widget.route!.description ?? '';
      _waypoints = List.from(widget.route!.waypoints);
      _estimatedDistance = widget.route!.estimatedDistance;
      _estimatedDuration = widget.route!.estimatedDuration;
    }
    
    // التحقق من وجود موقع تلقائي لإضافته
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAutoFillLocation();
    });
  }

  /// التحقق من وجود موقع تلقائي لإضافته كنقطة بداية
  /// Single Responsibility: مسؤول فقط عن التحقق وإضافة الموقع التلقائي
  Future<void> _checkForAutoFillLocation() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic>) {
      final autoFill = args['autoFillStartLocation'] as bool?;
      final startLocation = args['startLocation'] as Location?;
      
      if (autoFill == true && startLocation != null && _waypoints.isEmpty) {
        AppLogger.info('[CreateRoutePage] إضافة الموقع الحالي تلقائياً كنقطة بداية');
        
        // ✅ حفظ l10n قبل الـ async gap لتجنب use_build_context_synchronously
        final fallbackName = AppLocalizations.of(context)!.waypointStart;
        
        final realName = await _geocodingService.getAddressFromLocation(startLocation)
            ?? fallbackName;
        
        if (!mounted) return;
        setState(() {
          _waypoints.add(Waypoint(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: realName,
            location: startLocation,
            order: 0,
            createdAt: DateTime.now(),
          ));
        });
        
        // إظهار رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.addCurrentLocation),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoutesBloc, RoutesState>(
      listener: (context, state) {
        if (state is RouteCreated || state is RouteUpdated) {
          context.showSuccessSnackBar(_isEditMode ? AppLocalizations.of(context)!.routeUpdated : AppLocalizations.of(context)!.routeCreated);
          // إرجاع true للقائمة لإعلامها بإعادة التحميل
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              Navigator.pop(context, true); // ← true يُخبر routes_list بأن تعيد التحميل
            }
          });
        } else if (state is RoutesError) {
          setState(() => _isSubmitting = false);
          context.showErrorSnackBar(state.message);
        }
      },
      child: LoadingOverlay(
        isLoading: _isLocationLoading,
        message: _locationLoadingMessage,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_isEditMode ? AppLocalizations.of(context)!.editRoute : AppLocalizations.of(context)!.createRoute),
            actions: [
              if (_isSubmitting || _isCalculating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              else if (_isEditMode)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: _validateAndSave,
                  tooltip: AppLocalizations.of(context)!.saveTooltipEdits,
                ),
            ],
          ),
          body: _isSubmitting
              ? LoadingWidget(message: AppLocalizations.of(context)!.savingRoute)
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  children: [
                    // اسم المسار
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.routeName,
                        hintText: AppLocalizations.of(context)!.routeNameHint,
                        prefixIcon: const Icon(Icons.label),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.routeNameRequired;
                        }
                        if (value.trim().length < 3) {
                          return AppLocalizations.of(context)!.routeNameMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),

                    // وصف المسار
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.descriptionOptional,
                        hintText: AppLocalizations.of(context)!.routeDescription,
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppDimensions.spacingLG),

                    // معلومات المسافة والوقت
                    if (_estimatedDistance != null || _estimatedDuration != null)
                      Card(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.paddingMD),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (_estimatedDistance != null)
                                _buildInfoChip(
                                  icon: Icons.straighten,
                                  label: AppLocalizations.of(context)!.distance,
                                  value: _calculatorService.formatDistance(_estimatedDistance!),
                                ),
                              if (_estimatedDuration != null)
                                _buildInfoChip(
                                  icon: Icons.access_time,
                                  label: AppLocalizations.of(context)!.timeLabel,
                                  value: _calculatorService.formatDuration(_estimatedDuration!),
                                ),
                            ],
                          ),
                        ),
                      ),

                    if (_estimatedDistance != null || _estimatedDuration != null)
                      const SizedBox(height: AppDimensions.spacingMD),

                    // عنوان النقاط
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppLocalizations.of(context)!.waypointsCount} (${_waypoints.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.add_location),
                          tooltip: AppLocalizations.of(context)!.addWaypointTooltip,
                          onSelected: (value) {
                            switch (value) {
                              case 'current':
                                _addCurrentLocation();
                                break;
                              case 'map':
                                _pickLocationFromMap();
                                break;
                              case 'manual':
                                _showAddWaypointDialog();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'current',
                              child: Row(
                                children: [
                                  const Icon(Icons.my_location, size: 20),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.currentLocation),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'map',
                              child: Row(
                                children: [
                                  const Icon(Icons.map, size: 20),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.pickFromMap),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'manual',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_location, size: 20),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.manualInput),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),

                    // قائمة النقاط
                    if (_waypoints.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingXL),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_location_alt,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              AppLocalizations.of(context)!.noWaypointsYet,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXS),
                            Text(
                              AppLocalizations.of(context)!.minTwoWaypointsHint,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._waypoints.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimensions.spacingSM),
                          child: WaypointItem(
                            waypoint: entry.value,
                            index: entry.key + 1,
                            isFirst: entry.key == 0,
                            isLast: entry.key == _waypoints.length - 1,
                            onEdit: () => _editWaypoint(entry.key),
                            onDelete: () => _deleteWaypoint(entry.key),
                          ),
                        );
                      }),

                    const SizedBox(height: AppDimensions.spacingXL),

                    // زر الحفظ
                    CustomButton(
                      text: _isEditMode ? AppLocalizations.of(context)!.saveChanges : AppLocalizations.of(context)!.saveRoute,
                      onPressed: _validateAndSave,
                      icon: Icons.save,
                      isLoading: _isSubmitting,
                    ),
                  ],
                ),
              ),
        ), // Scaffold
      ), // LoadingOverlay
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// حساب تفاصيل المسار مع debouncing لتجنب الحسابات المتكررة
  /// Single Responsibility: مسؤول فقط عن حساب المسافة والوقت
  Future<void> _calculateRouteDetails() async {
    // إلغاء أي حساب سابق قيد الانتظار
    _debounceTimer?.cancel();
    
    // انتظار 500ms قبل الحساب (debouncing)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_waypoints.length < 2) return;
      
      setState(() => _isCalculating = true);

      try {
        AppLogger.info('[CreateRoutePage] جاري حساب تفاصيل المسار (${_waypoints.length} نقاط)');
        
        final calculation = await _calculatorService.calculateRouteDetails(
          _waypoints,
          useActualRoutes: true,
        );

        if (mounted) {
          setState(() {
            _estimatedDistance = calculation.distance;
            _estimatedDuration = calculation.duration;
            _isCalculating = false;
          });

          AppLogger.success('[CreateRoutePage] تم الحساب: ${calculation.formattedDistance}, ${calculation.formattedDuration}');
          context.showSuccessSnackBar(AppLocalizations.of(context)!.routeCalcSuccess);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCalculating = false);
          AppLogger.error('[CreateRoutePage] فشل حساب المسار', e);
          context.showErrorSnackBar(AppLocalizations.of(context)!.routeCalcFailed);
        }
      }
    });
  }

  /// التحقق من تفعيل GPS وعرض dialog إذا كان معطلاً
  Future<bool> _checkGPSEnabled() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('[CreateRoutePage] GPS معطل - عرض dialog');
        if (mounted) {
          await _showGPSRequiredDialog();
        }
        // التحقق مجدداً بعد عودة المستخدم من الإعدادات
        final serviceEnabledAfter = await Geolocator.isLocationServiceEnabled();
        return serviceEnabledAfter;
      }
      return true;
    } catch (e) {
      AppLogger.error('[CreateRoutePage] خطأ في التحقق من GPS', e);
      return false;
    }
  }

  /// عرض نافذة تفعيل GPS الإلزامية
  Future<void> _showGPSRequiredDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final l10n = AppLocalizations.of(context)!;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.location_off, color: Colors.orange, size: 48),
            title: Text(
              l10n.gpsRequired,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              l10n.gpsRequiredBody,
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: Text(l10n.cancel),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: Text(l10n.openSettings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _openLocationSettingsFromDialog(dialogContext),
              ),
            ],
          ),
        );
      },
    );
  }

  /// فتح إعدادات الموقع من داخل dialog
  Future<void> _openLocationSettingsFromDialog(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();
    await Geolocator.openLocationSettings();
  }

  /// إضافة الموقع الحالي
  /// Single Responsibility: مسؤول فقط عن إضافة الموقع الحالي كنقطة في المسار
  Future<void> _addCurrentLocation() async {
    // تجنب تنفيذ متعدد في نفس الوقت
    if (_isCalculating || _isLocationLoading) {
      context.showWarningSnackBar(AppLocalizations.of(context)!.waitCurrentOperation);
      return;
    }
    
    // إظهار loading overlay فوراً قبل أي عملية async
    setState(() {
      _isLocationLoading = true;
      _locationLoadingMessage = AppLocalizations.of(context)!.locatingCurrentPosition;
    });
    
    // التحقق من GPS أولاً
    final gpsEnabled = await _checkGPSEnabled();
    if (!gpsEnabled || !mounted) {
      setState(() => _isLocationLoading = false);
      return;
    }
    
    // Capture context-dependent values before async gap
    final l10n = AppLocalizations.of(context)!;
    
    try {
      final location = await _locationService.getCurrentLocation();
      
      if (!mounted) return;
      
      if (location != null) {
        AppLogger.info('[CreateRoutePage] تم الحصول على الموقع الحالي: ${location.latitude}, ${location.longitude}');
        
        // ✅ جلب العنوان الحقيقي عبر Geocoding (أكثر موثوقية من "موقعي الحالي")
        AppLogger.info('[CreateRoutePage] جلب العنوان من Geocoding...');
        final realAddress = await _geocodingService.getAddressFromLocation(location);
        
        if (!mounted) return;
        
        // تحديد اسم النقطة: العنوان الحقيقي إذا وُجد، وإلا الاسم التلقائي
        String waypointName;
        if (_waypoints.isEmpty) {
          // نقطة البداية
          waypointName = realAddress ?? l10n.waypointStart;
        } else if (_waypoints.length == 1) {
          // نقطة النهاية
          waypointName = realAddress ?? l10n.waypointEnd;
        } else {
          // نقطة وسيطة - أعد تسمية النقطة السابقة
          final lastIndex = _waypoints.length - 1;
          final previousLast = _waypoints[lastIndex];
          _waypoints[lastIndex] = previousLast.copyWith(
            name: _resolveMiddleName(previousLast.name, _waypoints.length, l10n),
          );
          // النقطة الجديدة - عنوان حقيقي أو اسم تلقائي
          waypointName = realAddress ?? l10n.waypointMiddle(_waypoints.length.toString());
        }

        AppLogger.success('[CreateRoutePage] اسم النقطة: $waypointName');
        
        final waypoint = Waypoint(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: waypointName,
          location: location,
          order: _waypoints.length,
          createdAt: DateTime.now(),
          radius: 50,
        );
        
        // إخفاء loading وإضافة النقطة معاً
        setState(() {
          _isLocationLoading = false;
          _waypoints.add(waypoint);
        });
        
        AppLogger.success('[CreateRoutePage] تم إضافة النقطة بالعنوان: $waypointName');
        
        // حساب المسار تلقائياً بعد إضافة نقطتين (مع debounce)
        if (_waypoints.length >= 2) {
          // إلغاء أي timer سابق
          _debounceTimer?.cancel();
          // الانتظار 800ms قبل الحساب للسماح بإضافة نقاط إضافية
          _debounceTimer = Timer(const Duration(milliseconds: 800), () {
            _calculateRouteDetails();
          });
        }
        
        if (mounted) {
          context.showSuccessSnackBar(AppLocalizations.of(context)!.waypointAddedSuccess(waypointName));
        }
      } else {
        AppLogger.warning('[CreateRoutePage] فشل في الحصول على الموقع الحالي');
        if (mounted) {
          setState(() => _isLocationLoading = false);
          context.showErrorSnackBar(AppLocalizations.of(context)!.locationFailed);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('[CreateRoutePage] خطأ في إضافة الموقع الحالي', e, stackTrace);
      if (mounted) {
        setState(() => _isLocationLoading = false);
        context.showErrorSnackBar(AppLocalizations.of(context)!.locationError);
      }
    }
  }

  /// اختيار موقع من الخريطة
  /// Single Responsibility: مسؤول فقط عن فتح شاشة اختيار الموقع وإضافة النقطة
  Future<void> _pickLocationFromMap() async {
    // منع التنفيذ المتعدد في نفس الوقت
    if (_isCalculating || _isLocationLoading) {
      context.showWarningSnackBar(AppLocalizations.of(context)!.waitCurrentOperation);
      return;
    }
    
    // إظهار loading overlay فوراً قبل أي عملية async
    setState(() {
      _isLocationLoading = true;
      _locationLoadingMessage = AppLocalizations.of(context)!.preparingMap;
    });
    
    // التحقق من GPS أولاً
    final gpsEnabled = await _checkGPSEnabled();
    if (!gpsEnabled || !mounted) {
      setState(() => _isLocationLoading = false);
      return;
    }
    
    // تخزين قيم l10n قبل أي async gap
    final l10n = AppLocalizations.of(context)!;
    
    // تحديد الموقع الابتدائي للخريطة
    Location? initialLocation;
    String? title;
    
    if (_waypoints.isEmpty) {
      // أول نقطة - استخدام الموقع الحالي
      title = l10n.selectStartPointTitle;
      try {
        initialLocation = await _locationService.getCurrentLocation();
      } catch (e) {
        AppLogger.warning('[CreateRoutePage] فشل الحصول على الموقع الحالي، استخدام موقع افتراضي');
        // في حالة الفشل، استخدام موقع افتراضي
      }
    } else if (_waypoints.length == 1) {
      // النقطة الثانية - استخدام نقطة البداية كموقع ابتدائي
      title = l10n.selectWaypointTitle;
      initialLocation = _waypoints.first.location;
    } else {
      // نقطة وسيطة - استخدام آخر نقطة مضافة
      title = l10n.selectWaypointTitle;
      initialLocation = _waypoints.last.location;
    }

    if (!mounted) return;

    // إخفاء loading قبل فتح شاشة اختيار الموقع
    setState(() => _isLocationLoading = false);

    final location = await Navigator.push<Location>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: initialLocation,
          title: title,
          existingWaypoints: _waypoints, // تمرير النقاط الموجودة لعرضها على الخريطة
        ),
      ),
    );

    if (location != null && mounted) {
      AppLogger.info('[CreateRoutePage] تم اختيار موقع من الخريطة: ${location.latitude}, ${location.longitude}');
      
      // ✅ جلب العنوان الحقيقي عبر Geocoding
      String? realAddress;
      try {
        realAddress = await _geocodingService.getAddressFromLocation(location);
        if (!mounted) return;
      } catch (_) {}

      // تحديد اسم النقطة: العنوان الحقيقي أو الاسم التلقائي
      String waypointName;
      if (_waypoints.isEmpty) {
        waypointName = realAddress ?? l10n.waypointStart;
      } else if (_waypoints.length == 1) {
        waypointName = realAddress ?? l10n.waypointEnd;
      } else {
        final lastIndex = _waypoints.length - 1;
        final previousLast = _waypoints[lastIndex];
        _waypoints[lastIndex] = previousLast.copyWith(
          name: _resolveMiddleName(previousLast.name, _waypoints.length, l10n),
        );
        waypointName = realAddress ?? l10n.waypointEnd;
        AppLogger.info('[CreateRoutePage] تم تحويل "${previousLast.name}" إلى نقطة وسيطة');
      }
      
      final waypoint = Waypoint(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: waypointName,
        location: location,
        order: _waypoints.length,
        createdAt: DateTime.now(),
        radius: 50,
      );
      
      setState(() => _waypoints.add(waypoint));
      
      AppLogger.success('[CreateRoutePage] تم إضافة النقطة: $waypointName');
      
      // حساب المسار تلقائياً بعد إضافة نقطتين (مع debounce)
      if (_waypoints.length >= 2) {
        // إلغاء أي timer سابق
        _debounceTimer?.cancel();
        // الانتظار 800ms قبل الحساب للسماح بإضافة نقاط إضافية
        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
          _calculateRouteDetails();
        });
      }
      
      if (mounted) {
        context.showSuccessSnackBar(AppLocalizations.of(context)!.waypointAddedFromMapSuccess(waypointName));
      }
    }
  }

  void _showAddWaypointDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final radiusController = TextEditingController(text: '50');
    bool isCheckpoint = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.manualWaypointTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.waypointNameRequired,
                    hintText: AppLocalizations.of(context)!.exampleHomeName,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.descriptionOptional,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.latitudeLabel,
                    hintText: '31.123456',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lngController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.longitudeLabel,
                    hintText: '35.123456',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.radiusLabel,
                    hintText: '50',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text(AppLocalizations.of(context)!.checkpointWaypoint),
                  subtitle: Text(AppLocalizations.of(context)!.mustPassPoint),
                  value: isCheckpoint,
                  onChanged: (value) {
                    setState(() => isCheckpoint = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    latController.text.trim().isEmpty ||
                    lngController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.requiredFields),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                  return;
                }

                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                final radius = double.tryParse(radiusController.text) ?? 50.0;

                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.invalidCoordinates),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                  return;
                }

                final waypoint = Waypoint(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  location: Location(
                    latitude: lat,
                    longitude: lng,
                    timestamp: DateTime.now(),
                  ),
                  order: _waypoints.length,
                  createdAt: DateTime.now(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  radius: radius,
                  isCheckpoint: isCheckpoint,
                );

                this.setState(() => _waypoints.add(waypoint));
                Navigator.pop(context);
                
                AppLogger.success('[CreateRoutePage] تم إضافة نقطة يدوياً: ${waypoint.name}');
                
                // حساب المسار تلقائياً بعد إضافة نقطتين (مع debounce)
                if (_waypoints.length >= 2) {
                  // إلغاء أي timer سابق
                  _debounceTimer?.cancel();
                  // الانتظار 800ms قبل الحساب للسماح بإضافة نقاط إضافية
                  _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                    _calculateRouteDetails();
                  });
                }
              },
              child: Text(AppLocalizations.of(context)!.addWaypoint),
            ),
          ],
        ),
      ),
    );
  }

  void _editWaypoint(int index) {
    final waypoint = _waypoints[index];
    final nameController = TextEditingController(text: waypoint.name);
    final descriptionController = TextEditingController(text: waypoint.description);
    final latController = TextEditingController(
      text: waypoint.location.latitude.toString(),
    );
    final lngController = TextEditingController(
      text: waypoint.location.longitude.toString(),
    );
    final radiusController = TextEditingController(
      text: waypoint.radius?.toString() ?? '50',
    );
    bool isCheckpoint = waypoint.isCheckpoint;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.editPointTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.waypointNameRequiredLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.descriptionLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.latitudeRequiredLabel),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lngController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.longitudeRequiredLabel),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.radiusMetersLabel),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text(AppLocalizations.of(context)!.checkpointWaypoint),
                  value: isCheckpoint,
                  onChanged: (value) => setState(() => isCheckpoint = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                final radius = double.tryParse(radiusController.text) ?? 50.0;

                if (lat != null && lng != null) {
                  this.setState(() {
                    _waypoints[index] = waypoint.copyWith(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      location: Location(
                        latitude: lat,
                        longitude: lng,
                        timestamp: DateTime.now(),
                      ),
                      radius: radius,
                      isCheckpoint: isCheckpoint,
                    );
                  });
                  Navigator.pop(context);
                  
                  AppLogger.success('[CreateRoutePage] تم تعديل نقطة: ${nameController.text}');
                  
                  // إعادة حساب المسار بعد التعديل (مع debounce)
                  if (_waypoints.length >= 2) {
                    // إلغاء أي timer سابق
                    _debounceTimer?.cancel();
                    // الانتظار 800ms قبل الحساب
                    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                      _calculateRouteDetails();
                    });
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteWaypoint(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deletePointTitle),
        content: Text(AppLocalizations.of(context)!.deleteWaypointConfirm(_waypoints[index].name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _waypoints.removeAt(index));
              Navigator.pop(context);
              
              // إعادة حساب المسار بعد الحذف إذا بقي نقطتان على الأقل
              if (_waypoints.length >= 2) {
                _calculateRouteDetails();
              } else {
                // إعادة تعيين القيم إذا أصبحت أقل من نقطتين
                setState(() {
                  _estimatedDistance = null;
                  _estimatedDuration = null;
                });
              }
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

  void _validateAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من وجود نقطتين على الأقل
    if (_waypoints.isEmpty) {
      context.showWarningSnackBar(AppLocalizations.of(context)!.routeNeedsWaypoints);
      return;
    }
    
    if (_waypoints.length < 2) {
      context.showWarningSnackBar(AppLocalizations.of(context)!.routeNeedsTwoWaypoints);
      return;
    }
    
    // ✅ التحقق من صحة إحداثيات النقاط
    final invalidWaypoints = _waypoints.where((w) =>
        w.location.latitude == 0.0 && w.location.longitude == 0.0).toList();
    if (invalidWaypoints.isNotEmpty) {
      context.showWarningSnackBar(AppLocalizations.of(context)!.waypointInvalidCoords);
      return;
    }
    
    // ✅ التحقق من أن النقاط ليست متطابقة تماماً
    final startLat = _waypoints.first.location.latitude;
    final startLng = _waypoints.first.location.longitude;
    final endLat = _waypoints.last.location.latitude;
    final endLng = _waypoints.last.location.longitude;
    if ((startLat - endLat).abs() < 0.0001 && (startLng - endLng).abs() < 0.0001 && _waypoints.length == 2) {
      context.showWarningSnackBar(AppLocalizations.of(context)!.waypointsSameLocation);
      return;
    }

    setState(() => _isSubmitting = true);

    // حساب المسافة والوقت إذا لم يتم حسابهما
    if (_estimatedDistance == null || _estimatedDuration == null) {
      try {
        final calculation = await _calculatorService.calculateRouteDetails(
          _waypoints,
          useActualRoutes: false, // استخدام المسافة المباشرة للسرعة
        );
        _estimatedDistance = calculation.distance;
        _estimatedDuration = calculation.duration;
      } catch (e) {
        // في حالة الفشل، استخدم الحساب المباشر
        _estimatedDistance = _calculatorService.calculateDirectDistance(_waypoints);
        _estimatedDuration = ((_estimatedDistance! / 1000) / 50 * 60).round();
      }
    }

    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.id : '';
    final now = DateTime.now();

    final route = RouteEntity(
      id: _isEditMode ? widget.route!.id : now.millisecondsSinceEpoch.toString(),
      userId: userId,
      name: _nameController.text.trim(),
      waypoints: _waypoints,
      createdAt: _isEditMode ? widget.route!.createdAt : now,
      updatedAt: now,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      estimatedDistance: _estimatedDistance,
      estimatedDuration: _estimatedDuration,
    );

    if (_isEditMode) {
      context.read<RoutesBloc>().add(UpdateRouteEvent(route: route));
    } else {
      context.read<RoutesBloc>().add(CreateRouteEvent(route: route));
    }
  }
}  /// ✅ تحديد اسم النقطة الوسيطة - يحافظ على اسم العنوان الحقيقي
  String _resolveMiddleName(String previousName, int newLength, AppLocalizations l10n) {
    // نقطة نهاية (موقعي الحالي النمط القديم) → وسيطة (موقعي الحالي)
    if (previousName.contains(l10n.waypointEndCurrentLocation)) {
      return l10n.waypointMiddleCurrentLocation(newLength.toString());
    }
    // نقطة نهاية عادية → وسيطة عادية
    if (previousName == l10n.waypointEnd || previousName.startsWith(l10n.waypointEnd)) {
      return l10n.waypointMiddle(newLength.toString());
    }
    // عنوان حقيقي (من Geocoding) → يبقى كما هو
    return previousName;
  }


