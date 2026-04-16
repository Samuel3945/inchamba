import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  static const String roleEmployer = 'empleador';
  static const String roleWorker = 'trabajador';

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String role; // 'empleador' or 'trabajador'
  final String? companyName;
  final String? avatarUrl;
  final String? bio;
  final List<String> categories;
  final double rating;
  final int ratingCount;
  final int jobsCompleted;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    this.companyName,
    this.avatarUrl,
    this.bio,
    this.categories = const [],
    this.rating = 0.0,
    this.ratingCount = 0,
    this.jobsCompleted = 0,
    required this.createdAt,
  });

  bool get isEmployer => role == roleEmployer;
  bool get isWorker => role == roleWorker;

  @override
  List<Object?> get props => [id, fullName, email, phone, city, role, companyName, avatarUrl, bio, categories, rating, ratingCount, jobsCompleted, createdAt];
}
