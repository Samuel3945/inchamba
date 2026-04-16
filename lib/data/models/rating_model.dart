import '../../domain/entities/rating.dart';

class RatingModel extends Rating {
  const RatingModel({
    required super.id,
    required super.jobPostId,
    required super.applicationId,
    required super.raterId,
    required super.ratedId,
    required super.stars,
    super.comment,
    required super.createdAt,
    super.raterName,
    super.raterAvatar,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    final rater = json['rater'] as Map<String, dynamic>?;
    return RatingModel(
      id: json['id'] as String,
      jobPostId: json['job_post_id'] as String,
      applicationId: json['application_id'] as String,
      raterId: json['rater_id'] as String,
      ratedId: json['rated_id'] as String,
      stars: json['score'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      raterName: rater?['full_name'] as String?,
      raterAvatar: rater?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'job_post_id': jobPostId,
      'application_id': applicationId,
      'rater_id': raterId,
      'rated_id': ratedId,
      'score': stars,
      'comment': comment,
    };
  }
}
