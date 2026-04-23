import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';
import '../../../../data/models/work_completion_model.dart';

final completionDetailProvider = FutureProvider.family<WorkCompletionModel?, String>((ref, completionId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final data = await ds.client
      .from('work_completions')
      .select('*, worker:profiles!worker_id(full_name, avatar_url), job_post:job_posts(title)')
      .eq('id', completionId)
      .single();
  return WorkCompletionModel.fromJson(data);
});

class ConfirmWorkScreen extends HookConsumerWidget {
  final String jobPostId;
  final String completionId;

  const ConfirmWorkScreen({super.key, required this.jobPostId, required this.completionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync = ref.watch(completionDetailProvider(completionId));
    final isConfirming = useState(false);

    return completionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
      data: (completion) {
        if (completion == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('No encontrado')));
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Confirmar trabajo')),
          body: LoadingOverlay(
            isLoading: isConfirming.value,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Worker info
                  Row(
                    children: [
                      InchambaAvatar(
                        imageUrl: completion.workerAvatar,
                        fallbackInitials: completion.workerName?.substring(0, 1).toUpperCase(),
                        radius: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              completion.workerName ?? 'Trabajador',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              completion.jobTitle ?? 'Oferta',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Descripción del trabajo', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      completion.completionNote ?? '',
                      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight, height: 1.5),
                    ),
                  ),
                  if (completion.evidenceUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Fotos de evidencia', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: completion.evidenceUrls.map((url) {
                        return GestureDetector(
                          onTap: () => _showFullImage(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const ShimmerLoading(width: 120, height: 120),
                              errorWidget: (_, _, _) => Container(
                                width: 120,
                                height: 120,
                                color: AppColors.darkSurface,
                                child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirmar trabajo'),
                            content: const Text(
                              'Al confirmar, el pago se liberará al trabajador. Esta acción no se puede deshacer.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
                            ],
                          ),
                        );
                        if (confirmed != true) return;

                        isConfirming.value = true;
                        try {
                          final ds = ref.read(supabaseDatasourceProvider);
                          await ds.confirmWorkCompletion(completionId);

                          // Update application status
                          await ds.updateApplicationStatus(completion.applicationId, 'completed');

                          // Update profile completed_jobs
                          final workerProfile = await ds.getProfile(completion.workerId);
                          await ds.updateProfile(completion.workerId, {
                            'completed_jobs': (workerProfile['completed_jobs'] as int? ?? 0) + 1,
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Trabajo confirmado. Pago liberado.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            // Offer to rate
                            final shouldRate = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Calificar trabajador'),
                                content: const Text('¿Deseas calificar al trabajador ahora?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Después')),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Calificar')),
                                ],
                              ),
                            );
                            if (context.mounted) {
                              if (shouldRate == true) {
                                context.pushReplacement('/rate/$jobPostId/${completion.applicationId}/${completion.workerId}');
                              } else {
                                context.pop();
                              }
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          isConfirming.value = false;
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text('Confirmar y liberar pago', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/dispute/$jobPostId'),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Reportar disputa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url),
          ),
        ),
      ),
    ));
  }
}
