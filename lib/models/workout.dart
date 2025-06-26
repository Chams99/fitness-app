class Exercise {
  final String exerciseId;
  final String name;
  final String? imageUrl;
  final List<String> equipments;
  final List<String> bodyParts;
  final String? exerciseType;
  final List<String> targetMuscles;
  final List<String> secondaryMuscles;
  final String? videoUrl;
  final String? overview;
  final List<String> instructions;
  final List<String> exerciseTips;
  final List<String> variations;

  const Exercise({
    required this.exerciseId,
    required this.name,
    this.imageUrl,
    required this.equipments,
    required this.bodyParts,
    this.exerciseType,
    required this.targetMuscles,
    required this.secondaryMuscles,
    this.videoUrl,
    this.overview,
    required this.instructions,
    required this.exerciseTips,
    required this.variations,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      exerciseId: json['exerciseId'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'],
      equipments: List<String>.from(json['equipments'] ?? []),
      bodyParts: List<String>.from(json['bodyParts'] ?? []),
      exerciseType: json['exerciseType'],
      targetMuscles: List<String>.from(json['targetMuscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondaryMuscles'] ?? []),
      videoUrl: json['videoUrl'],
      overview: json['overview'],
      instructions: List<String>.from(json['instructions'] ?? []),
      exerciseTips: List<String>.from(json['exerciseTips'] ?? []),
      variations: List<String>.from(json['variations'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'name': name,
      'imageUrl': imageUrl,
      'equipments': equipments,
      'bodyParts': bodyParts,
      'exerciseType': exerciseType,
      'targetMuscles': targetMuscles,
      'secondaryMuscles': secondaryMuscles,
      'videoUrl': videoUrl,
      'overview': overview,
      'instructions': instructions,
      'exerciseTips': exerciseTips,
      'variations': variations,
    };
  }
}

// Keep the old Workout class for backwards compatibility if needed elsewhere
class Workout {
  final String name;
  final String description;
  final String duration;
  final String calories;

  const Workout({
    required this.name,
    required this.description,
    required this.duration,
    required this.calories,
  });
}
