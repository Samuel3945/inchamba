import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class InchambaAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? fallbackInitials;

  const InchambaAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.fallbackInitials,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(imageUrl!),
        backgroundColor: AppColors.darkSurface,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: Text(
        fallbackInitials ?? '?',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkCard : Colors.grey[300]!,
      highlightColor: isDark ? AppColors.darkBorder : Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ShimmerLoading(height: 48, width: 48, borderRadius: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(height: 14, width: 150),
                SizedBox(height: 8),
                ShimmerLoading(height: 10, width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerJobCard extends StatelessWidget {
  const ShimmerJobCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLoading(height: 18, width: 200),
            SizedBox(height: 10),
            ShimmerLoading(height: 14, width: 120),
            SizedBox(height: 10),
            Row(
              children: [
                ShimmerLoading(height: 28, width: 80, borderRadius: 14),
                SizedBox(width: 8),
                ShimmerLoading(height: 28, width: 100, borderRadius: 14),
              ],
            ),
            SizedBox(height: 10),
            ShimmerLoading(height: 14, width: 80),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<int>? onChanged;
  final int currentValue;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.interactive = false,
    this.onChanged,
    this.currentValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (interactive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return GestureDetector(
            onTap: () => onChanged?.call(i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                i < currentValue ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.star,
                size: size,
              ),
            ),
          );
        }),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star_rounded, color: AppColors.star, size: size);
        } else if (i < rating) {
          return Icon(Icons.star_half_rounded, color: AppColors.star, size: size);
        }
        return Icon(Icons.star_outline_rounded, color: AppColors.star, size: size);
      }),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.fromStatus(String status) {
    switch (status) {
      case 'pending':
        return const StatusChip(label: 'Pendiente', color: AppColors.warning);
      case 'accepted':
        return const StatusChip(label: 'Aceptado', color: AppColors.success);
      case 'rejected':
        return const StatusChip(label: 'Rechazado', color: AppColors.error);
      case 'completed':
        return const StatusChip(label: 'Completado', color: AppColors.info);
      case 'active':
        return const StatusChip(label: 'Activa', color: AppColors.success);
      case 'in_progress':
        return const StatusChip(label: 'En progreso', color: AppColors.info);
      case 'pending_payment':
        return const StatusChip(label: 'Pendiente pago', color: AppColors.warning);
      case 'cancelled':
        return const StatusChip(label: 'Cancelada', color: AppColors.error);
      case 'held':
        return const StatusChip(label: 'En escrow', color: AppColors.escrow);
      case 'released':
        return const StatusChip(label: 'Liberado', color: AppColors.success);
      case 'open':
        return const StatusChip(label: 'Abierta', color: AppColors.warning);
      case 'reviewing':
        return const StatusChip(label: 'En revisión', color: AppColors.info);
      case 'resolved':
        return const StatusChip(label: 'Resuelta', color: AppColors.success);
      default:
        return StatusChip(label: status, color: AppColors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingText;

  const LoadingOverlay({super.key, required this.isLoading, required this.child, this.loadingText});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  if (loadingText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      loadingText!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
