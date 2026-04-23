import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/job_provider.dart';
import '../../../data/models/job_post_model.dart';

class GuestFeedScreen extends HookConsumerWidget {
  const GuestFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(jobFeedProvider);
    final scrollController = useScrollController();

    useEffect(() {
      scrollController.addListener(() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
          ref.read(jobFeedProvider.notifier).loadMore();
        }
      });
      return null;
    }, []);

    return Scaffold(
      backgroundColor: AppColors.surfaceLow,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surfaceLowest,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28, errorBuilder: (_, _, _) =>
                const Icon(Icons.work_rounded, color: AppColors.primary, size: 28)),
            const SizedBox(width: 8),
            Text('Inchamba', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 18,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text('Ingresar', style: GoogleFonts.poppins(
              color: AppColors.primary, fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          // CTA Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: AppColors.primary,
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Regístrate con tu Cédula para postularte',
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('Registrarse', style: GoogleFonts.poppins(
                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
              ],
            ),
          ),
          // Feed
          Expanded(
            child: feedState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : feedState.jobs.isEmpty
                    ? Center(
                        child: Text(
                          'No hay ofertas disponibles',
                          style: GoogleFonts.poppins(color: AppColors.textMuted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(jobFeedProvider.notifier).refresh(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: feedState.jobs.length + (feedState.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= feedState.jobs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                                ),
                              );
                            }
                            return _GuestJobCard(
                              job: feedState.jobs[index],
                              onTap: () => _showRegisterPrompt(context),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showRegisterPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Regístrate para postularte',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Necesitas una cuenta con tu Cédula de Ciudadanía para ver los detalles y aplicar a esta oferta.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '¿No tienes cédula? Podemos ayudarte a obtenerla.',
              style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/register');
                },
                icon: const Icon(Icons.badge_rounded),
                label: const Text('Registrarse con Cédula'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/login');
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('Ya tengo cuenta', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GuestJobCard extends StatelessWidget {
  final JobPostModel job;
  final VoidCallback onTap;

  const _GuestJobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    Formatters.currency(job.pay),
                    style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(job.city, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(width: 12),
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  timeago.format(job.createdAt, locale: 'es'),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            if (job.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                job.description,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Regístrate para ver', style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
                      )),
                    ],
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
