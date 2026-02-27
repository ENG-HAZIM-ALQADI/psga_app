import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';

/// بطاقة عرض المسار
class RouteCard extends StatelessWidget {
  final RouteEntity route;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDelete;

  const RouteCard({
    required this.route,
    super.key,
    this.onTap,
    this.onFavoriteToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final distance = route.calculateTotalDistance();
    final distanceKm = (distance / 1000).toStringAsFixed(1);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.route,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (route.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            route.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      route.isFavorite ? Icons.star : Icons.star_border,
                      color: route.isFavorite ? AppColors.gold : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    onPressed: onFavoriteToggle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    context,
                    icon: Icons.location_on,
                    label: '${route.waypoints.length} نقاط',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _InfoChip(
                    context,
                    icon: Icons.straighten,
                    label: '$distanceKm كم',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (route.estimatedDuration != null)
                    _InfoChip(
                      context,
                      icon: Icons.access_time,
                      label: '~${route.estimatedDuration} دقيقة',
                      color: AppColors.green,
                    ),
                  if (route.checkpointCount > 0)
                    _InfoChip(
                      context,
                      icon: Icons.flag,
                      label: '${route.checkpointCount} تفتيش',
                      color: AppColors.gold,
                    ),
                  _InfoChip(
                    context,
                    icon: Icons.circle,
                    label: _getStatusLabel(route.status),
                    color: _getStatusColor(context, route.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(RouteStatus status) {
    switch (status) {
      case RouteStatus.active:
        return 'نشط';
      case RouteStatus.inactive:
        return 'غير نشط';
      case RouteStatus.archived:
        return 'مؤرشف';
    }
  }

  Color _getStatusColor(BuildContext context, RouteStatus status) {
    switch (status) {
      case RouteStatus.active:
        return AppColors.green;
      case RouteStatus.inactive:
        return Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary;
      case RouteStatus.archived:
        return Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.darkTextSecondary;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
    this.context, {
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
