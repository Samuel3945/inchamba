import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.city,
    required super.role,
    super.companyName,
    super.avatarUrl,
    super.bio,
    super.categories,
    super.rating,
    super.ratingCount,
    super.jobsCompleted,
    required super.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      role: json['role'] as String? ?? Profile.roleWorker,
      companyName: json['company_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      categories: (json['skill_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['total_ratings'] as int? ?? 0,
      jobsCompleted: json['completed_jobs'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'role': role,
      'company_name': companyName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'skill_categories': categories,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'company_name': companyName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'skill_categories': categories,
    };
  }
}
