import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/constants/app_colors.dart';

class ShellScaffold extends ConsumerWidget {
  final bool isEmployer;
  final Widget child;

  const ShellScaffold({
    super.key,
    required this.isEmployer,
    required this.child,
  });

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final prefix = isEmployer ? '/employer' : '/worker';
    if (location == prefix) return 0;
    // Worker: Dashboard(0) | Progreso(1) | Perfil(2)
    if (!isEmployer && location == '/worker/progress') return 1;
    if (location == '$prefix/profile') return isEmployer ? 1 : 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final prefix = isEmployer ? '/employer' : '/worker';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppColors.darkSurface : AppColors.surfaceLowest;

    final items = isEmployer
        ? [
            _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', selected: index == 0, onTap: () => context.go(prefix)),
            _NavItem(icon: Icons.person_rounded, label: 'Perfil', selected: index == 1, onTap: () => context.go('$prefix/profile')),
          ]
        : [
            _NavItem(icon: Icons.home_rounded, label: 'Inicio', selected: index == 0, onTap: () => context.go(prefix)),
            _NavItem(icon: Icons.school_rounded, label: 'Progreso', selected: index == 1, onTap: () => context.go('$prefix/progress')),
            _NavItem(icon: Icons.person_rounded, label: 'Perfil', selected: index == 2, onTap: () => context.go('$prefix/profile')),
          ];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.5)
                  : AppColors.surfaceDim.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: items),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected ? AppColors.primary : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
