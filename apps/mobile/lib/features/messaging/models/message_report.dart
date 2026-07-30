class MessageReport {
  final String id;
  final String? messageId;
  final String reportedUserId;
  final String reporterId;
  final String gymId;
  final String reason;
  final String? note;
  final String status;
  final String? createdAt;
  final String? reviewedAt;

  const MessageReport({
    required this.id,
    this.messageId,
    required this.reportedUserId,
    required this.reporterId,
    required this.gymId,
    required this.reason,
    this.note,
    required this.status,
    this.createdAt,
    this.reviewedAt,
  });

  factory MessageReport.fromJson(Map<String, dynamic> json) => MessageReport(
        id: json['id'] as String,
        messageId: json['messageId'] as String?,
        reportedUserId: json['reportedUserId'] as String,
        reporterId: json['reporterId'] as String,
        gymId: json['gymId'] as String,
        reason: json['reason'] as String,
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'open',
        createdAt: json['createdAt'] as String?,
        reviewedAt: json['reviewedAt'] as String?,
      );
}
