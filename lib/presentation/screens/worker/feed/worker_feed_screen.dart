import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

class WorkerFeedScreen extends HookConsumerWidget {
  const WorkerFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(jobFeedProvider);
    final filters = ref.watch(jobFiltersProvider);
    final profile = ref.watch(currentProfileProvider);
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
          // ── Header ──────────────────────────────────────────────
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, ${profile?.fullName.split(' ').first ?? 'Trabajador'} 👋',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Encuentra tu próximo trabajo',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
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
                            child: Icon(
                              Icons.notifications_outlined,
                              color: textPrimary,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: TextField(
                      controller: searchCtrl,
                      onSubmitted: (value) {
                        ref.read(jobFiltersProvider.notifier).state =
                            filters.copyWith(search: value.isEmpty ? null : value);
                        ref.read(jobFeedProvider.notifier).loadJobs();
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar trabajo...',
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        suffixIcon: filters.search != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  ref.read(jobFiltersProvider.notifier).state =
                                      filters.copyWith(search: null);
                                  ref.read(jobFeedProvider.notifier).loadJobs();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        fillColor: isDark ? AppColors.darkSurface : AppColors.surfaceLow,
                      ),
                    ),
                  ),
                  // Category chips
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      children: [
                        _CategoryChip(
                          label: 'Todos',
                          selected: filters.category == null,
                          onTap: () {
                            ref.read(jobFiltersProvider.notifier).state =
                                filters.copyWith(clearCategory: true);
                            ref.read(jobFeedProvider.notifier).loadJobs();
                          },
                          isDark: isDark,
                        ),
                        ...AppConstants.jobCategories.entries.map((e) => _CategoryChip(
                          label: e.value,
                          selected: filters.category == e.key,
                          onTap: () {
                            ref.read(jobFiltersProvider.notifier).state = filters.copyWith(
                              category: filters.category == e.key ? null : e.key,
                            );
                            ref.read(jobFeedProvider.notifier).loadJobs();
                          },
                          isDark: isDark,
                        )),
                      ],
                    ),
                  ),
                  // Filter row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          '${feedState.jobs.length} oportunidades',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showFiltersSheet(context, ref, filters),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Filtros${filters.hasFilters ? " •" : ""}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Job list ────────────────────────────────────────────
          Expanded(
            child: feedState.isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.only(top: 12),
                    itemCount: 4,
                    itemBuilder: (_, _) => const ShimmerJobCard(),
                  )
                : feedState.jobs.isEmpty
                    ? const EmptyState(
                        icon: Icons.work_off_rounded,
                        title: 'No hay ofertas disponibles',
                        subtitle: 'Intenta con otros filtros o vuelve más tarde',
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(jobFeedProvider.notifier).refresh(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: feedState.jobs.length + (feedState.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= feedState.jobs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return _JobCard(
                              job: feedState.jobs[index],
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet(BuildContext context, WidgetRef ref, JobFilters filters) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(filters: filters, ref: ref),
    );
  }
}

// ─── Category chip ────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : AppColors.surfaceLowest),
          borderRadius: BorderRadius.circular(100),
          border: selected
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.surfaceDim,
                  width: 1,
                ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
  final Color cardBg;
  final Color textPrimary;
  final bool isDark;

  const _JobCard({
    required this.job,
    required this.cardBg,
    required this.textPrimary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final categoryEmoji = Formatters.categoryEmoji(job.categoryIcon ?? job.categoryName);
    final isUrgent = job.isUrgent as bool? ?? false;

    return GestureDetector(
      onTap: () => context.push('/job/${job.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: category icon + title + urgent badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(categoryEmoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUrgent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'Urgente',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.categoryLabel(job.categoryName),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Meta row: location + time
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    job.city,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    timeago.format(job.createdAt, locale: 'es'),
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.group_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${job.workersNeeded} puesto${job.workersNeeded > 1 ? "s" : ""}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Bottom row: price + apply button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRECIO BASE',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        Formatters.currency(job.pay),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        Formatters.payType(job.payType),
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => context.push('/job/${job.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Postular',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter bottom sheet ──────────────────────────────────────────────────────
class _FilterSheet extends HookWidget {
  final JobFilters filters;
  final WidgetRef ref;

  const _FilterSheet({required this.filters, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selectedPayType = useState(filters.payType);
    final minPay = useState(filters.minPay);
    final maxPay = useState(filters.maxPay);
    final minPayCtrl = useTextEditingController(text: filters.minPay?.toStringAsFixed(0) ?? '');
    final maxPayCtrl = useTextEditingController(text: filters.maxPay?.toStringAsFixed(0) ?? '');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (_, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ListView(
            controller: scrollCtrl,
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
                'Filtros',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selectedPayType.value,
                decoration: const InputDecoration(labelText: 'Tipo de pago'),
                borderRadius: BorderRadius.circular(16),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...AppConstants.payTypes.entries.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                onChanged: (val) => selectedPayType.value = val,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pago mínimo'),
                      onChanged: (val) => minPay.value = double.tryParse(val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxPayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pago máximo'),
                      onChanged: (val) => maxPay.value = double.tryParse(val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(jobFiltersProvider.notifier).state = JobFilters(
                      category: filters.category,
                      payType: selectedPayType.value,
                      minPay: minPay.value,
                      maxPay: maxPay.value,
                      search: filters.search,
                    );
                    ref.read(jobFeedProvider.notifier).loadJobs();
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
              if (filters.hasFilters) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      ref.read(jobFiltersProvider.notifier).state = const JobFilters();
                      ref.read(jobFeedProvider.notifier).loadJobs();
                      Navigator.pop(context);
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
