import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onActivated;
  final int holdDurationSeconds;
  final double size;

  const SOSButton({
    super.key,
    required this.onActivated,
    this.holdDurationSeconds = 3,
    this.size = 200,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.holdDurationSeconds),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onActivated();
        _controller.reset();
        setState(() => _isPressed = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPressStart() {
    HapticFeedback.mediumImpact();
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onPressEnd() {
    if (_controller.isAnimating) {
      _controller.reset();
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onPressStart(),
      onTapUp: (_) => _onPressEnd(),
      onTapCancel: _onPressEnd,
      child: AnimatedBuilder(
        listenable: _controller,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _isPressed ? Colors.red.shade900 : Colors.red.shade600,
                  Colors.red.shade800,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(_isPressed ? 0.6 : 0.4),
                  blurRadius: _isPressed ? 30 : 20,
                  spreadRadius: _isPressed ? 10 : 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isPressed)
                  SizedBox(
                    width: widget.size * 0.9,
                    height: widget.size * 0.9,
                    child: CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 8,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.size * 0.25,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPressed ? 'استمر بالضغط...' : 'اضغط مطولاً',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: widget.size * 0.07,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
