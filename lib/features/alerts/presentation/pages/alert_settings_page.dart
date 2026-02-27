import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_state.dart';

/// صفحة إعدادات التنبيهات مع التكامل مع AlertBloc
class AlertSettingsPage extends StatefulWidget {
  final String userId;

  const AlertSettingsPage({
    required this.userId,
    super.key,
  });

  @override
  State<AlertSettingsPage> createState() => _AlertSettingsPageState();
}

class _AlertSettingsPageState extends State<AlertSettingsPage> {
  // الإعدادات العامة
  bool _alertsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoEscalation = true;

  // Note: deviationThreshold moved to TripSettings

  // مدة العد التنازلي (ثانية)
  double _countdownDuration = 30.0;

  // ساعات الهدوء
  TimeOfDay? _quietHoursStart;
  TimeOfDay? _quietHoursEnd;
  bool _quietHoursEnabled = false;

  // إعدادات لكل نوع تنبيه
  final Map<String, bool> _alertTypeEnabled = {
    'deviation': true,
    'sos': true,
    'noMovement': true,
    'lowBattery': true,
    'connectionLost': false,
  };

  bool _isLoading = true;
  AlertConfigEntity? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  /// تحميل الإعدادات الحالية
  void _loadCurrentSettings() {
    AppLogger.info('[AlertSettings] تحميل الإعدادات الحالية للمستخدم: ${widget.userId}');
    // طلب تحميل الإعدادات من Bloc
    context.read<AlertBloc>().add(LoadAlertConfigEvent(userId: widget.userId));
  }

  /// حفظ الإعدادات
  void _saveSettings() {
    AppLogger.info('[AlertSettings] جاري حفظ الإعدادات');

    // إنشاء AlertTypeConfigs
    final typeConfigs = <AlertTypeConfig>[
      AlertTypeConfig(
        type: AlertType.deviation,
        enabled: _alertTypeEnabled['deviation'] ?? true,
        defaultSeverity: AlertSeverity.high,
        escalationThreshold: const Duration(minutes: 3),
        autoEscalate: _autoEscalation,
      ),
      AlertTypeConfig(
        type: AlertType.sos,
        enabled: _alertTypeEnabled['sos'] ?? true,
        defaultSeverity: AlertSeverity.critical,
        escalationThreshold: const Duration(minutes: 1),
        autoEscalate: true,
      ),
      AlertTypeConfig(
        type: AlertType.noMovement,
        enabled: _alertTypeEnabled['noMovement'] ?? true,
        defaultSeverity: AlertSeverity.medium,
        escalationThreshold: const Duration(minutes: 5),
        autoEscalate: _autoEscalation,
      ),
      AlertTypeConfig(
        type: AlertType.lowBattery,
        enabled: _alertTypeEnabled['lowBattery'] ?? true,
        defaultSeverity: AlertSeverity.low,
        escalationThreshold: const Duration(minutes: 10),
        autoEscalate: false,
      ),
    ];

    // إنشاء AlertConfigEntity
    final config = AlertConfigEntity(
      id: _currentConfig?.id ?? '${widget.userId}_config',
      userId: widget.userId,
      globalEnabled: _alertsEnabled,
      typeConfigs: typeConfigs,
      countdownDuration: Duration(seconds: _countdownDuration.toInt()),
      // deviationThreshold moved to TripSettings
      enableQuietHours: _quietHoursEnabled,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
      sendDuringQuietHours: true, // SOS دائماً
      createdAt: _currentConfig?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // حفظ الإعدادات محلياً
    setState(() {
      _currentConfig = config;
    });

    // إرسال Event لحفظ الإعدادات
    context.read<AlertBloc>().add(SaveAlertConfigEvent(config: config));
    
    AppLogger.success('[AlertSettings] تم إرسال طلب حفظ الإعدادات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.alertSettings),
        actions: [
          // زر الحفظ
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: AppLocalizations.of(context)!.saveSettingsTooltip,
          ),
        ],
      ),
      body: BlocConsumer<AlertBloc, AlertState>(
        listener: (context, state) {
          if (state is AlertConfigLoaded) {
            AppLogger.info('[AlertSettings] تم تحميل الإعدادات من Bloc');
            
            // تحديث القيم من الإعدادات المحملة
            setState(() {
              _currentConfig = state.config;
              _alertsEnabled = state.config.globalEnabled;
              // deviationThreshold moved to TripSettings
              _countdownDuration = state.config.countdownDuration.inSeconds.toDouble();
              _quietHoursEnabled = state.config.enableQuietHours;
              _quietHoursStart = state.config.quietHoursStart;
              _quietHoursEnd = state.config.quietHoursEnd;
              
              // البحث عن إعدادات deviation
              try {
                final deviationConfig = state.config.typeConfigs.firstWhere(
                  (c) => c.type == AlertType.deviation,
                );
                _autoEscalation = deviationConfig.autoEscalate;
              } catch (e) {
                // إذا لم يوجد، استخدام القيمة الافتراضية
                _autoEscalation = true;
              }
              
              // تحديث حالة تفعيل كل نوع تنبيه
              for (var typeConfig in state.config.typeConfigs) {
                final key = typeConfig.type.toString().split('.').last;
                _alertTypeEnabled[key] = typeConfig.enabled;
              }
              
              _isLoading = false;
            });
          } else if (state is AlertConfigSaved) {
            AppLogger.success('[AlertSettings] تم حفظ الإعدادات بنجاح');
            
            // تحديث الإعدادات المحلية
            setState(() {
              _currentConfig = state.config;
              _isLoading = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.settingsSavedSuccess),
                  ],
                ),
                backgroundColor: AppColors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (state is AlertError) {
            AppLogger.error('[AlertSettings] فشل الحفظ', state.message);
            setState(() => _isLoading = false);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.onError),
                    const SizedBox(width: 8),
                    Expanded(child: Text(AppLocalizations.of(context)!.settingsSaveFailed(state.message))),
                  ],
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          // عرض مؤشر التحميل أثناء الحفظ
          if (state is AlertLoading && _isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.savingSettings),
                ],
              ),
            );
          }

          final l10n = AppLocalizations.of(context)!;
          return ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // الإعدادات العامة
          _buildSection(
            title: l10n.generalSettings,
            children: [
              _buildSwitchTile(
                title: l10n.enableAlertsSwitchTitle,
                subtitle: l10n.enableAlertsSwitchSubtitle,
                value: _alertsEnabled,
                onChanged: (value) => setState(() => _alertsEnabled = value),
                icon: Icons.notifications_active,
              ),
              _buildSwitchTile(
                title: l10n.soundTitle,
                subtitle: l10n.soundSubtitle,
                value: _soundEnabled,
                onChanged: (value) => setState(() => _soundEnabled = value),
                icon: Icons.volume_up,
                enabled: _alertsEnabled,
              ),
              _buildSwitchTile(
                title: l10n.vibrationTitle,
                subtitle: l10n.vibrationSubtitle,
                value: _vibrationEnabled,
                onChanged: (value) => setState(() => _vibrationEnabled = value),
                icon: Icons.vibration,
                enabled: _alertsEnabled,
              ),
              _buildSwitchTile(
                title: l10n.autoEscalationTitle,
                subtitle: l10n.autoEscalationSubtitle,
                value: _autoEscalation,
                onChanged: (value) => setState(() => _autoEscalation = value),
                icon: Icons.auto_awesome,
                enabled: _alertsEnabled,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ملاحظة: عتبة الانحراف انتقلت لإعدادات الرحلة
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.deviationNoteTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.deviationNoteBody,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // مدة العد التنازلي
          _buildSection(
            title: l10n.countdownSectionTitle,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.responseTime),
                        Text(
                          l10n.countdownSeconds(_countdownDuration.toInt().toString()),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _countdownDuration,
                      min: 10,
                      max: 60,
                      divisions: 10,
                      label: l10n.countdownSliderLabel(_countdownDuration.toInt().toString()),
                      onChanged: _alertsEnabled
                          ? (value) => setState(() => _countdownDuration = value)
                          : null,
                    ),
                    Text(
                      l10n.countdownHint,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ساعات الهدوء
          _buildSection(
            title: l10n.quietHoursSectionTitle,
            children: [
              _buildSwitchTile(
                title: l10n.enableQuietHoursTitle,
                subtitle: l10n.enableQuietHoursSubtitle,
                value: _quietHoursEnabled,
                onChanged: (value) => setState(() => _quietHoursEnabled = value),
                icon: Icons.nightlight_round,
                enabled: _alertsEnabled,
              ),
              if (_quietHoursEnabled) ...[
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(l10n.quietHoursStart),
                  subtitle: Text(
                    _quietHoursStart != null
                        ? _quietHoursStart!.format(context)
                        : l10n.notSet,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(context, true),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(l10n.quietHoursEnd),
                  subtitle: Text(
                    _quietHoursEnd != null
                        ? _quietHoursEnd!.format(context)
                        : l10n.notSet,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTime(context, false),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // أنواع التنبيهات
          _buildSection(
            title: l10n.alertTypesSectionTitle,
            children: [
              _buildAlertTypeTile(
                context,
                l10n.alertTypeDeviation,
                'deviation',
                Icons.directions,
                AppColors.gold,
              ),
              _buildAlertTypeTile(
                context,
                l10n.alertTypeSos,
                'sos',
                Icons.emergency,
                AppColors.red,
              ),
              _buildAlertTypeTile(
                context,
                l10n.alertTypeNoMovement,
                'noMovement',
                Icons.directions_walk_outlined,
                AppColors.gold,
              ),
              _buildAlertTypeTile(
                context,
                l10n.alertTypeLowBattery,
                'lowBattery',
                Icons.battery_alert,
                AppColors.gold,
              ),
              _buildAlertTypeTile(
                context,
                l10n.alertTypeConnectionLost,
                'connectionLost',
                Icons.signal_wifi_off,
                AppColors.gold,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // زر الحفظ
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(16),
            ),
            child: Text(
              l10n.saveSettingsBtn,
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),

          const SizedBox(height: 16),

          // زر إعادة التعيين
          OutlinedButton(
            onPressed: _resetToDefaults,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
            child: Text(
              l10n.resetDefaultsBtn,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
          ); // إغلاق ListView
        }, // إغلاق builder
      ), // إغلاق BlocConsumer
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(
        icon, 
        color: enabled 
          ? Theme.of(context).colorScheme.primary 
          : Theme.of(context).textTheme.bodyMedium?.color
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildAlertTypeTile(
    BuildContext context,
    String title,
    String key,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Switch(
        value: _alertTypeEnabled[key] ?? false,
        onChanged: _alertsEnabled
            ? (value) => setState(() => _alertTypeEnabled[key] = value)
            : null,
        activeColor: color,
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietHoursStart = picked;
        } else {
          _quietHoursEnd = picked;
        }
      });
    }
  }

  void _resetToDefaults() {
    setState(() {
      _alertsEnabled = true;
      _soundEnabled = true;
      _vibrationEnabled = true;
      _autoEscalation = true;
      // _deviationThreshold removed - now in TripSettings
      _countdownDuration = 30.0;
      _quietHoursEnabled = false;
      _quietHoursStart = null;
      _quietHoursEnd = null;
      
      _alertTypeEnabled.forEach((key, _) {
        _alertTypeEnabled[key] = key != 'connectionLost';
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.settingsResetDefault)),
    );
  }
}
