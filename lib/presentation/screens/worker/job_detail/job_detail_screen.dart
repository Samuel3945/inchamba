import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';

class JobDetailScreen extends ConsumerWidget {
  final String jobPostId;

  const JobDetailScreen({super.key, required this.jobPostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobPostId));
    final applicationAsync = ref.watch(myApplicationForJobProvider(jobPostId));
    final isEmployer = ref.watch(isEmployerProvider);
    final profile = ref.watch(currentProfileProvider);

    return jobAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (job) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Banner
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        Formatters.categoryEmoji(job.categoryIcon ?? job.categoryName),
                        style: const TextStyle(fontSize: 72),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employer info
                      Row(
                        children: [
                          InchambaAvatar(
                            imageUrl: job.employerAvatar,
                            fallbackInitials: job.employerName?.substring(0, 1).toUpperCase(),
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/profile/${job.employerId}'),
                                  child: Text(
                                    job.employerName ?? 'Empleador',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (job.employerRating != null) ...[
                                      StarRating(rating: job.employerRating!, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        Formatters.rating(job.employerRating!),
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (job.isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.urgent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppStrings.urgent,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.urgent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        job.title,
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      // Category & Pay
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              Formatters.categoryLabel(job.categoryName),
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${Formatters.currency(job.pay)} ${Formatters.payType(job.payType)}',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Description
                      Text(
                        'Descripción',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.description,
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight, height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      // Details
                      Text(
                        'Detalles',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(icon: Icons.payments_outlined, label: 'Paga', value: '${Formatters.currency(job.pay)} ${Formatters.payType(job.payType)}'),
                      _DetailRow(icon: Icons.group_outlined, label: 'Trabajadores', value: '${job.workersHired}/${job.workersNeeded}'),
                      if (job.startDate != null)
                        _DetailRow(icon: Icons.calendar_today_outlined, label: 'Inicio', value: Formatters.date(job.startDate!)),
                      if (job.durationDays != null)
                        _DetailRow(icon: Icons.timer_outlined, label: 'Duración', value: '${job.durationDays} día(s)'),
                      if (job.schedule != null)
                        _DetailRow(icon: Icons.schedule_outlined, label: 'Horario', value: job.schedule!),
                      if (job.requirements.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Requisitos',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: job.requirements
                              .map((r) => Chip(label: Text(r)))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Location
                      Text(
                        'Ubicación',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            job.address != null ? '${job.city} - ${job.address}' : job.city,
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      // Application status
                      applicationAsync.when(
                        data: (app) {
                          if (app == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18),
                                const SizedBox(width: 8),
                                Text('Estado de tu postulación: ', style: GoogleFonts.poppins(fontSize: 14)),
                                StatusChip.fromStatus(app.status),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: isEmployer
              ? null
              : applicationAsync.when(
                  data: (app) {
                    if (app != null) return null;
                    if (job.isFull) {
                      return FloatingActionButton.extended(
                        onPressed: null,
                        backgroundColor: AppColors.textMuted,
                        label: Text(AppStrings.offerFull, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        icon: const Icon(Icons.block),
                      );
                    }
                    return FloatingActionButton.extended(
                      onPressed: () {
                        if (profile != null && !profile.phoneVerified) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Teléfono no verificado',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                              content: Text(
                                'Para postularte necesitas verificar tu número de teléfono. Agrégalo desde tu perfil.',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context.push('/edit-profile');
                                  },
                                  child: const Text('Ir al perfil'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        context.push('/job/$jobPostId/apply');
                      },
                      label: Text(AppStrings.applyNow, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      icon: const Icon(Icons.send_rounded),
                    );
                  },
                  loading: () => null,
                  error: (_, _) => null,
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
          const Spacer(),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
