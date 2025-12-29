import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/alert_config_entity.dart';
import '../bloc/alert_bloc.dart';
import '../bloc/alert_event.dart';
import '../bloc/alert_state.dart';

class AlertSettingsPage extends StatefulWidget {
  const AlertSettingsPage({super.key});

  @override
  State<AlertSettingsPage> createState() => _AlertSettingsPageState();
}

class _AlertSettingsPageState extends State<AlertSettingsPage> {
  late AlertConfigEntity _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    context.read<AlertBloc>().add(const LoadAlertConfigEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التنبيهات'),
      ),
      body: BlocConsumer<AlertBloc, AlertState>(
        listener: (context, state) {
          if (state is AlertConfigLoaded) {
            setState(() {
              _config = state.config;
              _isLoading = false;
            });
          } else if (state is AlertError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                'عام',
                Icons.settings,
                [
                  _buildSwitch(
                    'تفعيل التنبيهات',
                    'تفعيل أو تعطيل جميع التنبيهات',
                    _config.isEnabled,
                    (value) => _updateConfig(_config.copyWith(isEnabled: value)),
                  ),
                  _buildSwitch(
                    'زر الطوارئ SOS',
                    'تفعيل زر الطوارئ السريع',
                    _config.sosEnabled,
                    (value) => _updateConfig(_config.copyWith(sosEnabled: value)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                'حدود التنبيه',
                Icons.tune,
                [
                  _buildSlider(
                    'حد الانحراف',
                    '${_config.deviationThreshold.toInt()} متر',
                    _config.deviationThreshold,
                    50,
                    500,
                    (value) => _updateConfig(_config.copyWith(deviationThreshold: value)),
                  ),
                  _buildSlider(
                    'مدة العد التنازلي',
                    '${_config.countdownSeconds} ثانية',
                    _config.countdownSeconds.toDouble(),
                    10,
                    60,
                    (value) => _updateConfig(_config.copyWith(countdownSeconds: value.toInt())),
                  ),
                  _buildSlider(
                    'عد SOS التنازلي',
                    '${_config.sosCountdownSeconds} ثانية',
                    _config.sosCountdownSeconds.toDouble(),
                    3,
                    10,
                    (value) => _updateConfig(_config.copyWith(sosCountdownSeconds: value.toInt())),
                  ),
                  _buildSwitch(
                    'تصعيد تلقائي',
                    'تصعيد التنبيه تلقائياً عند انتهاء العد التنازلي',
                    _config.autoEscalate,
                    (value) => _updateConfig(_config.copyWith(autoEscalate: value)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                'الإشعارات',
                Icons.notifications,
                [
                  _buildSwitch(
                    'الصوت',
                    'تشغيل صوت عند التنبيه',
                    _config.soundEnabled,
                    (value) => _updateConfig(_config.copyWith(soundEnabled: value)),
                  ),
                  _buildSwitch(
                    'الاهتزاز',
                    'تفعيل الاهتزاز عند التنبيه',
                    _config.vibrationEnabled,
                    (value) => _updateConfig(_config.copyWith(vibrationEnabled: value)),
                  ),
                  _buildSwitch(
                    'ساعات الهدوء',
                    'تعطيل الإشعارات خلال فترة محددة',
                    _config.quietHoursEnabled,
                    (value) => _updateConfig(_config.copyWith(quietHoursEnabled: value)),
                  ),
                  if (_config.quietHoursEnabled) ...[
                    _buildTimePicker(
                      'بداية ساعات الهدوء',
                      _config.quietHoursStart,
                      (time) => _updateConfig(_config.copyWith(quietHoursStart: time)),
                    ),
                    _buildTimePicker(
                      'نهاية ساعات الهدوء',
                      _config.quietHoursEnd,
                      (time) => _updateConfig(_config.copyWith(quietHoursEnd: time)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                'تنبيهات إضافية',
                Icons.add_alert,
                [
                  _buildSlider(
                    'تنبيه عدم الحركة',
                    '${_config.inactivityTimeout} دقيقة',
                    _config.inactivityTimeout.toDouble(),
                    5,
                    120,
                    (value) => _updateConfig(_config.copyWith(inactivityTimeout: value.toInt())),
                  ),
                  _buildSlider(
                    'تنبيه البطارية المنخفضة',
                    '${_config.lowBatteryThreshold}%',
                    _config.lowBatteryThreshold.toDouble(),
                    5,
                    30,
                    (value) => _updateConfig(_config.copyWith(lowBatteryThreshold: value.toInt())),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSlider(
    String title,
    String valueLabel,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text(
                valueLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    String title,
    TimeOfDay? time,
    ValueChanged<TimeOfDay> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: TextButton(
        onPressed: () async {
          final selected = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 22, minute: 0),
          );
          if (selected != null) {
            onChanged(selected);
          }
        },
        child: Text(
          time != null ? time.format(context) : 'اختر',
        ),
      ),
    );
  }

  void _updateConfig(AlertConfigEntity config) {
    setState(() => _config = config);
    context.read<AlertBloc>().add(UpdateAlertConfigEvent(config));
  }
}
