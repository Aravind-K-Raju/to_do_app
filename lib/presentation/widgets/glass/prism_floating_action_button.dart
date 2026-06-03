import 'dart:ui';
import 'package:flutter/material.dart';

class PrismFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String heroTag;

  const PrismFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.heroTag = '<default_fab_tag>',
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.6),
                        const Color(0xFF8CE6FF).withValues(alpha: 0.15), // Cyan tint
                        const Color(0xFFFF8CC6).withValues(alpha: 0.1),  // Pink tint
                        const Color(0xFFFFF08C).withValues(alpha: 0.15), // Yellow tint
                        Colors.white.withValues(alpha: 0.3),
                      ],
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  // Inner glow effect
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: RadialGradient(
                        center: const Alignment(-0.5, -0.5),
                        radius: 1.5,
                        colors: [
                          Colors.white.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
