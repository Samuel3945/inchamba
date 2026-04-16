import 'package:equatable/equatable.dart';

class Rating extends Equatable {
  final String id;
  final String jobPostId;
  final String applicationId;
  final String raterId;
  final String ratedId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  // Joined
  final String? raterName;
  final String? raterAvatar;

  const Rating({
    required this.id,
    required this.jobPostId,
    required this.applicationId,
    required this.raterId,
    required this.ratedId,
    required this.stars,
    this.comment,
    required this.createdAt,
    this.raterName,
    this.raterAvatar,
  });

  @override
  List<Object?> get props => [id, jobPostId, raterId, ratedId, stars];
}
