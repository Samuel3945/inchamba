import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';

class WorkerDashboardScreen extends HookConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(jobFeedProvider);
    final filters = ref.watch(jobFiltersProvider);
    final profile = ref.watch(currentProfileProvider);
    final acceptedAppsAsync = ref.watch(workerApplicationsProvider('accepted'));
    final searchCtrl = useTextEditingController(text: filters.search);
    final scrollController = useScrollController();
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;
    final bgColor = isDark ? AppColors.darkBg : AppColors.surfaceLow;

    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
          ref.read(jobFeedProvider.notifier).loadMore();
        }
      }
      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, ${profile?.fullName.split(' ').first ?? 'Trabajador'} 👋',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                profile?.city.isNotEmpty == true ? profile!.city : 'Encuentra tu próximo trabajo',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/notifications'),
                          icon: Badge(
                            isLabelVisible: unreadCount > 0,
                            label: Text('$unreadCount', style: const TextStyle(fontSize: 9)),
                            backgroundColor: AppColors.error,
                            child: Icon(Icons.notifications_outlined, color: textPrimary, size: 26),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: searchCtrl,
                      onSubmitted: (val) {
                        ref.read(jobFiltersProvider.notifier).state =
                            filters.copyWith(search: val.isEmpty ? null : val);
                        ref.read(jobFeedProvider.notifier).loadJobs();
                      },
                      onChanged: (val) {
                        if (val.isEmpty) {
                          ref.read(jobFiltersProvider.notifier).state = filters.copyWith(search: null);
                          ref.read(jobFeedProvider.notifier).loadJobs();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar trabajos...',
                        hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: filters.search != null
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  ref.read(jobFiltersProvider.notifier).state = filters.copyWith(search: null);
                                  ref.read(jobFeedProvider.notifier).loadJobs();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : AppColors.surfaceLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Scrollable content ────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(jobFeedProvider);
                ref.invalidate(workerApplicationsProvider('accepted'));
              },
              color: AppColors.primary,
              child: CustomScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Mis trabajos section ─────────────────────
                  SliverToBoxAdapter(
                    child: acceptedAppsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (apps) {
                        if (apps.isEmpty) return const SizedBox.shrink();
                        return _MyJobsSection(apps: apps, isDark: isDark, textPrimary: textPrimary, cardBg: cardBg);
                      },
                    ),
                  ),

                  // ── Category filters ─────────────────────────
                  SliverToBoxAdapter(
                    child: _CategoryFilter(
                      selected: filters.category,
                      onSelected: (cat) {
                        ref.read(jobFiltersProvider.notifier).state = filters.copyWith(
                          category: cat,
                          clearCategory: cat == null,
                        );
                        ref.read(jobFeedProvider.notifier).loadJobs();
                      },
                    ),
                  ),

                  // ── Feed section title ───────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ofertas disponibles',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          if (feedState.jobs.isNotEmpty)
                            Text(
                              '${feedState.jobs.length}+ trabajos',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ── Job cards ────────────────────────────────
                  if (feedState.isLoading && feedState.jobs.isEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, _) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ShimmerJobCard(),
                        ),
                        childCount: 4,
                      ),
                    )
                  else if (feedState.jobs.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.work_off_outlined,
                        title: 'No hay ofertas en este momento',
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == feedState.jobs.length) {
                            return feedState.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                                  )
                                : const SizedBox(height: 80);
                          }
                          final job = feedState.jobs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: _JobCard(job: job, isDark: isDark),
                          );
                        },
                        childCount: feedState.jobs.length + 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── "Mis trabajos" schedule section ─────────────────────────────────────────
class _MyJobsSection extends StatelessWidget {
  final List apps;
  final bool isDark;
  final Color textPrimary;
  final Color cardBg;

  const _MyJobsSection({
    required this.apps,
    required this.isDark,
    required this.textPrimary,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    // Group accepted apps by date
    final Map<String, List<dynamic>> byDate = {};
    for (final app in apps) {
      final dateKey = app.jobStartDate != null
          ? DateFormat('yyyy-MM-dd').format(app.jobStartDate!)
          : 'sin_fecha';
      byDate.putIfAbsent(dateKey, () => []).add(app);
    }

    final sortedKeys = byDate.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Mis trabajos aceptados',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${apps.length} activos',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedKeys.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final key = sortedKeys[i];
              final dayApps = byDate[key]!;
              return _ScheduleDayCard(
                dateKey: key,
                dayApps: dayApps,
                isDark: isDark,
                textPrimary: textPrimary,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Divider(color: isDark ? AppColors.darkBorder : AppColors.surfaceDim),
        ),
      ],
    );
  }
}

class _ScheduleDayCard extends StatelessWidget {
  final String dateKey;
  final List dayApps;
  final bool isDark;
  final Color textPrimary;

  const _ScheduleDayCard({
    required this.dateKey,
    required this.dayApps,
    required this.isDark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;
    DateTime? date;
    String dateLabel;
    if (dateKey != 'sin_fecha') {
      date = DateTime.tryParse(dateKey);
      if (date != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final d = DateTime(date.year, date.month, date.day);
        if (d == today) {
          dateLabel = 'Hoy';
        } else if (d == today.add(const Duration(days: 1))) {
          dateLabel = 'Mañana';
        } else {
          dateLabel = DateFormat('EEE d MMM', 'es').format(date);
        }
      } else {
        dateLabel = 'Por confirmar';
      }
    } else {
      dateLabel = 'Sin fecha';
    }

    final isToday = date != null &&
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return GestureDetector(
      onTap: () => context.push('/worker/applications'),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: isToday
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: isDark ? AppColors.darkBorder : AppColors.surfaceDim),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dateLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isToday ? AppColors.primary : AppColors.success,
                    ),
                  ),
                ),
                if (dayApps.length > 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dayApps.length} trabajos',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ...dayApps.take(2).map((app) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.jobTitle ?? 'Trabajo',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (app.jobSchedule != null)
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            app.jobSchedule!,
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            )),
            if (dayApps.length > 2)
              Text(
                '+${dayApps.length - 2} más',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Category filter chips ────────────────────────────────────────────────────
class _CategoryFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'Todos',
            selected: selected == null,
            onTap: () => onSelected(null),
            isDark: isDark,
          ),
          ...AppConstants.jobCategories.entries.map((e) => _FilterChip(
            label: Formatters.categoryLabel(e.key),
            selected: selected == e.key,
            onTap: () => onSelected(selected == e.key ? null : e.key),
            isDark: isDark,
          )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({required this.label, required this.selected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : (isDark ? AppColors.darkCard : AppColors.surfaceLowest),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.surfaceDim),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Job card ─────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final dynamic job;
  final bool isDark;

  const _JobCard({required this.job, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;

    return GestureDetector(
      onTap: () => context.push('/job/${job.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Formatters.categoryIconData(job.categoryIcon ?? job.categoryName),
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (job.employerName != null)
                        Text(
                          job.employerName!,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                // Difficulty stars badge
                _DifficultyBadge(stars: job.difficultyStars),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text(job.city, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                const Spacer(),
                Text(
                  '${Formatters.currency(job.pay)} ${Formatters.payType(job.payType)}',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ],
            ),
            if (job.startDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('d MMM yyyy', 'es').format(job.startDate!),
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                  if (job.isUrgent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Urgente',
                          style: GoogleFonts.poppins(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeago.format(job.createdAt, locale: 'es'),
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${job.spotsLeft} cupos',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
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

// ─── Difficulty stars badge ───────────────────────────────────────────────────
class _DifficultyBadge extends StatelessWidget {
  final int stars;
  const _DifficultyBadge({required this.stars});

  @override
  Widget build(BuildContext context) {
    final clampedStars = stars.clamp(1, 5);
    final color = clampedStars <= 2
        ? AppColors.success
        : clampedStars == 3
            ? AppColors.warning
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) => Icon(
            i < clampedStars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 12,
            color: color,
          )),
        ),
        Text(
          _label(clampedStars),
          style: GoogleFonts.poppins(fontSize: 9, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _label(int s) {
    switch (s) {
      case 1: return 'Fácil';
      case 2: return 'Moderado';
      case 3: return 'Normal';
      case 4: return 'Difícil';
      case 5: return 'Experto';
      default: return '';
    }
  }
}
