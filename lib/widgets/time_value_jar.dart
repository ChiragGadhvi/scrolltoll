import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimeValueJar extends StatefulWidget {
  final double percentageRemaining;
  final double size;

  const TimeValueJar({
    super.key,
    required this.percentageRemaining,
    this.size = 200,
  });

  @override
  State<TimeValueJar> createState() => _TimeValueJarState();
}

class _TimeValueJarState extends State<TimeValueJar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingScale;
  late Animation<double> _glowOpacity;

  String _currentAsset = '';

  @override
  void initState() {
    super.initState();
    _currentAsset = _getAssetForPercentage(widget.percentageRemaining);

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _breathingScale = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowOpacity = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void didUpdateWidget(TimeValueJar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newAsset = _getAssetForPercentage(widget.percentageRemaining);
    if (newAsset != _currentAsset) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentAsset = newAsset;
      });
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  String _getAssetForPercentage(double percentage) {
    if (percentage >= 0.8) return 'assets/jar/jar_stage_1_full.png';
    if (percentage >= 0.6) return 'assets/jar/jar_stage_2_high.png';
    if (percentage >= 0.4) return 'assets/jar/jar_stage_3_half.png';
    if (percentage >= 0.2) return 'assets/jar/jar_stage_4_low.png';
    return 'assets/jar/jar_stage_5_empty.png';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingScale.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Premium Glow Background
              Container(
                width: widget.size * 0.85,
                height: widget.size * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35)
                          .withOpacity(_glowOpacity.value),
                      blurRadius: widget.size * 0.2,
                      spreadRadius: widget.size * 0.05,
                    )
                  ],
                ),
              ),
              // Animated Switcher for Jar Images
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  _currentAsset,
                  key: ValueKey<String>(_currentAsset),
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
