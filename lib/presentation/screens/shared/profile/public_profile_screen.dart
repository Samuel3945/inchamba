import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/models/rating_model.dart';

final publicProfileProvider = FutureProvider.family<ProfileModel, String>((ref, userId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final data = await ds.getProfile(userId);
  return ProfileModel.fromJson(data);
});

final publicRatingsProvider = FutureProvider.family<List<RatingModel>, String>((ref, userId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final data = await ds.getRatingsForUser(userId);
  return data.map((r) => RatingModel.fromJson(r)).toList();
});

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final ratingsAsync = ref.watch(publicRatingsProvider(userId));
    final ds = ref.watch(supabaseDatasourceProvider);
    final currentUserId = ds.currentUserId;

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
      data: (profile) {
        return Scaffold(
          appBar: AppBar(title: Text(profile.fullName)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                InchambaAvatar(
                  imageUrl: profile.avatarUrl,
                  fallbackInitials: profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                  radius: 50,
                ),
                const SizedBox(height: 16),
                Text(profile.fullName, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                if (profile.companyName != null && profile.companyName!.isNotEmpty)
                  Text(profile.companyName!, style: GoogleFonts.poppins(color: AppColors.textMuted)),
                Text(profile.city, style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StarRating(rating: profile.rating, size: 20),
                    const SizedBox(width: 8),
                    Text('${Formatters.rating(profile.rating)} (${profile.ratingCount})',
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${profile.jobsCompleted} trabajos completados',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(profile.bio!, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight)),
                  ),
                ],
                if (profile.categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.categories
                        .map((c) => Chip(label: Text(AppConstants.jobCategories[c] ?? c)))
                        .toList(),
                  ),
                ],
                if (currentUserId != null && currentUserId != userId) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final me = ref.read(currentProfileProvider);
                        if (me == null) return;
                        final meIsEmployer = me.role == Profile.roleEmployer;
                        final employerId = meIsEmployer ? currentUserId : userId;
                        final workerId = meIsEmployer ? userId : currentUserId;
                        final conv = await ds.getOrCreateConversation(
                          employerId: employerId,
                          workerId: workerId,
                        );
                        if (context.mounted) {
                          context.push('/chat/${conv['id']}?name=${Uri.encodeComponent(profile.fullName)}');
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Enviar mensaje'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Calificaciones', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                ratingsAsync.when(
                  loading: () => const CircularProgressIndicator(color: AppColors.primary),
                  error: (e, _) => Text('Error: $e'),
                  data: (ratings) {
                    if (ratings.isEmpty) {
                      return Text('No hay calificaciones aún', style: GoogleFonts.poppins(color: AppColors.textMuted));
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
                            Text(r.raterName ?? 'Usuario', style: GoogleFonts.poppins(fontSize: 14)),
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
        );
      },
    );
  }
}
