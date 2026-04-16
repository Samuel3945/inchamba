import 'package:equatable/equatable.dart';

class JobPost extends Equatable {
  final String id;
  final String employerId;
  final String title;
  final String description;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String city;
  final String? department;
  final String? address;
  final double pay;
  final String payType; // hora, dia, semana, mes, por_trabajo
  final int workersNeeded;
  final int workersHired;
  final List<String> requirements;
  final DateTime? startDate;
  final int? durationDays;
  final String? schedule;
  final String status; // pending_payment, active, in_progress, completed, cancelled, disputed
  final double totalEscrowRequired;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  // Joined fields
  final String? employerName;
  final String? employerAvatar;
  final double? employerRating;

  const JobPost({
    required this.id,
    required this.employerId,
    required this.title,
    required this.description,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    required this.city,
    this.department,
    this.address,
    required this.pay,
    required this.payType,
    required this.workersNeeded,
    this.workersHired = 0,
    this.requirements = const [],
    this.startDate,
    this.durationDays,
    this.schedule,
    this.status = 'pending_payment',
    this.totalEscrowRequired = 0,
    required this.createdAt,
    this.publishedAt,
    this.expiresAt,
    this.employerName,
    this.employerAvatar,
    this.employerRating,
  });

  bool get isUrgent {
    if (workersNeeded > 3) return true;
    if (startDate != null) {
      final daysUntilStart = startDate!.difference(DateTime.now()).inDays;
      return daysUntilStart <= 2 && daysUntilStart >= 0;
    }
    return false;
  }

  bool get isFull => workersHired >= workersNeeded;
  int get spotsLeft => workersNeeded - workersHired;

  @override
  List<Object?> get props => [id, employerId, title, status, createdAt];
}
