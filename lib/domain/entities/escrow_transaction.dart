import 'package:equatable/equatable.dart';

class EscrowTransaction extends Equatable {
  final String id;
  final String jobPostId;
  final String employerId;
  final double amount;
  final String status; // pending, held, released, refunded, disputed
  final String? boldReference;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EscrowTransaction({
    required this.id,
    required this.jobPostId,
    required this.employerId,
    required this.amount,
    this.status = 'pending',
    this.boldReference,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isHeld => status == 'held';
  bool get isReleased => status == 'released';

  @override
  List<Object?> get props => [id, jobPostId, employerId, amount, status];
}
