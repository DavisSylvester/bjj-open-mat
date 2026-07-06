class Report {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String description;
  final String status;
  final String? createdAt;
  final int? githubIssueNumber;
  final String? githubIssueUrl;

  const Report({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    this.createdAt,
    this.githubIssueNumber,
    this.githubIssueUrl,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'bug',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['createdAt'] as String?,
      githubIssueNumber: (json['githubIssueNumber'] as num?)?.toInt(),
      githubIssueUrl: json['githubIssueUrl'] as String?,
    );
  }
}
