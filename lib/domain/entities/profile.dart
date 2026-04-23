import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  static const String roleEmployer = 'empleador';
  static const String roleWorker = 'trabajador';

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String role;
  final String? companyName;
  final String? avatarUrl;
  final String? bio;
  final String? cedula;
  final List<String> categories;
  final double rating;
  final int ratingCount;
  final int jobsCompleted;
  final DateTime createdAt;
  final bool phoneVerified;

  // Campos extraídos de la cédula
  final String? cedulaPlaceBirth;
  final String? cedulaBloodType;
  final String? cedulaSex;
  final int? cedulaHeightCm;
  final DateTime? cedulaDateBirth;

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
    this.cedula,
    this.categories = const [],
    this.rating = 0.0,
    this.ratingCount = 0,
    this.jobsCompleted = 0,
    required this.createdAt,
    this.phoneVerified = false,
    this.cedulaPlaceBirth,
    this.cedulaBloodType,
    this.cedulaSex,
    this.cedulaHeightCm,
    this.cedulaDateBirth,
  });

  bool get isEmployer => role == roleEmployer;
  bool get isWorker => role == roleWorker;
  bool get hasCedula => cedula != null && cedula!.isNotEmpty;

  int? get age {
    if (cedulaDateBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - cedulaDateBirth!.year;
    if (now.month < cedulaDateBirth!.month ||
        (now.month == cedulaDateBirth!.month && now.day < cedulaDateBirth!.day)) {
      years--;
    }
    return years;
  }

  @override
  List<Object?> get props => [
        id, fullName, email, phone, city, role, companyName, avatarUrl, bio,
        cedula, categories, rating, ratingCount, jobsCompleted, createdAt,
        phoneVerified, cedulaPlaceBirth, cedulaBloodType, cedulaSex,
        cedulaHeightCm, cedulaDateBirth,
      ];
}
