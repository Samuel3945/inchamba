import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';
import '../../../../data/models/rating_model.dart';

final myRatingsProvider = FutureProvider<List<RatingModel>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  final data = await ds.getRatingsForUser(userId);
  return data.map((r) => RatingModel.fromJson(r)).toList();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final ratingsAsync = ref.watch(myRatingsProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.profile, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              Stack(
                children: [
                  InchambaAvatar(
                    imageUrl: profile.avatarUrl,
                    fallbackInitials: profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                    radius: 50,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => context.push('/edit-profile'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                profile.fullName,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (profile.companyName != null && profile.companyName!.isNotEmpty)
                Text(profile.companyName!, style: GoogleFonts.poppins(color: AppColors.textMuted)),
              Text(profile.city, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 14)),
              const SizedBox(height: 12),
              // Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StarRating(rating: profile.rating, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${Formatters.rating(profile.rating)} (${profile.ratingCount})',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatPill(
                    icon: Icons.check_circle_outline,
                    label: '${profile.jobsCompleted} ${AppStrings.jobsCompleted}',
                  ),
                  const SizedBox(width: 12),
                  _StatPill(
                    icon: Icons.calendar_today_outlined,
                    label: '${AppStrings.memberSince} ${Formatters.date(profile.createdAt)}',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Bio
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(profile.bio!, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight, height: 1.5)),
                ),
                const SizedBox(height: 16),
              ],
              // Categories
              if (profile.categories.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Categorías', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.categories
                      .map((c) => Chip(label: Text(AppConstants.jobCategories[c] ?? c)))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              // Edit profile button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/edit-profile'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(AppStrings.editProfile),
                ),
              ),
              const SizedBox(height: 12),
              // Role switcher
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCard,
                    foregroundColor: AppColors.textWhite,
                  ),
                  onPressed: () async {
                    final newRole = profile.isEmployer
                        ? Profile.roleWorker
                        : Profile.roleEmployer;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          profile.isEmployer
                              ? 'Cambiar a trabajador'
                              : 'Cambiar a empleador',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        content: Text(
                          profile.isEmployer
                              ? 'Podrás buscar y postularte a trabajos. Puedes volver a empleador cuando quieras.'
                              : 'Podrás publicar ofertas y contratar. Puedes volver a trabajador cuando quieras.',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cambiar')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      await ref.read(authProvider.notifier).updateProfile({'role': newRole});
                      if (context.mounted) {
                        context.go(newRole == Profile.roleEmployer ? '/employer' : '/worker');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo cambiar el rol: $e')),
                        );
                      }
                    }
                  },
                  icon: Icon(profile.isEmployer ? Icons.construction_rounded : Icons.business_rounded),
                  label: Text(
                    profile.isEmployer
                        ? 'Cambiar a modo trabajador'
                        : 'Cambiar a modo empleador',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Ratings history
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Calificaciones recibidas', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              ratingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Text('Error: $e'),
                data: (ratings) {
                  if (ratings.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: Text('No hay calificaciones aún', style: GoogleFonts.poppins(color: AppColors.textMuted)),
                    );
                  }
                  return Column(
                    children: ratings.map((r) => ListTile(
                      leading: InchambaAvatar(
                        imageUrl: r.raterAvatar,
                        fallbackInitials: r.raterName?.substring(0, 1).toUpperCase(),
                        radius: 18,
                      ),
                      title: Row(
                        children: [
                          Text(r.raterName ?? 'Usuario', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          StarRating(rating: r.stars.toDouble(), size: 14),
                        ],
                      ),
                      subtitle: r.comment != null
                          ? Text(r.comment!, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted))
                          : null,
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary)),
        ],
      ),
    );
  }
}
