import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable, theme-aware Yatra UI components.
///
/// Keep shared pieces here instead of re-implementing styled containers,
/// buttons or headings inside each screen.

/// The prominent primary call-to-action. Full width unless [expanded] is
/// `false`.
class YatraPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  const YatraPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
      label: Text(label),
    );

    if (!expanded) return Align(alignment: Alignment.centerLeft, child: button);

    return SizedBox(width: double.infinity, child: button);
  }
}

/// A secondary / outlined action.
class YatraSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  const YatraSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            child: Text(label),
          );

    if (!expanded) return Align(alignment: Alignment.centerLeft, child: button);

    return SizedBox(width: double.infinity, child: button);
  }
}

/// A consistent card surface.
class YatraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool padded;

  const YatraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = padded
        ? Padding(padding: padding, child: child)
        : child;

    final card = Card(
      margin: EdgeInsets.zero,
      child: content,
    );

    if (onTap == null) return card;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// A section heading with optional supporting text.
class YatraSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const YatraSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// A selectable pill chip used for filters / single or multiple choice.
class YatraChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool isFilter;

  const YatraChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.isFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFilter) {
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
      );
    }
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// A tappable selection card (destination/type/option pickers).
class YatraSelectionCard extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? leadingIcon;

  const YatraSelectionCard({
    super.key,
    required this.child,
    required this.selected,
    this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: selected ? scheme.primary : AppColors.onSurfaceHint,
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: child),
            if (selected)
              Icon(Icons.check_circle, color: scheme.primary, size: 22)
            else
              Icon(
                Icons.circle_outlined,
                color: scheme.outlineVariant,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Label/value row used in details & summaries.
class YatraInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const YatraInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: textTheme.bodySmall),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: emphasized
                  ? textTheme.bodyMedium
                  : AppType.bodyEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A friendly empty state placeholder.
class YatraEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;

  const YatraEmptyState({
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
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: scheme.outline),
          const SizedBox(height: AppSpacing.lg),
          Text(message, textAlign: TextAlign.center, style: textTheme.titleMedium),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// A coloured status badge (available / warning / etc).
class YatraStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const YatraStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// A visual-only step indicator for the trip-planning wizard
/// (e.g. `01 ━ 02 ━ 03 ━ 04`).
///
/// This does NOT navigate; it only reflects the current [currentStep].
class YatraStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const YatraStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var step = 1; step <= totalSteps; step++) ...[
          if (step > 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: step <= currentStep
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: step <= currentStep
                  ? scheme.primary
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: step <= currentStep ? scheme.primary : scheme.outline,
                width: 1.5,
              ),
            ),
            child: Text(
              step.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: step <= currentStep ? Colors.white : scheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared wizard page header: a visual step indicator plus a clear question
/// with a short helpful subtitle. Used across the setup screens so they read
/// as one guided flow.
class YatraWizardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int step;
  final int totalSteps;

  const YatraWizardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YatraStepIndicator(currentStep: step, totalSteps: totalSteps),
          const SizedBox(height: AppSpacing.xxl),
          Text(title, style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: textTheme.bodyLarge),
        ],
      );
    }
  }

/// A full-width, theme-consistent social sign-in button (e.g. Google,
/// Facebook, Apple). Shows a provider icon tile, a label and an optional
/// loading state. When [loading] is true the button is disabled and shows a
/// progress indicator instead of the trailing chevron.
class YatraSocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  const YatraSocialButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final isEnabled = enabled && !loading && onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    color: scheme.primary.withValues(alpha: 0.08),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppType.label.copyWith(fontSize: 15),
                  ),
                ),
                if (loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: scheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A centered divider row with a label, e.g. "or continue with".
class YatraDivider extends StatelessWidget {
  final String label;

  const YatraDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        const Expanded(child: Divider()),
        const SizedBox(width: AppSpacing.lg),
        Text(label, style: textTheme.bodySmall),
        const SizedBox(width: AppSpacing.lg),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// A country entry for the phone input's code selector.
class YatraCountry {
  final String name;
  final String code;

  const YatraCountry({required this.name, required this.code});
}

/// A small, theme-consistent pool of common countries. Used as the default
/// selector list for [YatraPhoneInput]. Firebase phone auth only needs the
/// dial code, so this list is intentionally compact.
const kYatraDefaultCountries = <YatraCountry>[
  YatraCountry(name: 'Nepal', code: '+977'),
  YatraCountry(name: 'India', code: '+91'),
  YatraCountry(name: 'United States', code: '+1'),
  YatraCountry(name: 'United Kingdom', code: '+44'),
  YatraCountry(name: 'Australia', code: '+61'),
  YatraCountry(name: 'Canada', code: '+1'),
  YatraCountry(name: 'Germany', code: '+49'),
];

/// A reusable phone number input with an inline country-code selector.
///
/// Pairs a compact dropdown of dial codes with the phone number field. The
/// dropdown code is surfaced through [onCountryCodeChanged]; the digits through
/// [onChanged]. Suitable for both the phone-auth screen and a future phone-based
/// signup.
class YatraPhoneInput extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final String? helperText;
  final bool autofocus;

  /// The currently selected dial code, e.g. `+977`.
  final String countryCode;

  /// Called whenever the user picks a different country.
  final ValueChanged<String> onCountryCodeChanged;

  /// The list of countries offered by the selector.
  final List<YatraCountry> countries;

  /// Optional button that labels the leading dial-code selector, e.g.
  /// "NEP +977". Defaults to the bare dial code.
  final bool showCountryName;

  const YatraPhoneInput({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.helperText,
    this.autofocus = false,
    required this.countryCode,
    required this.onCountryCodeChanged,
    this.countries = kYatraDefaultCountries,
    this.showCountryName = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = countries.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => YatraCountry(name: countryCode, code: countryCode),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CountrySelector(
              selected: selected,
              countries: countries,
              onChanged: onCountryCodeChanged,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (value) => onSubmitted?.call(value),
                keyboardType: TextInputType.phone,
                autofocus: autofocus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. 9812345678',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: errorText,
                ),
              ),
            ),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _CountrySelector extends StatelessWidget {
  final YatraCountry selected;
  final List<YatraCountry> countries;
  final ValueChanged<String> onChanged;

  const _CountrySelector({
    required this.selected,
    required this.countries,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Render the selector as a small bordered chip with a caret. A filled
    // anchor (instead of raw text) makes it tappable across the whole chip.
    return PopupMenuButton<String>(
      onSelected: onChanged,
      tooltip: 'Select country code',
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      itemBuilder: (context) => [
        for (final c in countries)
          PopupMenuItem<String>(
            value: c.code,
            child: Row(
              children: [
                const Icon(Icons.public, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text('${c.name} (${c.code})'),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        height: 56,
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 132),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                selected.code,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A six-digit OTP entry rendered as six independent boxes.
///
/// Handles auto-focus, focus advance/retreat as digits are typed, a numeric
/// keyboard and [enabled] gating. The full entered code is emitted through
/// [onChanged] on every keystroke. The raw code is kept only in local
/// controllers and is never logged or displayed in a plain text field.
class YatraOtpInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;
  final bool autofocus;

  const YatraOtpInput({
    super.key,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.autofocus = true,
  });

  /// How many digits the OTP uses. Firebase OTPS are 6 digits.
  static const int length = 6;

  @override
  State<YatraOtpInput> createState() => _YatraOtpInputState();
}

class _YatraOtpInputState extends State<YatraOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final String _buffer;

  @override
  void initState() {
    super.initState();
    _buffer = '';
    _controllers =
        List.generate(YatraOtpInput.length, (_) => TextEditingController());
    _focusNodes =
        List.generate(YatraOtpInput.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleChange(int index, String value) {
    // Keep only the digit, at most one, in this box.
    final digit = value.isEmpty ? '' : value[value.length - 1];
    _controllers[index].text = digit;

    final code = _currentCode();

    // Auto-advance once a digit is entered.
    if (digit.isNotEmpty && index < YatraOtpInput.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (digit.isEmpty && index > 0) {
      // Clearing a digit returns focus to the previous box.
      _focusNodes[index - 1].requestFocus();
    }

    if (code != _buffer) {
      _buffer = code;
      widget.onChanged(code);
    }
  }

  String _currentCode() {
    final buf = StringBuffer();
    for (final c in _controllers) {
      final t = c.text;
      if (t.isNotEmpty) buf.write(t[t.length - 1]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < YatraOtpInput.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 46,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  enabled: widget.enabled,
                  autofocus: widget.autofocus && i == 0,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: AppType.headline.copyWith(fontSize: 22),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '•',
                    hintStyle:
                        AppType.body.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  onChanged: (v) => _handleChange(i, v),
                ),
              ),
            ],
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText!,
            style: AppType.caption.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}
