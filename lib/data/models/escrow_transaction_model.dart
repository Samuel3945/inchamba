import '../../domain/entities/escrow_transaction.dart';

class EscrowTransactionModel extends EscrowTransaction {
  const EscrowTransactionModel({
    required super.id,
    required super.jobPostId,
    required super.employerId,
    required super.amount,
    super.status,
    super.boldReference,
    required super.createdAt,
    super.updatedAt,
  });

  factory EscrowTransactionModel.fromJson(Map<String, dynamic> json) {
    return EscrowTransactionModel(
      id: json['id'] as String,
      jobPostId: json['job_post_id'] as String,
      employerId: json['employer_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      boldReference: json['bold_reference'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'job_post_id': jobPostId,
      'employer_id': employerId,
      'amount': amount,
      'status': 'pending',
      'bold_reference': boldReference,
    };
  }
}
