import '../../domain/entities/dispute.dart';

class DisputeModel extends Dispute {
  const DisputeModel({
    required super.id,
    required super.jobPostId,
    super.applicationId,
    required super.reportedBy,
    super.reportedAgainst,
    required super.reason,
    required super.description,
    super.evidenceUrls,
    super.status,
    super.resolutionNotes,
    super.resolvedBy,
    required super.createdAt,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    return DisputeModel(
      id: json['id'] as String,
      jobPostId: json['job_post_id'] as String,
      applicationId: json['application_id'] as String?,
      reportedBy: json['reported_by'] as String,
      reportedAgainst: json['reported_against'] as String?,
      reason: json['reason'] as String,
      description: json['description'] as String? ?? '',
      evidenceUrls: (json['evidence_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'open',
      resolutionNotes: json['resolution_notes'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'job_post_id': jobPostId,
      if (applicationId != null) 'application_id': applicationId,
      'reported_by': reportedBy,
      if (reportedAgainst != null) 'reported_against': reportedAgainst,
      'reason': reason,
      'description': description,
      'evidence_urls': evidenceUrls,
      'status': 'open',
    };
  }
}
