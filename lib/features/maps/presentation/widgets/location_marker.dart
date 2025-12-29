import 'package:flutter/material.dart';

/// أنواع العلامات
enum MarkerType {
  currentLocation,
  startPoint,
  endPoint,
  waypoint,
  deviationPoint,
}

/// علامة موقع مخصصة
class LocationMarker extends StatelessWidget {
  final MarkerType type;
  final int? waypointNumber;
  final bool isAnimated;

  const LocationMarker({
    super.key,
    required this.type,
    this.waypointNumber,
    this.isAnimated = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case MarkerType.currentLocation:
        return _buildCurrentLocationMarker();
      case MarkerType.startPoint:
        return _buildStartPointMarker();
      case MarkerType.endPoint:
        return _buildEndPointMarker();
      case MarkerType.waypoint:
        return _buildWaypointMarker();
      case MarkerType.deviationPoint:
        return _buildDeviationMarker();
    }
  }

  /// علامة الموقع الحالي - دائرة زرقاء
  Widget _buildCurrentLocationMarker() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  /// علامة نقطة البداية - خضراء
  Widget _buildStartPointMarker() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  /// علامة نقطة النهاية - حمراء
  Widget _buildEndPointMarker() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Icon(
        Icons.flag,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  /// علامة نقطة وسيطة - برتقالية مرقمة
  Widget _buildWaypointMarker() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${waypointNumber ?? 1}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// علامة نقطة الانحراف - حمراء مع تحذير
  Widget _buildDeviationMarker() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.warning,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

/// علامة موقع متحركة
class AnimatedLocationMarker extends StatefulWidget {
  const AnimatedLocationMarker({super.key});

  @override
  State<AnimatedLocationMarker> createState() => _AnimatedLocationMarkerState();
}

class _AnimatedLocationMarkerState extends State<AnimatedLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 1, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _animation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.3 * (1 - (_animation.value - 1) / 0.5)),
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        );
      },
    );
  }
}
