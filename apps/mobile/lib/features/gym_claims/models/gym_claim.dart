class GymClaim {
  final String id;
  final String gymId;
  final String claimantId;
  final String kind; // 'claim' | 'transfer'
  final String relationship; // 'owner' | 'head_coach' | 'manager'
  final String contact;
  final String message;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled'
  final String? previousOwnerId;
  final String? createdAt;
  final String? decidedAt;
  final String? decisionNote;

  const GymClaim({
    required this.id,
    required this.gymId,
    required this.claimantId,
    required this.kind,
    required this.relationship,
    required this.contact,
    required this.message,
    required this.status,
    this.previousOwnerId,
    this.createdAt,
    this.decidedAt,
    this.decisionNote,
  });

  factory GymClaim.fromJson(Map<String, dynamic> json) => GymClaim(
        id: json['id'] as String,
        gymId: json['gymId'] as String,
        claimantId: json['claimantId'] as String,
        kind: json['kind'] as String,
        relationship: json['relationship'] as String,
        contact: json['contact'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        previousOwnerId: json['previousOwnerId'] as String?,
        createdAt: json['createdAt'] as String?,
        decidedAt: json['decidedAt'] as String?,
        decisionNote: json['decisionNote'] as String?,
      );
}
