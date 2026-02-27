import 'package:flutter/material.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/core/utils/extensions.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';

/// عنصر نقطة الطريق
class WaypointItem extends StatelessWidget {
  final Waypoint waypoint;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WaypointItem({
    required this.waypoint,
    required this.index,
    super.key,
    this.isFirst = false,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رقم النقطة
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getPointColor(),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _getPointIcon(),
              ),
            ),
            const SizedBox(width: 12),
            
            // معلومات النقطة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          waypoint.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (waypoint.isCheckpoint)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.warning.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'تفتيش',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (waypoint.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      waypoint.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${waypoint.location.latitude.toStringAsFixed(6)}, '
                          '${waypoint.location.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (waypoint.radius != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.radar,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${waypoint.radius!.toInt()} م',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // أزرار التحكم
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18),
                        const SizedBox(width: 8),
                        Text(context.l10n.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(context.l10n.delete, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit' && onEdit != null) {
                    onEdit!();
                  } else if (value == 'delete' && onDelete != null) {
                    onDelete!();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPointColor() {
    if (isFirst) return AppColors.success;
    if (isLast) return AppColors.error;
    return AppColors.primary;
  }

  Widget _getPointIcon() {
    if (isFirst) {
      return const Icon(Icons.play_arrow, color: Colors.white, size: 16);
    }
    if (isLast) {
      return const Icon(Icons.flag, color: Colors.white, size: 16);
    }
    return Text(
      '$index',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
