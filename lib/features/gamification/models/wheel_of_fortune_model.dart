class WheelTask {
  final String id;
  final String title;
  final String icon; // Category code e.g. 'pocket', 'silent'
  final String description;
  final String exceptions;

  WheelTask({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.exceptions,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'icon': icon,
    'description': description,
    'exceptions': exceptions,
  };

  factory WheelTask.fromJson(Map<String, dynamic> json) => WheelTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    description: json['description'] as String? ?? '',
    exceptions: json['exceptions'] as String? ?? '',
  );
}

class WheelOfFortune {
  final String id;
  final String code; // e.g. K15746
  final String name;
  final List<WheelTask> tasks;
  final String creatorName;
  final String creatorUid;
  final int likes;
  final bool isCustom;

  WheelOfFortune({
    required this.id,
    this.code = '',
    required this.name,
    required this.tasks,
    this.creatorName = 'HEJBEJ',
    this.creatorUid = '',
    this.likes = 0,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'creatorName': creatorName,
    'creatorUid': creatorUid,
    'likes': likes,
    'isCustom': isCustom,
  };

  factory WheelOfFortune.fromJson(Map<String, dynamic> json) => WheelOfFortune(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    tasks: (json['tasks'] as List<dynamic>?)
            ?.map((t) => WheelTask.fromJson(t as Map<String, dynamic>))
            .toList() ?? [],
    creatorName: json['creatorName'] as String? ?? 'HEJBEJ',
    creatorUid: json['creatorUid'] as String? ?? '',
    likes: json['likes'] as int? ?? 0,
    isCustom: json['isCustom'] as bool? ?? false,
  );
}
