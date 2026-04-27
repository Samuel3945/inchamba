import '../../domain/entities/job_application.dart';

class JobApplicationModel extends JobApplication {
  const JobApplicationModel({
    required super.id,
    required super.jobPostId,
    required super.workerId,
    required super.coverLetter,
    super.status,
    required super.createdAt,
    super.workerName,
    super.workerAvatar,
    super.workerRating,
    super.workerJobsCompleted,
    super.jobTitle,
    super.jobCategory,
    super.jobPay,
    super.jobPayType,
    super.jobCity,
    super.employerName,
    super.attachmentUrls,
    super.proposedPay,
    super.jobStartDate,
    super.jobSchedule,
  });

  factory JobApplicationModel.fromJson(Map<String, dynamic> json) {
    final worker = json['worker'] as Map<String, dynamic>?;
    final job = json['job_post'] as Map<String, dynamic>?;
    final attachments = json['application_attachments'] as List<dynamic>?;

    return JobApplicationModel(
      id: json['id'] as String,
      jobPostId: json['job_post_id'] as String,
      workerId: json['worker_id'] as String,
      coverLetter: json['cover_letter'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      workerName: worker?['full_name'] as String?,
      workerAvatar: worker?['avatar_url'] as String?,
      workerRating: (worker?['average_rating'] as num?)?.toDouble(),
      workerJobsCompleted: worker?['completed_jobs'] as int?,
      jobTitle: job?['title'] as String?,
      jobCategory: (job?['category'] as Map<String, dynamic>?)?['name'] as String?,
      jobPay: (job?['pay_amount'] as num?)?.toDouble(),
      jobPayType: job?['pay_type'] as String?,
      jobCity: job?['city'] as String?,
      employerName: (job?['employer'] as Map<String, dynamic>?)?['full_name'] as String?,
      attachmentUrls: attachments?.map((a) => (a as Map<String, dynamic>)['file_url'] as String).toList() ?? [],
      proposedPay: (json['proposed_pay'] as num?)?.toDouble(),
      jobStartDate: job?['start_date'] != null ? DateTime.tryParse(job!['start_date'] as String) : null,
      jobSchedule: job?['schedule'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'job_post_id': jobPostId,
      'worker_id': workerId,
      'cover_letter': coverLetter,
      'status': 'pending',
      if (proposedPay != null) 'proposed_pay': proposedPay,
    };
  }
}
