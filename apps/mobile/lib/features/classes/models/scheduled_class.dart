class ScheduledClass {
  final String classId;
  final String gymId;
  final String date;
  final String title;
  final String classType;
  final String? classTypeLabel;
  final String giType;
  final String skillLevel;
  final String startTime;
  final String endTime;
  final String? instructorUserId;
  final String? instructorName;
  final String status;
  final String? note;
  final int? capacity;
  final int goingCount;

  const ScheduledClass({
    required this.classId,
    required this.gymId,
    required this.date,
    required this.title,
    required this.classType,
    this.classTypeLabel,
    required this.giType,
    required this.skillLevel,
    required this.startTime,
    required this.endTime,
    this.instructorUserId,
    this.instructorName,
    required this.status,
    this.note,
    this.capacity,
    required this.goingCount,
  });

  factory ScheduledClass.fromJson(Map<String, dynamic> json) => ScheduledClass(
        classId: json['classId'] as String,
        gymId: json['gymId'] as String,
        date: json['date'] as String,
        title: json['title'] as String,
        classType: json['classType'] as String,
        classTypeLabel: json['classTypeLabel'] as String?,
        giType: json['giType'] as String,
        skillLevel: json['skillLevel'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        instructorUserId: json['instructorUserId'] as String?,
        instructorName: json['instructorName'] as String?,
        status: json['status'] as String,
        note: json['note'] as String?,
        capacity: json['capacity'] as int?,
        goingCount: json['goingCount'] as int,
      );

  bool get isCancelled => status == 'cancelled';
}
