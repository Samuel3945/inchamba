import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/job_application_model.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';

class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mis Postulaciones', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
          bottom: TabBar(
            isScrollable: true,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: const [
              Tab(text: 'Pendientes'),
              Tab(text: 'Aceptadas'),
              Tab(text: 'Rechazadas'),
              Tab(text: 'Completadas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ApplicationList(status: 'pending'),
            _ApplicationList(status: 'accepted'),
            _ApplicationList(status: 'rejected'),
            _ApplicationList(status: 'completed'),
          ],
        ),
      ),
    );
  }
}

class _ApplicationList extends ConsumerWidget {
  final String status;
  const _ApplicationList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(workerApplicationsProvider(status));

    return appsAsync.when(
      loading: () => ListView.builder(
        itemCount: 4,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, _) => const ShimmerJobCard(),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (apps) {
        if (apps.isEmpty) {
          return EmptyState(
            icon: Icons.assignment_outlined,
            title: _emptyMessage(status),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workerApplicationsProvider(status)),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: apps.length,
            itemBuilder: (context, index) => _ApplicationCard(
              app: apps[index],
              onTap: () => context.push('/job/${apps[index].jobPostId}'),
            ),
          ),
        );
      },
    );
  }

  String _emptyMessage(String s) {
    switch (s) {
      case 'pending':   return 'No tienes postulaciones pendientes';
      case 'accepted':  return 'No tienes postulaciones aceptadas';
      case 'rejected':  return 'No tienes postulaciones rechazadas';
      case 'completed': return 'No tienes trabajos completados';
      default:          return 'No hay postulaciones';
    }
  }
}

class _ApplicationCard extends StatelessWidget {
  final JobApplicationModel app;
  final VoidCallback onTap;

  const _ApplicationCard({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(app.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: title + badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        app.jobTitle ?? 'Oferta sin título',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: app.status),
                  ],
                ),
                const SizedBox(height: 8),

                // Category chip
                if (app.jobCategory != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppConstants.jobCategories[app.jobCategory] ?? app.jobCategory!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Pay + employer row
                Row(
                  children: [
                    if (app.jobPay != null) ...[
                      const Icon(Icons.attach_money_rounded, size: 16, color: AppColors.success),
                      Text(
                        '${Formatters.currency(app.jobPay!)} ${app.jobPayType != null ? Formatters.payType(app.jobPayType!) : ""}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (app.jobCity != null) ...[
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text(
                        app.jobCity!,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),

                if (app.employerName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.business_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        app.employerName!,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // Footer: time + action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.timeAgo(app.createdAt),
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                    ),
                    if (app.isAccepted)
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/job/${app.jobPostId}/mark-completed/${app.id}'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(
                            'Marcar completado',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    if (app.status == 'completed')
                      const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':  return AppColors.success;
      case 'rejected':  return AppColors.error;
      case 'completed': return AppColors.info;
      default:          return AppColors.warning;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted'  => ('Aceptada', AppColors.success),
      'rejected'  => ('Rechazada', AppColors.error),
      'completed' => ('Completada', AppColors.info),
      _           => ('Pendiente', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
