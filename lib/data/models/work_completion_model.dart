import '../../domain/entities/work_completion.dart';

class WorkCompletionModel extends WorkCompletion {
  const WorkCompletionModel({
    required super.id,
    required super.jobPostId,
    required super.applicationId,
    required super.workerId,
    super.completionNote,
    super.evidenceUrls,
    required super.workerMarkedAt,
    super.employerConfirmedAt,
    super.status,
    super.workerName,
    super.workerAvatar,
    super.jobTitle,
  });

  factory WorkCompletionModel.fromJson(Map<String, dynamic> json) {
    final worker = json['worker'] as Map<String, dynamic>?;
    final job = json['job_post'] as Map<String, dynamic>?;
    return WorkCompletionModel(
      id: json['id'] as String,
      jobPostId: json['job_post_id'] as String,
      applicationId: json['application_id'] as String,
      workerId: json['worker_id'] as String,
      completionNote: json['completion_note'] as String?,
      evidenceUrls: (json['evidence_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      workerMarkedAt: DateTime.parse(json['worker_marked_at'] as String),
      employerConfirmedAt: json['employer_confirmed_at'] != null
          ? DateTime.parse(json['employer_confirmed_at'] as String)
          : null,
      status: json['status'] as String? ?? 'pending_confirmation',
      workerName: worker?['full_name'] as String?,
      workerAvatar: worker?['avatar_url'] as String?,
      jobTitle: job?['title'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'job_post_id': jobPostId,
      'application_id': applicationId,
      'worker_id': workerId,
      'completion_note': completionNote,
      'evidence_urls': evidenceUrls,
      'status': 'pending_confirmation',
    };
  }
}
