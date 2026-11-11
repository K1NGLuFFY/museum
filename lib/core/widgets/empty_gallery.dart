import 'package:flutter/cupertino.dart';

import '../theme/museum_theme.dart';

class EmptyGallery extends StatelessWidget {
  const EmptyGallery({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
    decoration: BoxDecoration(
      color: MuseumColors.resolve(MuseumColors.surface, context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: MuseumColors.resolve(MuseumColors.divider, context),
      ),
    ),
    child: Column(
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 36,
            color: MuseumColors.resolve(MuseumColors.accent, context),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: MuseumColors.resolve(MuseumColors.secondary, context),
            ),
          ),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 22),
          CupertinoButton.filled(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}
