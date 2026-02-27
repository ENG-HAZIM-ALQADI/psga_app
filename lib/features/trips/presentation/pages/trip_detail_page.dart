import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/presentation/bloc/bloc.dart';
import 'package:psga_app/features/trips/presentation/pages/trip_history_page.dart';
import 'package:psga_app/features/trips/presentation/widgets/deviation_alert_widget.dart';
import 'package:psga_app/features/trips/presentation/widgets/trip_info_card.dart';
import 'package:psga_app/features/trips/presentation/widgets/trip_stats_widget.dart';
import 'package:psga_app/features/trips/presentation/widgets/waypoint_progress_widget.dart';
import 'package:psga_app/features/maps/presentation/widgets/trip_map_widget.dart';
import 'package:psga_app/shared/widgets/error_widget.dart' as custom;
import 'package:psga_app/shared/widgets/loading_widget.dart';

class TripDetailPage extends StatefulWidget {
  final String tripId;

  const TripDetailPage({
    required this.tripId,
    super.key,
  });

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  @override
  void initState() {
    super.initState();
    // تحميل تفاصيل الرحلة عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
    });
  }

  void _loadDetails() {
    context.read<TripBloc>().add(
      LoadTripDetailsEvent(tripId: widget.tripId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tripDetails),
      ),
      body: BlocConsumer<TripBloc, TripState>(
        listener: (context, state) {
          // لا نفعل شيئاً في الـ listener لتجنب تغيير الحالة
        },
        buildWhen: (previous, current) {
          // نعيد البناء فقط عند تحميل التفاصيل أو الخطأ أو التحميل
          return current is TripLoading ||
                 current is TripDetailsLoaded ||
                 current is TripError;
        },
        builder: (context, state) {
          if (state is TripLoading) {
            return LoadingWidget(message: context.l10n.pleaseWait);
          }

          if (state is TripError) {
            return custom.ErrorDisplayWidget(
              message: state.message,
              onRetry: () {
                context.read<TripBloc>().add(
                      LoadTripDetailsEvent(tripId: widget.tripId),
                    );
              },
            );
          }

          if (state is TripDetailsLoaded) {
            final trip = state.trip;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // خريطة الرحلة المكتملة
                  TripMapWidget(
                    trip: trip,
                    autoCenter: false, // لا حاجة للتتبع التلقائي في رحلة منتهية
                    showFullRoute: true, // عرض المسار الكامل
                  ),

                  TripInfoCard(trip: trip),
                  TripStatsWidget(trip: trip),
                  WaypointProgressWidget(trip: trip),

                  if (trip.deviations.isNotEmpty)
                    DeviationAlertWidget(
                      deviations: trip.deviations,
                      userId: trip.userId,
                    ),

                  const SizedBox(height: 16),

                  // زر العودة لسجل الرحلات (يظهر فقط للرحلات المكتملة/الملغاة)
                  if (trip.status == TripStatus.completed ||
                      trip.status == TripStatus.cancelled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // العودة لسجل الرحلات
                            final authState = context.read<AuthBloc>().state;
                            final userId = authState is Authenticated ? authState.user.id : '';
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TripHistoryPage(userId: userId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: Text(context.l10n.backToHistory),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          }

          // إذا لم تكن هناك حالة محددة، أعد المحاولة
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 64, color: Theme.of(context).textTheme.bodyMedium?.color),
                const SizedBox(height: 16),
                Text(
                  context.l10n.noData,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadDetails,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
