import 'package:flutter/material.dart';

/// Shared, theme-aware UI building blocks used across Yatra screens.

/// Returns the semantic colour for a package difficulty level.
Color difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'Easy':
      return Colors.green.shade700;
    case 'Moderate':
      return Colors.orange.shade800;
    case 'Challenging':
      return Colors.red.shade700;
    default:
      return Colors.blueGrey;
  }
}

/// A section heading used consistently across screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// A friendly, theme-aware empty state.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: scheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

/// An outlined info box with the shared brand-aligned border + radius.
class InfoBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderSide Function(Color borderColor)? border;

  const InfoBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border?.call(scheme.outlineVariant).color ??
              scheme.outlineVariant,
          width: border?.call(scheme.outlineVariant).width ?? 1,
        ),
      ),
      child: child,
    );
  }
}

/// A package/place cover image that falls back to a branded gradient
/// placeholder when the asset is missing.
class CoverImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final BorderRadius borderRadius;

  const CoverImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final image = Image.asset(
      imageUrl,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primaryContainer, scheme.primary],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.landscape, size: 48, color: scheme.onPrimary),
        );
      },
    );

    if (borderRadius == BorderRadius.zero) {
      return image;
    }

    return ClipRRect(borderRadius: borderRadius, child: image);
  }
}
