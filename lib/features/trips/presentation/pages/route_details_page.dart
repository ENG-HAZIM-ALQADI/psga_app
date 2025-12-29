// ============================================================================
// 📄 ملف: route_details_page.dart
// 🏗️ الطبقة: Presentation (عرض التفاصيل)
// 🎯 الوظيفة: صفحة تعرض تفاصيل المسار الكامل مع خيارات التعديل والحذف والبدء
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/route_entity.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/trip_bloc.dart';
import '../bloc/trip_event.dart';
import '../bloc/trip_state.dart';

/// 📌 صفحة تفاصيل المسار (StatelessWidget)
/// 💡 لا نحتاج StatefulWidget هنا لأننا نعتمد على BLoC لإدارة الحالة
class RouteDetailsPage extends StatelessWidget {
  final RouteEntity route;
  final String userId;

  const RouteDetailsPage({
    super.key,
    required this.route,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// 🎯 BlocListener: استمع فقط على أحداث بدء الرحلة
    /// عندما تنتقل الحالة من TripLoading إلى TripActive، نذهب للصفحة الجديدة
    return BlocListener<TripBloc, TripState>(
      /// 📌 listenWhen: تصفية الحالات - استمع فقط للانتقالات المهمة
      /// هنا: من Loading إلى Active (أي بدء الرحلة بنجاح)
      listenWhen: (previous, current) {
        return previous is TripLoading && current is TripActive;
      },
      listener: (context, state) {
        /// ✅ الرحلة بدأت بنجاح!
        if (state is TripActive) {
          AppLogger.info('[Trip] تم بدء الرحلة بنجاح، الانتقال لصفحة الرحلة النشطة', name: 'RouteDetails');
          /// الانتقال للصفحة النشطة مع تمرير بيانات الرحلة
          context.push(AppRoutes.tripActive, extra: state.trip);
        } 
        /// ❌ خطأ أثناء البدء
        else if (state is TripError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          IconButton(
            icon: Icon(
              route.isFavorite ? Icons.star : Icons.star_border,
              color: route.isFavorite ? Colors.amber : null,
            ),
            onPressed: () {
              context.read<RouteBloc>().add(ToggleFavorite(route.id));
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                AppLogger.info('[Route] الانتقال لتعديل المسار: ${route.name}', name: 'RouteDetails');
                context.push(AppRoutes.routeCreate, extra: route);
              } else if (value == 'delete') {
                _showDeleteConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('حذف', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'معاينة الخريطة',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (route.description != null) ...[
                    Text(
                      route.description!,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildInfoCard(
                    theme,
                    title: 'معلومات المسار',
                    children: [
                      _buildInfoRow(
                        icon: Icons.straighten,
                        label: 'المسافة',
                        value: '${route.estimatedDistance.toStringAsFixed(1)} كم',
                      ),
                      _buildInfoRow(
                        icon: Icons.access_time,
                        label: 'الوقت المتوقع',
                        value: _formatDuration(route.estimatedDuration),
                      ),
                      _buildInfoRow(
                        icon: Icons.repeat,
                        label: 'عدد الاستخدامات',
                        value: '${route.usageCount} مرة',
                      ),
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'تاريخ الإنشاء',
                        value: _formatDate(route.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    theme,
                    title: 'نقاط المسار',
                    children: [
                      _buildWaypointRow(
                        icon: Icons.trip_origin,
                        iconColor: Colors.green,
                        label: 'البداية',
                        value: route.startPoint.name ?? 'نقطة البداية',
                      ),
                      if (route.waypoints.isNotEmpty) ...[
                        const Divider(),
                        ...route.waypoints.map((wp) => _buildWaypointRow(
                              icon: Icons.circle,
                              iconColor: theme.colorScheme.primary,
                              label: 'نقطة ${wp.order}',
                              value: wp.name ?? 'نقطة وسيطة',
                            )),
                      ],
                      const Divider(),
                      _buildWaypointRow(
                        icon: Icons.flag,
                        iconColor: Colors.red,
                        label: 'النهاية',
                        value: route.endPoint.name ?? 'نقطة النهاية',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'بدء رحلة على هذا المسار',
                    icon: Icons.play_arrow,
                    onPressed: () => _startTrip(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWaypointRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المسار'),
        content: const Text('هل أنت متأكد من حذف هذا المسار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<RouteBloc>().add(DeleteRoute(
                    routeId: route.id,
                    userId: userId,
                  ));
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _startTrip(BuildContext context) {
    AppLogger.info('[Trip] بدء رحلة على المسار: ${route.name}', name: 'RouteDetails');
    final startLocation = route.startPoint.location;
    context.read<TripBloc>().add(StartTrip(
      routeId: route.id,
      userId: userId,
      startLocation: startLocation,
    ));
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} ساعة ${duration.inMinutes % 60} دقيقة';
    }
    return '${duration.inMinutes} دقيقة';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
