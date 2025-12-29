import 'package:flutter/material.dart';

class CountdownTimerWidget extends StatelessWidget {
  final int seconds;
  final int totalSeconds;
  final double size;
  final VoidCallback? onCancel;

  const CountdownTimerWidget({
    super.key,
    required this.seconds,
    required this.totalSeconds,
    this.size = 150,
    this.onCancel,
  });

  Color get _color {
    final percentage = seconds / totalSeconds;
    if (percentage > 0.6) return Colors.green;
    if (percentage > 0.3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final progress = seconds / totalSeconds;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  valueColor: AlwaysStoppedAnimation<Color>(_color),
                  backgroundColor: _color.withOpacity(0.2),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$seconds',
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                      color: _color,
                    ),
                  ),
                  Text(
                    'ثانية',
                    style: TextStyle(
                      fontSize: size * 0.12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('أنا بخير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}
