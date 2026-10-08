import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// ============================================================
/// SHARED UI KIT — dipakai lintas screen
/// ============================================================

/// Kartu dasar dengan border halus + shadow lembut.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = AppRadius.lg,
    this.color,
    this.onTap,
    this.gradient,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Theme.of(context).cardColor) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: gradient == null ? p.border : Colors.transparent,
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: content,
              ),
            ),
    );
  }
}

/// Header seksi dengan aksen bar + opsional aksi.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 18 : 30,
            decoration: BoxDecoration(
              color: p.brand,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.texts.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.texts.bodySmall?.copyWith(
                      color: p.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Kartu statistik dengan ikon bulat berwarna.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (caption != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    caption!,
                    style: context.texts.labelSmall?.copyWith(color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge/pill kecil.
class AppBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: context.texts.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state yang konsisten.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
              ),
              child: Icon(icon, size: 36, color: p.brand),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(color: p.textMuted),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0, duration: 300.ms);
  }
}

/// Hero panel bergradien — dipakai dashboard & auth.
class HeroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? colors;

  const HeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = AppRadius.xl,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? p.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: p.brand.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ornamen lembut
          Positioned(
            right: -30,
            top: -40,
            child: _orb(120, Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: _orb(90, Colors.white.withValues(alpha: 0.07)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Tombol kecil bergaya pill untuk aksi cepat.
class PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool solid;

  const PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: solid ? p.brand : Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.texts.labelMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Latar bergradien halus untuk halaman auth.
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF0B0F1E), Color(0xFF151A38), Color(0xFF0B0F1E)]
                    : const [Color(0xFFF7F7FE), Color(0xFFEDEBFF), Color(0xFFF7F7FE)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: _blob(280, p.brand.withValues(alpha: isDark ? 0.30 : 0.22)),
        ),
        Positioned(
          bottom: -140,
          right: -90,
          child: _blob(320, p.accent.withValues(alpha: isDark ? 0.18 : 0.16)),
        ),
        Positioned(
          top: 180,
          right: -60,
          child: _blob(200, p.transfer.withValues(alpha: isDark ? 0.16 : 0.13)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _blob(double size, Color color) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}
