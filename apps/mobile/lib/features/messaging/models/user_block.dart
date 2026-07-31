class UserBlock {
  final String id;
  final String blockerId;
  final String blockedId;
  final String? createdAt;

  const UserBlock({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    this.createdAt,
  });

  factory UserBlock.fromJson(Map<String, dynamic> json) => UserBlock(
        id: json['id'] as String,
        blockerId: json['blockerId'] as String,
        blockedId: json['blockedId'] as String,
        createdAt: json['createdAt'] as String?,
      );
}
