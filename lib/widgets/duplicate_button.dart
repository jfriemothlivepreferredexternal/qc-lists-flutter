import 'package:flutter/material.dart';

class DuplicateButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final ButtonStyle? style;
  final bool iconOnly;

  const DuplicateButton({
    super.key,
    required this.onPressed,
    this.label = 'Duplicate',
    this.icon = Icons.content_copy_outlined,
    this.style,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: Colors.purple.shade100,
          foregroundColor: Colors.purple.shade700,
        ),
        tooltip: label,
      );
    }
    
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: style ?? ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }
}
