import 'package:flutter/material.dart';
import 'package:psga_app/features/maps/data/services/deviation_detector.dart';

/// تحذير الانحراف على الخريطة
class DeviationWarning extends StatelessWidget {
  final DeviationResult deviation;
  final VoidCallback? onDismiss;
  final VoidCallback? onNavigateBack;

  const DeviationWarning({
    super.key,
    required this.deviation,
    this.onDismiss,
    this.onNavigateBack,
  });

  @override
  Widget build(BuildContext context) {
    if (!deviation.isDeviated) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _getShadowColor(),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildWarningIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deviation.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onDismiss,
                  ),
              ],
            ),
            if (onNavigateBack != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNavigateBack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _getBackgroundColor(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text(
                    'العودة للمسار',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getIcon(),
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (deviation.severity) {
      case DeviationSeverity.low:
        return Colors.orange;
      case DeviationSeverity.medium:
        return Colors.deepOrange;
      case DeviationSeverity.high:
        return Colors.red;
      case DeviationSeverity.critical:
        return Colors.red.shade900;
      default:
        return Colors.orange;
    }
  }

  Color _getShadowColor() {
    return _getBackgroundColor().withOpacity(0.4);
  }

  IconData _getIcon() {
    switch (deviation.severity) {
      case DeviationSeverity.critical:
        return Icons.error;
      case DeviationSeverity.high:
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  String _getTitle() {
    switch (deviation.severity) {
      case DeviationSeverity.low:
        return 'انحراف بسيط';
      case DeviationSeverity.medium:
        return 'انحراف متوسط';
      case DeviationSeverity.high:
        return 'انحراف كبير';
      case DeviationSeverity.critical:
        return 'انحراف خطير!';
      default:
        return 'تنبيه';
    }
  }
}

/// بانر الانحراف الصغير
class DeviationBanner extends StatelessWidget {
  final double distanceFromRoute;
  final DeviationSeverity severity;

  const DeviationBanner({
    super.key,
    required this.distanceFromRoute,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '${distanceFromRoute.round()} متر عن المسار',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (severity) {
      case DeviationSeverity.low:
        return Colors.orange;
      case DeviationSeverity.medium:
        return Colors.deepOrange;
      case DeviationSeverity.high:
      case DeviationSeverity.critical:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// مؤشر اتجاه العودة للمسار
class ReturnToRouteIndicator extends StatelessWidget {
  final double angle;
  final double distance;

  const ReturnToRouteIndicator({
    super.key,
    required this.angle,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: angle,
            child: const Icon(
              Icons.arrow_upward,
              color: Colors.blue,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'العودة للمسار',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                '${distance.round()} متر',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
