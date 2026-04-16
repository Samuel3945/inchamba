import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';

final employerStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return {};
  return await ds.getEmployerStats(userId);
});

final recentApplicantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  return await ds.getRecentApplicants(userId);
});

class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(employerStatsProvider);
    final activeJobsAsync = ref.watch(employerJobsProvider('active'));
    final recentAsync = ref.watch(recentApplicantsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Inchamba', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary)),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount', style: const TextStyle(fontSize: 10)),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employerStatsProvider);
          ref.invalidate(employerJobsProvider('active'));
          ref.invalidate(recentApplicantsProvider);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Hola, ${profile?.fullName.split(' ').first ?? ''}',
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                profile?.companyName ?? 'Tu dashboard de empleador',
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              // Stats
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
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(
                  children: [
                    _StatCard(
                      value: '${stats['active_offers'] ?? 0}',
                      label: 'Activas',
                      icon: Icons.work_outline,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      value: '${stats['total_applicants'] ?? 0}',
                      label: 'Postulantes',
                      icon: Icons.people_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      value: '${stats['in_progress'] ?? 0}',
                      label: 'En progreso',
                      icon: Icons.pending_actions,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Active offers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ofertas activas', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: () => context.go('/employer/offers'),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              activeJobsAsync.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (_, __) => const Text('Error cargando ofertas'),
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.darkBorder),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline, size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Text('No tienes ofertas activas', style: GoogleFonts.poppins(color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.push('/employer/create-offer'),
                            child: const Text('Crear primera oferta'),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return GestureDetector(
                          onTap: () => context.push('/employer/offer/${job.id}'),
                          child: Container(
                            width: 260,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
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
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Text(
                                      '${job.workersHired}/${job.workersNeeded} trabajadores',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Formatters.currency(job.pay),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              // Recent applicants
              Text('Postulantes recientes', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              recentAsync.when(
                loading: () => Column(
                  children: List.generate(3, (_) => const ShimmerListTile()),
                ),
                error: (_, __) => const Text('Error cargando postulantes'),
                data: (applicants) {
                  if (applicants.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                        child: Text('No hay postulantes aún', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    );
                  }
                  return Column(
                    children: applicants.map((a) {
                      final worker = a['profiles'] as Map<String, dynamic>?;
                      final job = a['job_posts'] as Map<String, dynamic>?;
                      return ListTile(
                        leading: InchambaAvatar(
                          imageUrl: worker?['avatar_url'] as String?,
                          fallbackInitials: (worker?['full_name'] as String?)?.substring(0, 1).toUpperCase(),
                        ),
                        title: Text(worker?['full_name'] as String? ?? 'Trabajador'),
                        subtitle: Text(
                          'Para: ${job?['title'] ?? 'Oferta'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          Formatters.timeAgo(DateTime.parse(a['created_at'] as String)),
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                        ),
                        onTap: () {
                          final jobPostId = a['job_post_id'] as String?;
                          if (jobPostId != null) context.push('/employer/offer/$jobPostId');
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employer/create-offer'),
        icon: const Icon(Icons.add_rounded),
        label: Text('Nueva oferta', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
