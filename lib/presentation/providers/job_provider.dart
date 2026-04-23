import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/job_post_model.dart';
import '../../core/constants/app_constants.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

class JobFilters {
  final String? category;
  final String? city;
  final String? payType;
  final double? minPay;
  final double? maxPay;
  final String? search;

  const JobFilters({
    this.category,
    this.city,
    this.payType,
    this.minPay,
    this.maxPay,
    this.search,
  });

  JobFilters copyWith({
    String? category,
    String? city,
    String? payType,
    double? minPay,
    double? maxPay,
    String? search,
    bool clearCategory = false,
    bool clearCity = false,
    bool clearPayType = false,
    bool clearPay = false,
  }) {
    return JobFilters(
      category: clearCategory ? null : (category ?? this.category),
      city: clearCity ? null : (city ?? this.city),
      payType: clearPayType ? null : (payType ?? this.payType),
      minPay: clearPay ? null : (minPay ?? this.minPay),
      maxPay: clearPay ? null : (maxPay ?? this.maxPay),
      search: search ?? this.search,
    );
  }

  // city is excluded — always locked to the user's current GPS city
  bool get hasFilters => category != null || payType != null || minPay != null || maxPay != null;
}

final jobFiltersProvider = StateProvider<JobFilters>((ref) => const JobFilters());

class JobFeedState {
  final List<JobPostModel> jobs;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const JobFeedState({
    this.jobs = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  JobFeedState copyWith({
    List<JobPostModel>? jobs,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return JobFeedState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class JobFeedNotifier extends StateNotifier<JobFeedState> {
  final SupabaseDatasource _datasource;
  final Ref _ref;

  JobFeedNotifier(this._datasource, this._ref) : super(const JobFeedState()) {
    loadJobs();
  }

  Future<void> loadJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final filters = _ref.read(jobFiltersProvider);
      final profile = _ref.read(currentProfileProvider);
      final userCity = profile?.city.isNotEmpty == true ? profile!.city : null;
      String? categoryId;
      if (filters.category != null && filters.category!.isNotEmpty) {
        categoryId = await _datasource.resolveCategoryId(filters.category!);
      }
      final data = await _datasource.getJobPosts(
        categoryId: categoryId,
        city: userCity,
        payType: filters.payType,
        minPay: filters.minPay,
        maxPay: filters.maxPay,
        search: filters.search,
      );
      final jobs = data.map((j) => JobPostModel.fromJson(j)).toList();
      state = JobFeedState(
        jobs: jobs,
        hasMore: jobs.length >= AppConstants.pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error cargando ofertas');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final filters = _ref.read(jobFiltersProvider);
      final profile = _ref.read(currentProfileProvider);
      final userCity = profile?.city.isNotEmpty == true ? profile!.city : null;
      String? categoryId;
      if (filters.category != null && filters.category!.isNotEmpty) {
        categoryId = await _datasource.resolveCategoryId(filters.category!);
      }
      final data = await _datasource.getJobPosts(
        offset: state.jobs.length,
        categoryId: categoryId,
        city: userCity,
        payType: filters.payType,
        minPay: filters.minPay,
        maxPay: filters.maxPay,
        search: filters.search,
      );
      final newJobs = data.map((j) => JobPostModel.fromJson(j)).toList();
      state = state.copyWith(
        jobs: [...state.jobs, ...newJobs],
        isLoadingMore: false,
        hasMore: newJobs.length >= AppConstants.pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() => loadJobs();
}

final jobFeedProvider = StateNotifierProvider<JobFeedNotifier, JobFeedState>((ref) {
  return JobFeedNotifier(ref.watch(supabaseDatasourceProvider), ref);
});

final jobDetailProvider = FutureProvider.family<JobPostModel, String>((ref, jobId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final data = await ds.getJobPost(jobId);
  return JobPostModel.fromJson(data);
});

final hasAppliedProvider = FutureProvider.family<bool, String>((ref, jobPostId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return false;
  return await ds.hasApplied(jobPostId, userId);
});

final employerJobsProvider = FutureProvider.family<List<JobPostModel>, String?>((ref, status) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  final data = await ds.getEmployerJobPosts(userId, status: status);
  return data.map((j) => JobPostModel.fromJson(j)).toList();
});

final employerStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return {};
  return await ds.getEmployerStats(userId);
});

final recentApplicantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  return await ds.getRecentApplicants(userId);
});
