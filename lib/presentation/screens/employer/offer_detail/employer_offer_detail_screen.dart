import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';
import '../../../../data/models/work_completion_model.dart';

final workCompletionsProvider = FutureProvider.family<List<WorkCompletionModel>, String>((ref, jobPostId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final data = await ds.getWorkCompletions(jobPostId);
  return data.map((w) => WorkCompletionModel.fromJson(w)).toList();
});

class EmployerOfferDetailScreen extends ConsumerWidget {
  final String jobPostId;

  const EmployerOfferDetailScreen({super.key, required this.jobPostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobPostId));
    final appsAsync = ref.watch(jobApplicationsProvider(jobPostId));
    final completionsAsync = ref.watch(workCompletionsProvider(jobPostId));

    return jobAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
      data: (job) {
        return Scaffold(
          appBar: AppBar(
            title: Text(job.title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job info summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(Formatters.categoryEmoji(job.categoryIcon ?? job.categoryName), style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                                Text('${Formatters.currency(job.pay)} ${Formatters.payType(job.payType)}',
                                    style: GoogleFonts.poppins(color: AppColors.success, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          StatusChip.fromStatus(job.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.group, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${job.workersHired}/${job.workersNeeded} trabajadores aceptados',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      if (job.spotsLeft > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Faltan ${job.spotsLeft} trabajador${job.spotsLeft > 1 ? "es" : ""}',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Work completions pending
                completionsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (completions) {
                    final pending = completions.where((c) => c.isPending).toList();
                    if (pending.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitudes de confirmación',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        ...pending.map((completion) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        InchambaAvatar(
                                          imageUrl: completion.workerAvatar,
                                          fallbackInitials: completion.workerName?.substring(0, 1).toUpperCase(),
                                          radius: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            completion.workerName ?? 'Trabajador',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        StatusChip.fromStatus('pending'),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      completion.completionNote ?? '',
                                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (completion.evidenceUrls.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('${completion.evidenceUrls.length} foto(s) de evidencia',
                                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.info)),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => context.push(
                                          '/employer/offer/$jobPostId/confirm-work/${completion.id}',
                                        ),
                                        child: const Text('Revisar y confirmar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                // Applicants
                Text(
                  'Postulantes',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                appsAsync.when(
                  loading: () => Column(children: List.generate(3, (_) => const ShimmerListTile())),
                  error: (e, _) => Text('Error: $e'),
                  data: (apps) {
                    if (apps.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surfaceDim),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('No hay postulantes aún', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      );
                    }

                    final accepted = apps.where((a) => a.isAccepted).toList();
                    final pendingApps = apps.where((a) => a.isPending).toList();
                    final rejected = apps.where((a) => a.isRejected).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (accepted.isNotEmpty) ...[
                          Text('Aceptados (${accepted.length})',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                          const SizedBox(height: 8),
                          ...accepted.map((app) => _ApplicantCard(
                                app: app,
                                jobPostId: jobPostId,
                                canAccept: false,
                                canReject: false,
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (pendingApps.isNotEmpty) ...[
                          Text('Pendientes (${pendingApps.length})',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.warning)),
                          const SizedBox(height: 8),
                          ...pendingApps.map((app) => _ApplicantCard(
                                app: app,
                                jobPostId: jobPostId,
                                canAccept: !job.isFull,
                                canReject: true,
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (rejected.isNotEmpty) ...[
                          Text('Rechazados (${rejected.length})',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                          const SizedBox(height: 8),
                          ...rejected.map((app) => _ApplicantCard(
                                app: app,
                                jobPostId: jobPostId,
                                canAccept: false,
                                canReject: false,
                              )),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApplicantCard extends ConsumerWidget {
  final dynamic app;
  final String jobPostId;
  final bool canAccept;
  final bool canReject;

  const _ApplicantCard({
    required this.app,
    required this.jobPostId,
    required this.canAccept,
    required this.canReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/${app.workerId}'),
                  child: InchambaAvatar(
                    imageUrl: app.workerAvatar,
                    fallbackInitials: app.workerName?.substring(0, 1).toUpperCase(),
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile/${app.workerId}'),
                        child: Text(
                          app.workerName ?? 'Trabajador',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      Row(
                        children: [
                          if (app.workerRating != null) ...[
                            StarRating(rating: app.workerRating!, size: 12),
                            const SizedBox(width: 4),
                          ],
                          if (app.workerJobsCompleted != null)
                            Text(
                              '${app.workerJobsCompleted} trabajos',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusChip.fromStatus(app.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              Formatters.truncate(app.coverLetter, 120),
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight),
            ),
            if (app.attachmentUrls.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${app.attachmentUrls.length} adjunto(s)',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.info)),
            ],
            if (canAccept || canReject) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canReject)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Rechazar postulante'),
                              content: const Text('¿Estás seguro de rechazar esta postulación?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rechazar')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final ds = ref.read(supabaseDatasourceProvider);
                            await ds.updateApplicationStatus(app.id, 'rejected');
                            ref.invalidate(jobApplicationsProvider(jobPostId));
                          }
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                        child: const Text('Rechazar'),
                      ),
                    ),
                  if (canAccept && canReject) const SizedBox(width: 10),
                  if (canAccept)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final ds = ref.read(supabaseDatasourceProvider);
                          await ds.updateApplicationStatus(app.id, 'accepted');
                          // Increment workers_hired
                          await ds.updateJobPost(jobPostId, {
                            'workers_hired': (ref.read(jobDetailProvider(jobPostId)).value?.workersHired ?? 0) + 1,
                          });
                          ref.invalidate(jobApplicationsProvider(jobPostId));
                          ref.invalidate(jobDetailProvider(jobPostId));
                        },
                        child: const Text('Aceptar'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
