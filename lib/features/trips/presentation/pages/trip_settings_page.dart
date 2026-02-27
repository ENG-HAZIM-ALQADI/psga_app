import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/services/deviation_detector.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/trips/domain/entities/trip_settings_entity.dart';
import 'package:psga_app/features/trips/domain/usecases/get_trip_settings_usecase.dart';
import 'package:psga_app/features/trips/domain/usecases/save_trip_settings_usecase.dart';
import 'package:psga_app/injection_container.dart' as di;

/// صفحة إعدادات الرحلات
/// Single Responsibility: مسؤولة فقط عن عرض وتعديل إعدادات الرحلات
class TripSettingsPage extends StatefulWidget {
  const TripSettingsPage({super.key});

  @override
  State<TripSettingsPage> createState() => _TripSettingsPageState();
}

class _TripSettingsPageState extends State<TripSettingsPage> {
  late TripSettingsEntity _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  final GetTripSettingsUseCase _getSettingsUseCase = di.sl<GetTripSettingsUseCase>();
  final SaveTripSettingsUseCase _saveSettingsUseCase = di.sl<SaveTripSettingsUseCase>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() => _isLoading = true);

    final result = await _getSettingsUseCase(
      GetTripSettingsParams(userId: authState.user.id),
    );

    result.fold(
      (failure) {
        AppLogger.error('[TripSettings] فشل جلب الإعدادات: ${failure.message}');
        setState(() {
          _settings = TripSettingsEntity.defaults(authState.user.id);
          _isLoading = false;
        });
      },
      (settings) {
        AppLogger.success('[TripSettings] تم جلب الإعدادات');
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final result = await _saveSettingsUseCase(
      SaveTripSettingsParams(settings: _settings),
    );

    setState(() => _isSaving = false);

    result.fold(
      (failure) {
        if (mounted) {
          context.showErrorSnackBar(failure.message);
        }
      },
      (_) {
        // ✅ تطبيق الإعدادات الجديدة على DeviationDetector فوراً
        // هذا يضمن أن أي رحلة نشطة ستستخدم العتبات المحدثة
        try {
          DeviationDetector.instance.updateThresholds(
            low: _settings.lowDeviationThreshold,
            medium: _settings.mediumDeviationThreshold,
            high: _settings.highDeviationThreshold,
          );
          AppLogger.success(
            '[TripSettings] تم تطبيق العتبات الجديدة على DeviationDetector: '
            'Low=${_settings.lowDeviationThreshold}م, '
            'Medium=${_settings.mediumDeviationThreshold}م, '
            'High=${_settings.highDeviationThreshold}م',
          );
        } catch (e) {
          AppLogger.warning('[TripSettings] فشل تحديث DeviationDetector', e);
          // لا نوقف العملية - الإعدادات محفوظة على أي حال
        }
        
        if (mounted) {
          context.showSuccessSnackBar(AppLocalizations.of(context)!.settingsSavedSuccessMsg);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.trips),
        actions: [
          if (_isSaving)
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
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: AppLocalizations.of(context)!.saveSettingsTooltipTrip,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات توضيحية
                  _buildInfoCard(context),
                  const SizedBox(height: AppDimensions.spacingLG),

                  // عتبة موقع البداية
                  _buildSectionTitle(AppLocalizations.of(context)!.startLocationSectionTitle),
                  _buildDistanceSlider(
                    context: context,
                    title: AppLocalizations.of(context)!.allowedDistanceTitle,
                    value: _settings.startLocationThreshold,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          startLocationThreshold: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  
                  _buildToggleTile(
                    context: context,
                    title: AppLocalizations.of(context)!.enableLocationValidationTitle,
                    subtitle: AppLocalizations.of(context)!.enableLocationValidationSubtitle,
                    value: _settings.enableLocationValidation,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          enableLocationValidation: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  
                  _buildToggleTile(
                    context: context,
                    title: AppLocalizations.of(context)!.alwaysStartFromCurrentTitle,
                    subtitle: AppLocalizations.of(context)!.alwaysStartFromCurrentSubtitle,
                    value: _settings.alwaysStartFromCurrentLocation,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          alwaysStartFromCurrentLocation: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  
                  _buildToggleTile(
                    context: context,
                    title: AppLocalizations.of(context)!.updateOriginalRouteTitle,
                    subtitle: AppLocalizations.of(context)!.updateOriginalRouteSubtitle,
                    value: _settings.updateOriginalRoute,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          updateOriginalRoute: value,
                        );
                      });
                    },
                  ),
                  
                  // عرض إحصائيات الاستخدام
                  if (_settings.startFromHereUsageCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.spacingMD),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingSM),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined,
                                color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.startFromHereUsageCount(
                                    _settings.startFromHereUsageCount.toString()),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Divider(height: 40),

                  // عتبات الانحراف
                  _buildSectionTitle(AppLocalizations.of(context)!.deviationSectionTitle),
                  const SizedBox(height: AppDimensions.spacingSM),
                  
                  _buildDistanceSlider(
                    context: context,
                    title: AppLocalizations.of(context)!.deviationLow,
                    value: _settings.lowDeviationThreshold,
                    min: 10,
                    max: 200,
                    divisions: 19,
                    color: Colors.amber,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          lowDeviationThreshold: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),

                  _buildDistanceSlider(
                    context: context,
                    title: AppLocalizations.of(context)!.deviationMedium,
                    value: _settings.mediumDeviationThreshold,
                    min: 50,
                    max: 400,
                    divisions: 35,
                    color: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          mediumDeviationThreshold: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),

                  _buildDistanceSlider(
                    context: context,
                    title: AppLocalizations.of(context)!.deviationHigh,
                    value: _settings.highDeviationThreshold,
                    min: 100,
                    max: 1000,
                    divisions: 90,
                    color: Colors.red,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          highDeviationThreshold: value,
                        );
                      });
                    },
                  ),

                  const Divider(height: 40),

                  // إعدادات أخرى
                  _buildSectionTitle(AppLocalizations.of(context)!.generalSettingsSection),
                  _buildToggleTile(
                    context: context,
                    title: AppLocalizations.of(context)!.autoRouteCalcTitle,
                    subtitle: AppLocalizations.of(context)!.autoRouteCalcSubtitle,
                    value: _settings.enableAutoRouteCalculation,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          enableAutoRouteCalculation: value,
                        );
                      });
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // زر إعادة تعيين
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final authState = context.read<AuthBloc>().state;
                        if (authState is! Authenticated) return;
                        
                        setState(() {
                          _settings = TripSettingsEntity.defaults(authState.user.id);
                        });
                        context.showInfoSnackBar(
                            AppLocalizations.of(context)!.settingsResetSuccess);
                      },
                      icon: const Icon(Icons.restore),
                      label: Text(AppLocalizations.of(context)!.resetToDefaults),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),
                ],
              ),
            ),
    );
  }

  // تم تمرير context لمعالجة الثيم والترجمة
  Widget _buildInfoCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.tripSettingsInfoBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildDistanceSlider({
    required BuildContext context,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    Color? color,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final sliderColor = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sliderColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.distanceMetersValue(value.toInt().toString()),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: sliderColor,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: sliderColor,
              label: l10n.distanceMeters(value.toInt().toString()),
              onChanged: onChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.distanceMeters(min.toInt().toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                Text(
                  l10n.distanceMeters(max.toInt().toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 1,
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
