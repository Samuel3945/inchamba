import 'package:equatable/equatable.dart';

class JobApplication extends Equatable {
  final String id;
  final String jobPostId;
  final String workerId;
  final String coverLetter;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  // Joined
  final String? workerName;
  final String? workerAvatar;
  final double? workerRating;
  final int? workerJobsCompleted;
  final String? jobTitle;
  final String? jobCategory;
  final double? jobPay;
  final String? jobPayType;
  final String? jobCity;
  final String? employerName;
  final List<String> attachmentUrls;
  final double? proposedPay;
  final DateTime? jobStartDate;
  final String? jobSchedule;

  const JobApplication({
    required this.id,
    required this.jobPostId,
    required this.workerId,
    required this.coverLetter,
    this.status = 'pending',
    required this.createdAt,
    this.workerName,
    this.workerAvatar,
    this.workerRating,
    this.workerJobsCompleted,
    this.jobTitle,
    this.jobCategory,
    this.jobPay,
    this.jobPayType,
    this.jobCity,
    this.employerName,
    this.attachmentUrls = const [],
    this.proposedPay,
    this.jobStartDate,
    this.jobSchedule,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  @override
  List<Object?> get props => [id, jobPostId, workerId, status, createdAt, proposedPay];
}
