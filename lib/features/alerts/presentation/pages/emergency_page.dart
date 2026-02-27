import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_event.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_state.dart';
import 'package:psga_app/features/alerts/presentation/widgets/active_alerts_widget.dart';
import 'package:psga_app/features/alerts/presentation/widgets/sos_button_widget.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// صفحة الطوارئ مع زر SOS محسّن
class EmergencyPage extends StatefulWidget {
  final String userId;

  const EmergencyPage({
    required this.userId,
    super.key,
  });

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final LocationService _locationService = LocationService.instance;
  Location? _currentLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _currentLocation = Location(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
          );
        });
      }
    } catch (e) {
      AppLogger.error('[EmergencyPage] فشل جلب الموقع', e);
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _triggerSOS() {
    AppLogger.info('[EmergencyPage] تفعيل SOS');

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.locatingMsg),
          backgroundColor: AppColors.gold,
        ),
      );
      _getCurrentLocation();
      return;
    }

    // إرسال SOS فوري
    context.read<AlertBloc>().add(SendImmediateSOSEvent(
      userId: widget.userId,
      location: _currentLocation!,
      message: 'طوارئ - أحتاج للمساعدة فوراً',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.emergency),
        backgroundColor: AppColors.red,
        foregroundColor: Theme.of(context).colorScheme.onError,
        actions: [
          // زر تحديث الموقع
          if (_isLoadingLocation)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _getCurrentLocation,
              tooltip: 'تحديث الموقع',
            ),
        ],
      ),
      body: BlocListener<AlertBloc, AlertState>(
        listener: (context, state) {
          if (state is ImmediateSOSSent) {
            AppLogger.success('[EmergencyPage] SOS تم الإرسال');
            
            _showSOSResultDialog(state);
          } else if (state is AlertError) {
            AppLogger.error('[EmergencyPage] خطأ في SOS', state.message);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is AlertLoading) {
            AppLogger.info('[EmergencyPage] جاري الإرسال...');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.error.withOpacity(0.1),
                Theme.of(context).colorScheme.error.withOpacity(0.2),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // العنوان
                    Text(
                      '🚨 إشارة استغاثة',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // الوصف
                    Text(
                      'اضغط مطولاً (3 ثوان) على الزر لإرسال\nإشارة طوارئ لجميع جهات الاتصال',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // زر SOS
                    SOSButtonWidget(
                      longPressDuration: 3,
                      countdownDuration: 5,
                      onSOSTriggered: _triggerSOS,
                      onCancelled: () {
                        AppLogger.info('[EmergencyPage] SOS ملغي');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.sosCancelledMsg),
                            backgroundColor: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // معلومات الموقع
                    _buildLocationInfo(),

                    const SizedBox(height: 24),

                    // رقم الطوارئ
                    _buildEmergencyNumber(),

                    const SizedBox(height: 24),

                    // تعليمات
                    _buildInstructions(),

                    const SizedBox(height: 32),

                    // التنبيهات النشطة
                    ActiveAlertsWidget(userId: widget.userId),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: _currentLocation != null ? AppColors.green : Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 8),
              Text(
                'الموقع الحالي',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentLocation != null)
            Text(
              'lat: ${_currentLocation!.latitude.toStringAsFixed(6)}\nlng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'جاري تحديد الموقع...',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumber() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'رقم الطوارئ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '999',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: إضافة url_launcher للاتصال
                AppLogger.info('[EmergencyPage] اتصال بالطوارئ');
              },
              icon: const Icon(Icons.phone),
              label: Text(AppLocalizations.of(context)!.callEmergency),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.gold),
              SizedBox(width: 8),
              Text(
                'تعليمات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1', 'اضغط مطولاً (3 ثوان) على زر SOS'),
          _buildInstructionItem('2', 'ستبدأ عد تنازلي 5 ثوان'),
          _buildInstructionItem('3', 'يمكنك الإلغاء قبل انتهاء الوقت'),
          _buildInstructionItem('4', 'سيتم إرسال رسالة لجميع جهات الاتصال'),
          _buildInstructionItem('5', 'سيتم إرسال موقعك الحالي'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSOSResultDialog(ImmediateSOSSent state) {
    final results = state.results;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.sosActivated),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تم إرسال إشارة الاستغاثة بنجاح:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (results['internal'] == true)
              _buildResultItem(
                Icons.notifications_active,
                'تنبيه داخلي',
                Colors.blue,
              ),
            if (results['fcm'] == true)
              _buildResultItem(
                Icons.send,
                'إشعار FCM: ${results['fcmCount']} جهة',
                Colors.green,
              ),
            if (results['sms'] == true)
              _buildResultItem(
                Icons.sms,
                'رسائل SMS: ${results['smsCount']} جهة',
                Colors.orange,
              ),
            const SizedBox(height: 16),
            const Text(
              'جميع جهات الاتصال الطارئة تم إبلاغها بموقعك',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
