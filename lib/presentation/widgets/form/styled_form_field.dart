import 'package:flutter/material.dart';

class StyledFormField extends StatelessWidget {
  final String label;
  final Widget child;
  final IconData icon;
  final Color iconColor;
  final String? helperText;
  final Widget? trailing;
  final VoidCallback? onTap;

  const StyledFormField({
    super.key,
    required this.label,
    required this.child,
    required this.icon,
    this.iconColor = const Color(0xFF7C3AED), // Default to primary purple
    this.helperText,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161824), // Dark slightly elevated background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Form Field Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Provide an unconstrained/borderless theme to the child
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
                
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!,
                ],
              ],
            ),
          ),
          if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    helperText!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    
    return content;
  }
}
