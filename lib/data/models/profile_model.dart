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
    super.cedula,
    super.categories,
    super.rating,
    super.ratingCount,
    super.jobsCompleted,
    required super.createdAt,
    super.phoneVerified,
    super.cedulaPlaceBirth,
    super.cedulaBloodType,
    super.cedulaSex,
    super.cedulaHeightCm,
    super.cedulaDateBirth,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseCedulaDate(dynamic raw) {
      if (raw == null) return null;
      try {
        return DateTime.parse(raw as String);
      } catch (_) {
        return null;
      }
    }

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
      cedula: json['cedula'] as String?,
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
      phoneVerified: json['phone_verified'] as bool? ?? false,
      cedulaPlaceBirth: json['cedula_place_birth'] as String?,
      cedulaBloodType: json['cedula_blood_type'] as String?,
      cedulaSex: json['cedula_sex'] as String?,
      cedulaHeightCm: json['cedula_height_cm'] as int?,
      cedulaDateBirth: parseCedulaDate(json['cedula_date_birth']),
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
      if (cedula != null) 'cedula': cedula,
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
      if (cedula != null) 'cedula': cedula,
      'skill_categories': categories,
    };
  }
}
