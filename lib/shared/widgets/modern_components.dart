import 'package:flutter/material.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';

// =============================================================================
// MODERN UI COMPONENTS & UTILITIES
// =============================================================================
//
// This file provides reusable, beautifully designed components for the
// Ledger app following modern design principles:
//
// - Consistency: All components follow Material 3 & modern design patterns
// - Accessibility: Proper contrast ratios and touch targets
// - Animation: Smooth transitions for better UX
// - Responsiveness: Adapts to different screen sizes

/// Modern card wrapper with elevation and border styling
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final void Function()? onTap;
  final bool elevated;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 14,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.elevated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.surfaceVariantDark,
          width: borderWidth,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

/// Modern section header with optional subtitle
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modern stat display with icon and label
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final Color? iconColor;

  const StatTile({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gray700,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyles.titleMedium.copyWith(
              color: valueColor ?? AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern status badge with color coding
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final double fontSize;

  const StatusBadge({
    Key? key,
    required this.label,
    this.backgroundColor = AppColors.primary,
    this.textColor = AppColors.textOnPrimary,
    this.icon,
    this.fontSize = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern empty state with icon and message
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariantDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 40,
              color: iconColor ?? AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyles.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Modern progress indicator with label
class ProgressIndicator extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String? label;
  final Color backgroundColor;
  final Color progressColor;
  final double height;
  final double borderRadius;

  const ProgressIndicator({
    Key? key,
    required this.value,
    this.label,
    this.backgroundColor = AppColors.surfaceVariantDark,
    this.progressColor = AppColors.primary,
    this.height = 8,
    this.borderRadius = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: height,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

/// Modern divider with optional label
class ModernDivider extends StatelessWidget {
  final String? label;
  final EdgeInsets padding;
  final Color color;

  const ModernDivider({
    Key? key,
    this.label,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.color = AppColors.surfaceVariantDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: padding,
        child: Divider(
          color: color,
          height: 1,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Divider(color: color, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label!,
              style: TextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: color, height: 1),
          ),
        ],
      ),
    );
  }
}

/// Modern input field wrapper
class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType keyboardType;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const ModernTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyles.bodyLarge.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: TextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textTertiary)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

