import 'package:flutter/material.dart';

class StyledAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool isEditMode;

  const StyledAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onSave,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Back Button
            _buildCircularButton(
              icon: Icons.arrow_back,
              onTap: onBack,
              gradientColors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            const SizedBox(width: 16),
            
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            
            // Save/Check Button
            _buildCircularButton(
              icon: isEditMode ? Icons.edit : Icons.check,
              iconColor: isEditMode ? Colors.orangeAccent : Colors.blueAccent,
              onTap: onSave,
              gradientColors: [
                (isEditMode ? Colors.orangeAccent : Colors.blueAccent).withValues(alpha: 0.2),
                (isEditMode ? Colors.orangeAccent : Colors.purpleAccent).withValues(alpha: 0.05),
              ],
              borderColor: (isEditMode ? Colors.orangeAccent : Colors.blueAccent).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> gradientColors,
    Color iconColor = Colors.white,
    Color borderColor = Colors.white12,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80.0);
}
