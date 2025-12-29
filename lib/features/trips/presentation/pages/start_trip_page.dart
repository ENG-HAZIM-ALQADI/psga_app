// ============================================================================
// 📄 ملف: start_trip_page.dart
// 🏗️ الطبقة: Presentation (بدء الرحلة)
// 🎯 الوظيفة: صفحة اختيار مسار وبدء رحلة جديدة أو استئناف رحلة موقوفة
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';
import '../bloc/trip_bloc.dart';
import '../bloc/trip_event.dart';
import '../bloc/trip_state.dart';

/// 📌 صفحة بدء الرحلة
/// 💡 تستخدم MultiBlocListener للاستماع على عدة BLoCs (RouteBloc و TripBloc)
class StartTripPage extends StatefulWidget {
  final String userId;

  const StartTripPage({super.key, required this.userId});

  @override
  State<StartTripPage> createState() => _StartTripPageState();
}

class _StartTripPageState extends State<StartTripPage> {
  RouteEntity? _selectedRoute;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    context.read<RouteBloc>().add(LoadRoutes(widget.userId));
    context.read<TripBloc>().add(LoadActiveTrip(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بدء رحلة'),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<TripBloc, TripState>(
            listener: (context, state) {
              if (state is TripActive) {
                setState(() => _isStarting = false);
                AppLogger.info('[StartTrip] الانتقال إلى شاشة الرحلة النشطة', name: 'StartTrip');
                context.push(AppRoutes.tripActive, extra: state.trip);
              } else if (state is TripError) {
                setState(() => _isStarting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
        child: BlocBuilder<TripBloc, TripState>(
          builder: (context, tripState) {
            if (tripState is TripActive) {
              return _buildActiveTripCard(context, tripState.trip, theme);
            }
            
            if (tripState is TripPaused) {
              return _buildPausedTripCard(context, tripState.trip, theme);
            }

            return BlocBuilder<RouteBloc, RouteState>(
              builder: (context, routeState) {
                if (routeState is RoutesLoading || tripState is TripLoading) {
                  return const LoadingWidget();
                }

                if (routeState is RoutesLoaded) {
                  if (routeState.routes.isEmpty) {
                    return _buildNoRoutesState(context, theme);
                  }
                  return _buildRouteSelection(context, routeState.routes, theme);
                }

                if (routeState is RoutesError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(routeState.message),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'إعادة المحاولة',
                          onPressed: () {
                            context.read<RouteBloc>().add(LoadRoutes(widget.userId));
                          },
                        ),
                      ],
                    ),
                  );
                }

                return const LoadingWidget();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveTripCard(BuildContext context, dynamic trip, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لديك رحلة نشطة',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trip.routeName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'متابعة الرحلة',
                    icon: Icons.play_arrow,
                    onPressed: () {
                      context.push(AppRoutes.tripActive, extra: trip);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedTripCard(BuildContext context, dynamic trip, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.pause_circle,
                    size: 64,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'رحلة متوقفة مؤقتاً',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trip.routeName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'استئناف الرحلة',
                    icon: Icons.play_arrow,
                    onPressed: () {
                      context.push(AppRoutes.tripActive, extra: trip);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRoutesState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد مسارات',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يجب إنشاء مسار أولاً لبدء رحلة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'إنشاء مسار جديد',
              icon: Icons.add,
              onPressed: () {
                context.push(AppRoutes.routeCreate);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSelection(BuildContext context, List<RouteEntity> routes, ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'اختر المسار للرحلة',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              final isSelected = _selectedRoute?.id == route.id;

              return Card(
                color: isSelected ? theme.colorScheme.primaryContainer : null,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRoute = route;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.route,
                            color: isSelected 
                                ? theme.colorScheme.onPrimary 
                                : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.straighten,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${route.estimatedDistance.toStringAsFixed(1)} كم',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${route.estimatedDuration.inMinutes} دقيقة',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomButton(
            text: 'بدء الرحلة',
            icon: Icons.play_arrow,
            isLoading: _isStarting,
            onPressed: _selectedRoute == null
                ? null
                : () {
                    setState(() => _isStarting = true);
                    
                    final startLocation = LocationEntity(
                      latitude: _selectedRoute!.startPoint.location.latitude,
                      longitude: _selectedRoute!.startPoint.location.longitude,
                      timestamp: DateTime.now(),
                      address: _selectedRoute!.startPoint.name ?? 'نقطة البداية',
                    );
                    
                    AppLogger.info('[StartTrip] بدء رحلة على المسار: ${_selectedRoute!.name}', name: 'StartTrip');
                    
                    context.read<TripBloc>().add(StartTrip(
                      routeId: _selectedRoute!.id,
                      userId: widget.userId,
                      startLocation: startLocation,
                    ));
                  },
          ),
        ),
      ],
    );
  }
}
