import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
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
          title: Text(AppStrings.myApplications, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: AppStrings.pending),
              Tab(text: AppStrings.accepted),
              Tab(text: AppStrings.rejected),
              Tab(text: AppStrings.completed),
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
        itemBuilder: (_, __) => const ShimmerJobCard(),
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
            padding: const EdgeInsets.only(top: 8),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return Card(
                child: InkWell(
                  onTap: () => context.push('/job/${app.jobPostId}'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.jobTitle ?? 'Oferta',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusChip.fromStatus(app.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (app.employerName != null)
                          Text(
                            app.employerName!,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                          ),
                        if (app.jobPay != null)
                          Text(
                            '${Formatters.currency(app.jobPay!)} ${app.jobPayType != null ? Formatters.payType(app.jobPayType!) : ""}',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.success),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          Formatters.timeAgo(app.createdAt),
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                        ),
                        if (app.isAccepted) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/job/${app.jobPostId}/mark-completed/${app.id}'),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text(AppStrings.markCompleted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _emptyMessage(String status) {
    switch (status) {
      case 'pending':
        return 'No tienes postulaciones pendientes';
      case 'accepted':
        return 'No tienes postulaciones aceptadas';
      case 'rejected':
        return 'No tienes postulaciones rechazadas';
      case 'completed':
        return 'No tienes trabajos completados';
      default:
        return 'No hay postulaciones';
    }
  }
}
