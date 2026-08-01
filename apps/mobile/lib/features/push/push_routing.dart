String? routeForPushData(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  if (type == null) return null;
  if (type == 'message') {
    final id = data['conversationId'] as String?;
    return (id != null && id.isNotEmpty) ? '/messages/$id' : null;
  }
  return '/notifications';
}
