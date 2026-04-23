import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../widgets/common_widgets.dart';


class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(employerStatsProvider);
    final activeJobsAsync = ref.watch(employerJobsProvider('active'));
    final recentAsync = ref.watch(recentApplicantsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final balanceAsync = ref.watch(walletBalanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;
    final bgColor = isDark ? AppColors.darkBg : AppColors.surfaceLow;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employer/create-offer'),
        icon: const Icon(Icons.add_rounded),
        label: Text('Nueva oferta', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employerStatsProvider);
          ref.invalidate(employerJobsProvider('active'));
          ref.invalidate(recentApplicantsProvider);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ──────────────────────────────────────────
            SliverAppBar(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
              surfaceTintColor: Colors.transparent,
              floating: true,
              snap: true,
              elevation: 0,
              titleSpacing: 20,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${profile?.fullName.split(' ').first ?? 'Empleador'} 👋',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    profile?.companyName ?? 'Tu panel de empleador',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount', style: const TextStyle(fontSize: 9)),
                    backgroundColor: AppColors.error,
                    child: Icon(Icons.notifications_outlined, color: textPrimary, size: 26),
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Wallet card ─────────────────────────────────
                  _WalletCard(
                    balanceAsync: balanceAsync,
                    isDark: isDark,
                    onTap: () => context.push('/employer/wallet'),
                    onRecharge: () => context.push('/payment/recharge'),
                  ),
                  const SizedBox(height: 24),

                  // ── Stats ───────────────────────────────────────
                  statsAsync.when(
                    loading: () => const Row(
                      children: [
                        Expanded(child: ShimmerLoading(height: 90, borderRadius: 16)),
                        SizedBox(width: 12),
                        Expanded(child: ShimmerLoading(height: 90, borderRadius: 16)),
                        SizedBox(width: 12),
                        Expanded(child: ShimmerLoading(height: 90, borderRadius: 16)),
                      ],
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (stats) => Row(
                      children: [
                        _StatCard(
                          value: '${stats['active_offers'] ?? 0}',
                          label: 'Activas',
                          icon: Icons.work_outline_rounded,
                          color: AppColors.primary,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: '${stats['total_applicants'] ?? 0}',
                          label: 'Postulantes',
                          icon: Icons.people_outline_rounded,
                          color: AppColors.success,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: '${stats['in_progress'] ?? 0}',
                          label: 'En progreso',
                          icon: Icons.pending_actions_rounded,
                          color: AppColors.warning,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Active offers ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ofertas activas',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/employer/offers'),
                        child: Text(
                          'Ver todas',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  activeJobsAsync.when(
                    loading: () => const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      )),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (jobs) {
                      if (jobs.isEmpty) {
                        return _EmptyOffersCard(cardBg: cardBg, textPrimary: textPrimary);
                      }
                      return SizedBox(
                        height: 155,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: jobs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) => _ActiveOfferCard(
                            job: jobs[index],
                            isDark: isDark,
                            textPrimary: textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── Recent applicants ───────────────────────────
                  Text(
                    'Postulantes recientes',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  recentAsync.when(
                    loading: () => Column(
                      children: List.generate(3, (_) => const ShimmerListTile()),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (applicants) {
                      if (applicants.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No hay postulantes aún',
                              style: GoogleFonts.poppins(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.textDark.withValues(alpha: 0.05),
                                    blurRadius: 24,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Column(
                          children: applicants.asMap().entries.map((entry) {
                            final i = entry.key;
                            final a = entry.value;
                            final worker = a['profiles'] as Map<String, dynamic>?;
                            final job = a['job_posts'] as Map<String, dynamic>?;
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: InchambaAvatar(
                                    imageUrl: worker?['avatar_url'] as String?,
                                    fallbackInitials: (worker?['full_name'] as String?)
                                        ?.substring(0, 1)
                                        .toUpperCase(),
                                  ),
                                  title: Text(
                                    worker?['full_name'] as String? ?? 'Trabajador',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Para: ${job?['title'] ?? 'Oferta'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  trailing: Text(
                                    Formatters.timeAgo(DateTime.parse(a['created_at'] as String)),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  onTap: () {
                                    final jobPostId = a['job_post_id'] as String?;
                                    if (jobPostId != null) {
                                      context.push('/employer/offer/$jobPostId');
                                    }
                                  },
                                ),
                                if (i < applicants.length - 1)
                                  Divider(
                                    height: 1,
                                    indent: 70,
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.surfaceLow,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Wallet card ──────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final AsyncValue<double> balanceAsync;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRecharge;

  const _WalletCard({
    required this.balanceAsync,
    required this.isDark,
    required this.onTap,
    required this.onRecharge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Saldo disponible',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            balanceAsync.when(
              loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              error: (_, _) => Text(
                '—',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              data: (balance) => Text(
                Formatters.currency(balance),
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRecharge,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Recargar saldo',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final Color textPrimary;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active offer card ────────────────────────────────────────────────────────
class _ActiveOfferCard extends StatelessWidget {
  final dynamic job;
  final bool isDark;
  final Color textPrimary;

  const _ActiveOfferCard({
    required this.job,
    required this.isDark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;
    return GestureDetector(
      onTap: () => context.push('/employer/offer/${job.id}'),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.categoryEmoji(job.categoryIcon ?? job.categoryName),
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              job.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${job.workersHired}/${job.workersNeeded} contratados',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  Formatters.currency(job.pay),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty offers card ────────────────────────────────────────────────────────
class _EmptyOffersCard extends StatelessWidget {
  final Color cardBg;
  final Color textPrimary;

  const _EmptyOffersCard({
    required this.cardBg,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 155,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline_rounded, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            'No tienes ofertas activas',
            style: GoogleFonts.poppins(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/employer/create-offer'),
            child: Text(
              'Crear primera oferta',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
