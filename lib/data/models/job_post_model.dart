import '../../domain/entities/job_post.dart';

class JobPostModel extends JobPost {
  const JobPostModel({
    required super.id,
    required super.employerId,
    required super.title,
    required super.description,
    super.categoryId,
    super.categoryName,
    super.categoryIcon,
    required super.city,
    super.department,
    super.address,
    required super.pay,
    required super.payType,
    required super.workersNeeded,
    super.workersHired,
    super.requirements,
    super.startDate,
    super.durationDays,
    super.schedule,
    super.status,
    super.totalEscrowRequired,
    required super.createdAt,
    super.publishedAt,
    super.expiresAt,
    super.employerName,
    super.employerAvatar,
    super.employerRating,
    super.difficultyStars = 3,
  });

  factory JobPostModel.fromJson(Map<String, dynamic> json) {
    final employer = json['employer'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;
    return JobPostModel(
      id: json['id'] as String,
      employerId: json['employer_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      categoryName: category?['name'] as String?,
      categoryIcon: category?['icon'] as String?,
      city: json['city'] as String? ?? '',
      department: json['department'] as String?,
      address: json['address'] as String?,
      pay: (json['pay_amount'] as num?)?.toDouble() ?? 0,
      payType: json['pay_type'] as String? ?? 'por_trabajo',
      workersNeeded: json['workers_needed'] as int? ?? 1,
      workersHired: json['workers_hired'] as int? ?? 0,
      requirements: (json['requirements'] as List<dynamic>?)?.cast<String>() ?? [],
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      durationDays: json['duration_days'] as int?,
      schedule: json['schedule'] as String?,
      status: json['status'] as String? ?? 'pending_payment',
      totalEscrowRequired: (json['total_escrow_required'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      employerName: employer?['full_name'] as String?,
      employerAvatar: employer?['avatar_url'] as String?,
      employerRating: (employer?['average_rating'] as num?)?.toDouble(),
      difficultyStars: (json['difficulty_stars'] as int?) ?? 3,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'employer_id': employerId,
      'title': title,
      'description': description,
      if (categoryId != null) 'category_id': categoryId,
      'city': city,
      if (department != null) 'department': department,
      if (address != null) 'address': address,
      'pay_amount': pay,
      'pay_type': payType,
      'workers_needed': workersNeeded,
      'requirements': requirements,
      if (startDate != null) 'start_date': startDate!.toIso8601String().split('T').first,
      if (durationDays != null) 'duration_days': durationDays,
      if (schedule != null) 'schedule': schedule,
      'status': status,
      'total_escrow_required': totalEscrowRequired,
    };
  }
}
