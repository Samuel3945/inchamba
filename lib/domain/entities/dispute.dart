import 'package:equatable/equatable.dart';

class Dispute extends Equatable {
  final String id;
  final String jobPostId;
  final String? applicationId;
  final String reportedBy;
  final String? reportedAgainst;
  final String reason;
  final String description;
  final List<String> evidenceUrls;
  final String status; // open, under_review, resolved_worker, resolved_employer, closed
  final String? resolutionNotes;
  final String? resolvedBy;
  final DateTime createdAt;

  const Dispute({
    required this.id,
    required this.jobPostId,
    this.applicationId,
    required this.reportedBy,
    this.reportedAgainst,
    required this.reason,
    required this.description,
    this.evidenceUrls = const [],
    this.status = 'open',
    this.resolutionNotes,
    this.resolvedBy,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, jobPostId, reportedBy, status];
}
