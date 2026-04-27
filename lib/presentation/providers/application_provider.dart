import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/job_application_model.dart';
import '../../core/constants/app_constants.dart';
import 'core_providers.dart';

final workerApplicationsProvider = FutureProvider.family<List<JobApplicationModel>, String?>((ref, status) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  final data = await ds.getWorkerApplications(userId, status: status);
  return data.map((a) => JobApplicationModel.fromJson(a)).toList();
});

final jobApplicationsProvider = FutureProvider.family<List<JobApplicationModel>, String>((ref, jobPostId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final data = await ds.getJobApplications(jobPostId);
  return data.map((a) => JobApplicationModel.fromJson(a)).toList();
});

final myApplicationForJobProvider = FutureProvider.family<JobApplicationModel?, String>((ref, jobPostId) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return null;
  final data = await ds.getApplication(jobPostId, userId);
  if (data == null) return null;
  return JobApplicationModel.fromJson(data);
});

class ApplicationSubmitter {
  final SupabaseDatasource _datasource;

  ApplicationSubmitter(this._datasource);

  Future<void> submit({
    required String jobPostId,
    required String coverLetter,
    List<XFile> attachments = const [],
    String? audioUrl,
    double? proposedPay,
  }) async {
    final userId = _datasource.currentUserId!;
    final app = await _datasource.createApplication({
      'job_post_id': jobPostId,
      'worker_id': userId,
      'cover_letter': coverLetter,
      'status': 'pending',
      'audio_url': ?audioUrl,
      'proposed_pay': ?proposedPay,
    });

    for (final xfile in attachments) {
      final url = await _datasource.uploadXFile(
        AppConstants.applicationAttachmentsBucket,
        xfile,
      );
      await _datasource.createAttachment(app['id'] as String, url);
    }
  }
}

final applicationSubmitterProvider = Provider<ApplicationSubmitter>((ref) {
  return ApplicationSubmitter(ref.watch(supabaseDatasourceProvider));
});
