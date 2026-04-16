import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
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
    final searchCtrl = useTextEditingController(text: filters.search);
    final scrollController = useScrollController();
    final unreadCount = ref.watch(unreadNotificationCountProvider);

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
      appBar: AppBar(
        title: Text('Inchamba', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary)),
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
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: searchCtrl,
              onSubmitted: (value) {
                ref.read(jobFiltersProvider.notifier).state =
                    filters.copyWith(search: value.isEmpty ? null : value);
                ref.read(jobFeedProvider.notifier).loadJobs();
              },
              decoration: InputDecoration(
                hintText: AppStrings.searchJobs,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: filters.search != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          searchCtrl.clear();
                          ref.read(jobFiltersProvider.notifier).state =
                              filters.copyWith(search: null);
                          ref.read(jobFeedProvider.notifier).loadJobs();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Category chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: filters.category == null,
                    label: const Text('Todas'),
                    onSelected: (_) {
                      ref.read(jobFiltersProvider.notifier).state =
                          filters.copyWith(clearCategory: true);
                      ref.read(jobFeedProvider.notifier).loadJobs();
                    },
                  ),
                ),
                ...AppConstants.jobCategories.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      selected: filters.category == e.key,
                      label: Text(e.value),
                      onSelected: (_) {
                        ref.read(jobFiltersProvider.notifier).state =
                            filters.copyWith(category: filters.category == e.key ? null : e.key);
                        ref.read(jobFeedProvider.notifier).loadJobs();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          // Filter bar
          if (filters.hasFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Filtros activos', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(jobFiltersProvider.notifier).state = const JobFilters();
                      ref.read(jobFeedProvider.notifier).loadJobs();
                    },
                    child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          // Filter button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tune, size: 18),
                  label: const Text('Filtros'),
                  onPressed: () => _showFiltersSheet(context, ref, filters),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Job list
          Expanded(
            child: feedState.isLoading
                ? ListView.builder(
                    itemCount: 5,
                    itemBuilder: (_, __) => const ShimmerJobCard(),
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
                          itemCount: feedState.jobs.length + (feedState.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= feedState.jobs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                            }
                            final job = feedState.jobs[index];
                            return _JobCard(job: job);
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

class _FilterSheet extends HookWidget {
  final JobFilters filters;
  final WidgetRef ref;

  const _FilterSheet({required this.filters, required this.ref});

  @override
  Widget build(BuildContext context) {
    final selectedCity = useState(filters.city);
    final selectedPayType = useState(filters.payType);
    final minPay = useState(filters.minPay);
    final maxPay = useState(filters.maxPay);
    final minPayCtrl = useTextEditingController(text: filters.minPay?.toStringAsFixed(0) ?? '');
    final maxPayCtrl = useTextEditingController(text: filters.maxPay?.toStringAsFixed(0) ?? '');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Filtros', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedCity.value,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas las ciudades')),
                  ...AppConstants.colombianCities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (val) => selectedCity.value = val,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPayType.value,
                decoration: const InputDecoration(labelText: 'Tipo de pago'),
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
                      city: selectedCity.value,
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
            ],
          ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  final dynamic job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/job/${job.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (job.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.urgent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppStrings.urgent,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.urgent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    job.employerName ?? 'Empleador',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    job.city,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      Formatters.categoryLabel(job.categoryName),
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${Formatters.currency(job.pay)} ${Formatters.payType(job.payType)}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.group_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${job.workersNeeded} trabajador${job.workersNeeded > 1 ? "es" : ""}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    timeago.format(job.createdAt, locale: 'es'),
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
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
