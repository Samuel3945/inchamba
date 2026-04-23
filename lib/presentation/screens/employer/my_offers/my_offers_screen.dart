import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';

class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mis Ofertas', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
              Tab(text: 'Activas'),
              Tab(text: 'Pendiente pago'),
              Tab(text: 'En progreso'),
              Tab(text: 'Completadas'),
              Tab(text: 'Canceladas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OfferList(status: 'active'),
            _OfferList(status: 'pending_payment'),
            _OfferList(status: 'in_progress'),
            _OfferList(status: 'completed'),
            _OfferList(status: 'cancelled'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/employer/create-offer'),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _OfferList extends ConsumerWidget {
  final String status;

  const _OfferList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(employerJobsProvider(status));

    return jobsAsync.when(
      loading: () => ListView.builder(
        itemCount: 3,
        itemBuilder: (_, _) => const ShimmerJobCard(),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (jobs) {
        if (jobs.isEmpty) {
          return EmptyState(
            icon: Icons.work_off_outlined,
            title: 'No tienes ofertas ${_statusLabel(status).toLowerCase()}',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(employerJobsProvider(status)),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              final isPending = job.status == 'pending_payment';
              return Card(
                child: InkWell(
                  onTap: isPending
                      ? () => context.push('/payment/${job.id}')
                      : () => context.push('/employer/offer/${job.id}'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              Formatters.categoryEmoji(job.categoryIcon ?? job.categoryName),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                job.title,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusChip.fromStatus(job.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.group_outlined, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${job.workersHired}/${job.workersNeeded}',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.payments_outlined, size: 16, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.currency(job.pay * job.workersNeeded),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Formatters.timeAgo(job.createdAt),
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        if (isPending) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmCancel(context, ref, job.id, job.title),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  label: const Text('Eliminar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push('/payment/${job.id}'),
                                  icon: const Icon(Icons.payment_rounded, size: 16),
                                  label: const Text('Pagar'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
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

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String jobId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar oferta'),
        content: Text('¿Eliminar "$title"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ds = ref.read(supabaseDatasourceProvider);
      final result = await ds.cancelPendingJob(jobId);
      if (result['success'] == true) {
        ref.invalidate(employerJobsProvider('pending_payment'));
        ref.invalidate(employerJobsProvider('cancelled'));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oferta eliminada'), backgroundColor: AppColors.success),
          );
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'activas';
      case 'pending_payment': return 'pendientes de pago';
      case 'in_progress': return 'en progreso';
      case 'completed': return 'completadas';
      case 'cancelled': return 'canceladas';
      default: return status;
    }
  }
}
