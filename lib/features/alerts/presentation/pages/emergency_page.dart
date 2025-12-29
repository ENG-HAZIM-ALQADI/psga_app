import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../trips/domain/entities/location_entity.dart';
import '../../domain/entities/alert_entity.dart';
import '../bloc/alert_bloc.dart';
import '../bloc/alert_event.dart';
import '../bloc/alert_state.dart';
import '../widgets/sos_button.dart';
import '../widgets/countdown_timer_widget.dart';

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطوارئ'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<AlertBloc, AlertState>(
        listener: (context, state) {
          if (state is AlertError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SOSSending) {
            return _buildSendingState(context, state.countdownSeconds);
          }
          
          if (state is SOSSent) {
            return _buildSentState(context, state);
          }
          
          if (state is AlertAcknowledged) {
            return _buildAcknowledgedState(context);
          }
          
          return _buildInitialState(context);
        },
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'اضغط مطولاً على الزر لإرسال إشارة طوارئ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 48),
            SOSButton(
              size: MediaQuery.of(context).size.width * 0.6,
              holdDurationSeconds: 3,
              onActivated: () {
                final location = LocationEntity(
                  latitude: 24.7136,
                  longitude: 46.6753,
                  timestamp: DateTime.now(),
                );
                context.read<AlertBloc>().add(SendSOSEvent(location));
              },
            ),
            const Spacer(),
            _buildEmergencyNumbers(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSendingState(BuildContext context, int seconds) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CountdownTimerWidget(
            seconds: seconds,
            totalSeconds: 5,
            size: 180,
          ),
          const SizedBox(height: 32),
          const Text(
            'جاري إرسال تنبيه الطوارئ...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () {
              final alert = AlertEntity(
                id: 'temp',
                tripId: '',
                userId: '',
                type: AlertType.sos,
                level: AlertLevel.critical,
                status: AlertStatus.active,
                location: LocationEntity(
                  latitude: 0,
                  longitude: 0,
                  timestamp: DateTime.now(),
                ),
                message: '',
                triggeredAt: DateTime.now(),
              );
              context.read<AlertBloc>().add(CancelAlertEvent(alert));
            },
            icon: const Icon(Icons.close),
            label: const Text('إلغاء'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentState(BuildContext context, SOSSent state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'تم إرسال التنبيه',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'تم إبلاغ جهات الاتصال الخاصة بك',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          if (state.notifiedContacts.isNotEmpty) ...[
            const Text(
              'جهات الاتصال التي تم إبلاغها:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...state.notifiedContacts.map((name) => Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: Text(name),
                trailing: const Icon(Icons.check, color: Colors.green),
              ),
            )),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.read<AlertBloc>().add(
                AcknowledgeAlertEvent(state.alert.id),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('أنا بخير - إلغاء التنبيه'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgedState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sentiment_satisfied_alt,
            color: Colors.green,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'تم إلغاء التنبيه',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'سيتم إعلام جهات الاتصال بأنك بخير',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('العودة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumbers(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'أرقام الطوارئ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEmergencyButton(
                context,
                '911',
                'الطوارئ',
                Icons.local_hospital,
                Colors.red,
              ),
              _buildEmergencyButton(
                context,
                '998',
                'الدفاع المدني',
                Icons.fire_truck,
                Colors.orange,
              ),
              _buildEmergencyButton(
                context,
                '999',
                'الشرطة',
                Icons.local_police,
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton(
    BuildContext context,
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('tel:$number');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
