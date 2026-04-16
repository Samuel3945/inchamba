import 'package:equatable/equatable.dart';

class WorkCompletion extends Equatable {
  final String id;
  final String jobPostId;
  final String applicationId;
  final String workerId;
  final String? completionNote;
  final List<String> evidenceUrls;
  final DateTime workerMarkedAt;
  final DateTime? employerConfirmedAt;
  final String status; // pending_confirmation, confirmed, disputed

  // Joined
  final String? workerName;
  final String? workerAvatar;
  final String? jobTitle;

  const WorkCompletion({
    required this.id,
    required this.jobPostId,
    required this.applicationId,
    required this.workerId,
    this.completionNote,
    this.evidenceUrls = const [],
    required this.workerMarkedAt,
    this.employerConfirmedAt,
    this.status = 'pending_confirmation',
    this.workerName,
    this.workerAvatar,
    this.jobTitle,
  });

  bool get isPending => status == 'pending_confirmation';
  bool get isConfirmed => status == 'confirmed';
  bool get isDisputed => status == 'disputed';

  @override
  List<Object?> get props => [id, jobPostId, workerId, status];
}
