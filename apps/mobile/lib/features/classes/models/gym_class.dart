class GymClass {
  final String id;
  final String gymId;
  final String title;
  final String classType;
  final String? classTypeLabel;
  final String? description;
  final String giType;
  final String skillLevel;
  final String? instructorUserId;
  final String? instructorName;
  final bool isRecurring;
  final int? dayOfWeek;
  final String startTime;
  final String endTime;
  final String? specificDate;
  final int? capacity;
  final String status;
  final String? createdAt;

  const GymClass({
    required this.id,
    required this.gymId,
    required this.title,
    required this.classType,
    this.classTypeLabel,
    this.description,
    required this.giType,
    required this.skillLevel,
    this.instructorUserId,
    this.instructorName,
    required this.isRecurring,
    this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.specificDate,
    this.capacity,
    required this.status,
    this.createdAt,
  });

  factory GymClass.fromJson(Map<String, dynamic> json) => GymClass(
        id: json['id'] as String,
        gymId: json['gymId'] as String,
        title: json['title'] as String,
        classType: json['classType'] as String,
        classTypeLabel: json['classTypeLabel'] as String?,
        description: json['description'] as String?,
        giType: json['giType'] as String,
        skillLevel: json['skillLevel'] as String,
        instructorUserId: json['instructorUserId'] as String?,
        instructorName: json['instructorName'] as String?,
        isRecurring: json['isRecurring'] as bool,
        dayOfWeek: json['dayOfWeek'] as int?,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        specificDate: json['specificDate'] as String?,
        capacity: json['capacity'] as int?,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String?,
      );
}
