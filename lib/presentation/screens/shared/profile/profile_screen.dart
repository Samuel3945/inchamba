import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/wallet_provider.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;
    final bgColor = isDark ? AppColors.darkBg : AppColors.surfaceLow;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App bar ──────────────────────────────────────────
            SliverAppBar(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              title: Text(
                'Perfil Profesional',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: Icon(Icons.settings_outlined, color: textPrimary),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  // ── Header card ─────────────────────────────────
                  Container(
                    color: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                              child: InchambaAvatar(
                                imageUrl: profile.avatarUrl,
                                fallbackInitials: profile.fullName.isNotEmpty
                                    ? profile.fullName[0].toUpperCase()
                                    : '?',
                                radius: 52,
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => context.push('/edit-profile'),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                            // Rating badge
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.star,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 2),
                                    Text(
                                      Formatters.rating(profile.rating),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.fullName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        if (profile.companyName != null && profile.companyName!.isNotEmpty)
                          Text(
                            profile.companyName!,
                            style: GoogleFonts.poppins(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                profile.isEmployer
                                    ? Icons.business_center_rounded
                                    : Icons.construction_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                profile.isEmployer
                                    ? 'EMPLEADOR'
                                    : '${profile.jobsCompleted} trabajos completados',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              profile.city,
                              style: GoogleFonts.poppins(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '(${profile.ratingCount} reseñas)',
                              style: GoogleFonts.poppins(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Onboarding checklist ────────────────────────
                  if (!(profile.avatarUrl?.isNotEmpty ?? false) ||
                      !profile.hasCedula ||
                      profile.cedulaBackUrl == null ||
                      !profile.phoneVerified) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _OnboardingChecklist(profile: profile),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Worker wallet card ──────────────────────────
                  if (!profile.isEmployer) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _WorkerWalletCard(isDark: isDark),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Earnings / stats cards ──────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.verified_rounded,
                            iconColor: AppColors.primary,
                            title: '${profile.jobsCompleted}',
                            subtitle: 'Trabajos completados',
                            cardBg: cardBg,
                            textPrimary: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.star_rounded,
                            iconColor: AppColors.star,
                            title: Formatters.rating(profile.rating),
                            subtitle: 'Calificación promedio',
                            cardBg: cardBg,
                            textPrimary: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Datos de identidad (cédula) ─────────────────
                  if (profile.hasCedula) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _CedulaIdentityCard(profile: profile, cardBg: cardBg, textPrimary: textPrimary, isDark: isDark),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Bio ─────────────────────────────────────────
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sobre mí',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile.bio!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Categories ──────────────────────────────────
                  if (profile.categories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESPECIALIDADES',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: profile.categories.map((c) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    AppConstants.jobCategories[c] ?? c,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Account menu ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'GESTIÓN DE CUENTA',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              _MenuItem(
                                icon: profile.isEmployer
                                    ? Icons.construction_rounded
                                    : Icons.business_rounded,
                                label: profile.isEmployer
                                    ? 'Cambiar a trabajador'
                                    : 'Cambiar a empleador',
                                subtitle: profile.isEmployer
                                    ? 'Busca y aplica a trabajos'
                                    : 'Publica ofertas y contrata',
                                iconColor: AppColors.accent,
                                textPrimary: textPrimary,
                                onTap: () => _confirmRoleSwitch(context, ref, profile),
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Ratings ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'CALIFICACIONES',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        ratingsAsync.when(
                          loading: () => const ShimmerLoading(height: 80, borderRadius: 16),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (ratings) {
                            if (ratings.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    'Aún no tienes calificaciones',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: ratings.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final r = entry.value;
                                  return Column(
                                    children: [
                                      ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        leading: InchambaAvatar(
                                          imageUrl: r.raterAvatar,
                                          fallbackInitials: r.raterName
                                              ?.substring(0, 1)
                                              .toUpperCase(),
                                          radius: 20,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r.raterName ?? 'Usuario',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                            StarRating(rating: r.stars.toDouble(), size: 14),
                                          ],
                                        ),
                                        subtitle: r.comment != null
                                            ? Text(
                                                r.comment!,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              )
                                            : null,
                                      ),
                                      if (i < ratings.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 70,
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : AppColors.surfaceLow,
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRoleSwitch(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final isCurrentlyEmployer = profile.isEmployer;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isCurrentlyEmployer ? 'Cambiar a trabajador' : 'Cambiar a empleador',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          isCurrentlyEmployer
              ? 'Podrás buscar y postularte a trabajos. Puedes volver a empleador cuando quieras.'
              : 'Podrás publicar ofertas y contratar. Puedes volver a trabajador cuando quieras.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final newRole =
          isCurrentlyEmployer ? Profile.roleWorker : Profile.roleEmployer;
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
  }
}

// ─── Worker wallet card ───────────────────────────────────────────────────────
class _WorkerWalletCard extends ConsumerWidget {
  final bool isDark;
  const _WorkerWalletCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);

    Future<void> showWithdrawDialog(double currentBalance) async {
      final amounts = [50000.0, 100000.0, 200000.0, 500000.0]
          .where((a) => a <= currentBalance)
          .toList();
      double? selected = amounts.isNotEmpty ? amounts.first : null;
      final ctrl = TextEditingController();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            double? computeAmount() {
              if (selected != null) return selected;
              final v = double.tryParse(
                ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
              );
              return (v != null && v > 0 && v <= currentBalance) ? v : null;
            }
            final amount = computeAmount();

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¿Cuánto deseas retirar?',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saldo disponible: ${Formatters.currency(currentBalance)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (amounts.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: amounts.map((p) {
                        final isSelected = selected == p;
                        return GestureDetector(
                          onTap: () => setState(() {
                            selected = isSelected ? null : p;
                            ctrl.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              Formatters.currency(p),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Otro monto',
                      prefixText: '\$ ',
                    ),
                    onChanged: (_) => setState(() => selected = null),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: amount != null
                          ? () async {
                              Navigator.pop(ctx);
                              final ds = ref.read(supabaseDatasourceProvider);
                              final currentProfile = ref.read(currentProfileProvider);
                              try {
                                final result = await ds.requestWithdrawal(amount);
                                if (result['success'] == true && currentProfile != null) {
                                  ds.notifyWithdrawalToOwner(
                                    workerName: currentProfile.fullName,
                                    workerPhone: currentProfile.phone,
                                    workerCedula: currentProfile.cedula,
                                    amount: amount,
                                  );
                                }
                                ref.invalidate(walletBalanceProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['success'] == true
                                            ? 'Solicitud de retiro enviada.'
                                            : 'Saldo insuficiente',
                                      ),
                                      backgroundColor: result['success'] == true
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        amount != null
                            ? 'Retirar ${Formatters.currency(amount)}'
                            : 'Selecciona un monto',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'BILLETERA',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          balanceAsync.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            error: (_, _) => Text(
              '—',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
            data: (balance) => Text(
              Formatters.currency(balance),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'COP • Saldo disponible',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final balance = balanceAsync.valueOrNull ?? 0;
                    if (balance <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No tienes saldo para retirar')),
                      );
                      return;
                    }
                    showWithdrawDialog(balance);
                  },
                  icon: const Icon(Icons.savings_outlined, size: 16),
                  label: Text(
                    'Retirar fondos',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/worker/wallet'),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(
                    'Historial',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color cardBg;
  final Color textPrimary;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.cardBg,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu item ────────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final Color textPrimary;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.textPrimary,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            color: isDark ? AppColors.darkBorder : AppColors.surfaceLow,
          ),
      ],
    );
  }
}

// ─── Phone not verified banner ────────────────────────────────────────────────
class _OnboardingChecklist extends StatelessWidget {
  final Profile profile;
  const _OnboardingChecklist({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAvatar = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;
    final hasCedula = profile.hasCedula && profile.cedulaBackUrl != null;
    final hasPhone = profile.phoneVerified;
    final allDone = hasAvatar && hasCedula && hasPhone;

    if (allDone) return const SizedBox.shrink();

    final items = [
      (
        done: hasAvatar,
        icon: Icons.face_rounded,
        label: 'Foto de perfil',
        hint: 'Selfie en vivo con cámara frontal',
      ),
      (
        done: hasCedula,
        icon: Icons.badge_rounded,
        label: 'Cédula de Ciudadanía',
        hint: 'Frente y reverso de tu CC',
      ),
      (
        done: hasPhone,
        icon: Icons.phone_rounded,
        label: 'Teléfono verificado',
        hint: 'Número con código OTP',
      ),
    ];

    final doneCount = [hasAvatar, hasCedula, hasPhone].where((v) => v).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allDone
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: allDone
                    ? [AppColors.success.withValues(alpha: 0.12), AppColors.success.withValues(alpha: 0.06)]
                    : [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDone ? '¡Perfil completo!' : 'Completa tu perfil para empezar',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: allDone ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      Text(
                        allDone
                            ? 'Ya puedes aplicar a trabajos y publicar ofertas'
                            : 'Necesitas estos datos para aplicar y publicar ofertas',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: doneCount / items.length,
                        strokeWidth: 4,
                        backgroundColor: AppColors.surfaceDim,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          allDone ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '$doneCount/${items.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: allDone ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Checklist items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.done
                            ? AppColors.success
                            : AppColors.surfaceDim,
                        border: item.done
                            ? null
                            : Border.all(color: AppColors.textMuted.withValues(alpha: 0.4)),
                      ),
                      child: Icon(
                        item.done ? Icons.check_rounded : item.icon,
                        size: 14,
                        color: item.done ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: item.done
                                  ? AppColors.success
                                  : isDark ? AppColors.textWhite : AppColors.textDark,
                              decoration: item.done ? TextDecoration.none : null,
                            ),
                          ),
                          if (!item.done)
                            Text(item.hint,
                                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (item.done)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                  ],
                ),
              )).toList(),
            ),
          ),

          if (!allDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/edit-profile'),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    'Completar ahora',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Cédula identity card ─────────────────────────────────────────────────────
class _CedulaIdentityCard extends StatelessWidget {
  final Profile profile;
  final Color cardBg;
  final Color textPrimary;
  final bool isDark;

  const _CedulaIdentityCard({
    required this.profile,
    required this.cardBg,
    required this.textPrimary,
    required this.isDark,
  });

  Future<void> _requestCorrection(BuildContext context) async {
    final name = Uri.encodeComponent(profile.fullName);
    final cedula = Uri.encodeComponent(profile.cedula ?? 'No registrada');
    final body = Uri.encodeComponent(
      'Hola equipo Inchamba,\n\n'
      'Solicito la corrección de mis datos personales.\n\n'
      'Nombre actual: ${profile.fullName}\n'
      'Cédula actual: ${profile.cedula ?? "No registrada"}\n\n'
      'Datos a corregir:\n'
      '[Describe aquí qué dato está incorrecto y cuál es el valor correcto]\n\n'
      'Adjunto documento de soporte si es necesario.\n\n'
      'Gracias.',
    );
    final uri = Uri.parse(
      'mailto:soporte@inchamba.co'
      '?subject=Corrección de datos - $name ($cedula)'
      '&body=$body',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escríbenos a soporte@inchamba.co para solicitar la corrección.'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sexLabel = profile.cedulaSex == 'M'
        ? 'Masculino'
        : profile.cedulaSex == 'F'
            ? 'Femenino'
            : profile.cedulaSex ?? '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'IDENTIDAD',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Verificada con cédula',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _IdentityRow(
                  icon: Icons.person_outlined,
                  label: 'Nombre completo',
                  value: profile.fullName.isNotEmpty ? profile.fullName : '—',
                  textPrimary: textPrimary,
                ),
                _IdentityRow(
                  icon: Icons.flag_outlined,
                  label: 'Nacionalidad',
                  value: 'Colombiana',
                  textPrimary: textPrimary,
                ),
                if (profile.cedulaSex != null)
                  _IdentityRow(
                    icon: Icons.wc_outlined,
                    label: 'Sexo',
                    value: sexLabel,
                    textPrimary: textPrimary,
                  ),
                if (profile.cedulaDateBirth != null) ...[
                  _IdentityRow(
                    icon: Icons.cake_outlined,
                    label: 'Fecha de nacimiento',
                    value: _formatDate(profile.cedulaDateBirth),
                    textPrimary: textPrimary,
                  ),
                  if (profile.age != null)
                    _IdentityRow(
                      icon: Icons.numbers_outlined,
                      label: 'Edad',
                      value: '${profile.age} años',
                      textPrimary: textPrimary,
                    ),
                ],
                if (profile.cedulaPlaceBirth != null)
                  _IdentityRow(
                    icon: Icons.location_city_outlined,
                    label: 'Lugar de nacimiento',
                    value: profile.cedulaPlaceBirth!,
                    textPrimary: textPrimary,
                  ),
                if (profile.cedulaBloodType != null)
                  _IdentityRow(
                    icon: Icons.bloodtype_outlined,
                    label: 'Tipo de sangre',
                    value: profile.cedulaBloodType!,
                    textPrimary: textPrimary,
                  ),
                if (profile.cedulaHeightCm != null)
                  _IdentityRow(
                    icon: Icons.height_outlined,
                    label: 'Estatura',
                    value: '${profile.cedulaHeightCm} cm',
                    textPrimary: textPrimary,
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _requestCorrection(context),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: Text(
                      'Solicitar corrección de datos',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Un integrante del equipo se encargará de la corrección lo más rápido posible.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;

  const _IdentityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
