import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'dart:async';

/// زر SOS محسّن مع ضغط مطول وعد تنازلي
class SOSButtonWidget extends StatefulWidget {
  final VoidCallback onSOSTriggered;
  final VoidCallback? onCancelled;
  final int longPressDuration; // ثواني الضغط المطول
  final int countdownDuration; // ثواني العد التنازلي

  const SOSButtonWidget({
    required this.onSOSTriggered,
    this.onCancelled,
    this.longPressDuration = 3,
    this.countdownDuration = 5,
    super.key,
  });

  @override
  State<SOSButtonWidget> createState() => _SOSButtonWidgetState();
}

class _SOSButtonWidgetState extends State<SOSButtonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  bool _isPressing = false;
  bool _isCountingDown = false;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onLongPressStart() {
    setState(() => _isPressing = true);
    HapticFeedback.mediumImpact();

    // بدء عد الضغط المطول
    _longPressTimer = Timer(Duration(seconds: widget.longPressDuration), () {
      if (_isPressing) {
        _startCountdown();
      }
    });
  }

  void _onLongPressEnd() {
    setState(() => _isPressing = false);
    _longPressTimer?.cancel();
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _remainingSeconds = widget.countdownDuration;
      _isPressing = false;
    });

    HapticFeedback.heavyImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remainingSeconds--);

      if (_remainingSeconds > 0) {
        HapticFeedback.selectionClick();
      } else {
        _countdownTimer?.cancel();
        _triggerSOS();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _remainingSeconds = 0;
    });
    widget.onCancelled?.call();
    HapticFeedback.mediumImpact();
  }

  void _triggerSOS() {
    setState(() => _isCountingDown = false);
    HapticFeedback.heavyImpact();
    widget.onSOSTriggered();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) {
      return _buildCountdownView();
    }

    return _buildSOSButton();
  }

  Widget _buildSOSButton() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressing ? 0.9 : _scaleAnimation.value,
          child: GestureDetector(
            onLongPressStart: (_) => _onLongPressStart(),
            onLongPressEnd: (_) => _onLongPressEnd(),
            onLongPressCancel: _onLongPressEnd,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.red,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withOpacity(0.5 * _pulseAnimation.value),
                    blurRadius: 40 * _pulseAnimation.value,
                    spreadRadius: 20 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onError,
                      letterSpacing: 8,
                    ),
                  ),
                  if (_isPressing)
                    Positioned(
                      bottom: 30,
                      child: Text(
                        'استمر...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onError.withOpacity(0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // عد تنازلي
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _remainingSeconds <= 2 ? AppColors.red : AppColors.gold,
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_remainingSeconds',
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.seconds,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 40),

        // زر الإلغاء
        ElevatedButton(
          onPressed: _cancelCountdown,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            AppLocalizations.of(context)!.imOkay,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'سيتم إرسال تنبيه الطوارئ',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
          ),
        ),
      ],
    );
  }
}
