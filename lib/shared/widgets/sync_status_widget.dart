import 'package:flutter/material.dart';
import '../../core/services/sync/sync_manager.dart';
import '../../core/services/sync/sync_item.dart';

/// Widget لعرض حالة المزامنة
/// يظهر أيقونة سحابة مع حالة المزامنة الحالية
class SyncStatusWidget extends StatelessWidget {
  final bool showLabel;
  final double iconSize;

  const SyncStatusWidget({
    super.key,
    this.showLabel = false,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncManager.instance.syncStatusStream,
      initialData: const SyncStatus(
        isSyncing: false,
        pendingCount: 0,
      ),
      builder: (context, snapshot) {
        final status = snapshot.data!;

        return GestureDetector(
          onTap: () => _showSyncDetails(context, status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getBackgroundColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getBackgroundColor(status).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(status),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getTextColor(context, status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(SyncStatus status) {
    if (status.isSyncing) {
      // جاري المزامنة - سحابة دوارة
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: iconSize,
              color: Colors.blue,
            ),
            SizedBox(
              width: iconSize * 0.6,
              height: iconSize * 0.6,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      );
    }

    if (status.hasError) {
      // خطأ - سحابة حمراء مع علامة تعجب
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.cloud_off,
            size: iconSize,
            color: Colors.red,
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (status.hasPendingItems) {
      // عناصر في الانتظار - سحابة برتقالية مع رقم
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.cloud_upload,
            size: iconSize,
            color: Colors.orange,
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${status.pendingCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // متزامن بالكامل - سحابة خضراء مع علامة صح
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.cloud_done,
          size: iconSize,
          color: Colors.green,
        ),
      ],
    );
  }

  Color _getBackgroundColor(SyncStatus status) {
    if (status.isSyncing) return Colors.blue;
    if (status.hasError) return Colors.red;
    if (status.hasPendingItems) return Colors.orange;
    return Colors.green;
  }

  Color _getTextColor(BuildContext context, SyncStatus status) {
    if (status.isSyncing) return Colors.blue;
    if (status.hasError) return Colors.red;
    if (status.hasPendingItems) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(SyncStatus status) {
    if (status.isSyncing) return 'جاري المزامنة...';
    if (status.hasError) return 'فشل المزامنة';
    if (status.hasPendingItems) return '${status.pendingCount} في الانتظار';
    return 'متزامن';
  }

  void _showSyncDetails(BuildContext context, SyncStatus status) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIcon(status),
                const SizedBox(width: 12),
                Text(
                  'حالة المزامنة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              icon: Icons.sync,
              label: 'الحالة',
              value: _getStatusText(status),
              color: _getBackgroundColor(status),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.pending_actions,
              label: 'عناصر في الانتظار',
              value: '${status.pendingCount}',
              color: Colors.orange,
            ),
            if (status.lastSyncTime != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.access_time,
                label: 'آخر مزامنة',
                value: _formatLastSync(status.lastSyncTime!),
                color: Colors.blue,
              ),
            ],
            if (status.hasError) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.error,
                label: 'الخطأ',
                value: status.lastError ?? 'خطأ غير معروف',
                color: Colors.red,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  SyncManager.instance.syncNow();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('مزامنة الآن'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'منذ ${diff.inSeconds} ثانية';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else {
      return 'منذ ${diff.inDays} يوم';
    }
  }
}