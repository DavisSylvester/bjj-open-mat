class AppNotification {
  final String id;
  final String type; // rsvp | review | session_update | system
  final String title;
  final String body;
  final bool read;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'system',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: json['createdAt'] as String? ?? '',
      );
}

String relativeTime(String iso, {DateTime? now}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
