import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout.dart';

class ExerciseApiService {
  static const String baseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main';
  static const int pageSize = 20;

  // Cache for all exercises to avoid multiple API calls
  static List<Exercise>? _allExercisesCache;

  // Convert Free Exercise DB format to our Exercise model
  static Exercise _convertFreeExerciseDbToExercise(
    Map<String, dynamic> freeExercise,
  ) {
    // Get the base image URL
    final imageBaseUrl = '$baseUrl/exercises/';

    return Exercise(
      exerciseId: freeExercise['id'] ?? '',
      name: freeExercise['name'] ?? '',
      imageUrl:
          freeExercise['images']?.isNotEmpty == true
              ? '$imageBaseUrl${freeExercise['images'][0]}'
              : null,
      equipments: [freeExercise['equipment'] ?? 'bodyweight'],
      bodyParts: List<String>.from(freeExercise['primaryMuscles'] ?? []),
      exerciseType: freeExercise['category'] ?? 'strength',
      targetMuscles: List<String>.from(freeExercise['primaryMuscles'] ?? []),
      secondaryMuscles: List<String>.from(
        freeExercise['secondaryMuscles'] ?? [],
      ),
      videoUrl: null, // Free Exercise DB doesn't have videos
      overview:
          'A ${freeExercise['level'] ?? 'beginner'} level ${freeExercise['category'] ?? 'strength'} exercise targeting ${(freeExercise['primaryMuscles'] as List?)?.join(', ') ?? 'multiple muscle groups'}.',
      instructions: List<String>.from(freeExercise['instructions'] ?? []),
      exerciseTips:
          [], // Free Exercise DB doesn't have tips, we'll add some generic ones
      variations: [], // Free Exercise DB doesn't have variations
    );
  }

  // Fallback dummy data in case API fails
  static List<Exercise> _getFallbackExercises() {
    return [
      Exercise(
        exerciseId: 'push_ups',
        name: 'Push-ups',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['chest'],
        exerciseType: 'strength',
        targetMuscles: ['chest', 'triceps'],
        secondaryMuscles: ['shoulders'],
        videoUrl: null,
        overview:
            'A basic upper body exercise that targets the chest, triceps, and shoulders.',
        instructions: [
          'Start in a plank position with your hands placed slightly wider than shoulder-width apart',
          'Lower your body until your chest nearly touches the floor',
          'Push your body back up to the starting position',
          'Repeat for desired number of repetitions',
        ],
        exerciseTips: [
          'Keep your core engaged throughout the movement',
          'Maintain a straight line from head to heels',
        ],
        variations: [
          'Incline Push-ups',
          'Decline Push-ups',
          'Diamond Push-ups',
        ],
      ),
      Exercise(
        exerciseId: 'squats',
        name: 'Squats',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['quadriceps'],
        exerciseType: 'strength',
        targetMuscles: ['quadriceps', 'glutes'],
        secondaryMuscles: ['hamstrings', 'calves'],
        videoUrl: null,
        overview:
            'A fundamental lower body exercise that targets the quadriceps and glutes.',
        instructions: [
          'Stand with feet shoulder-width apart',
          'Lower your body as if sitting back into a chair',
          'Keep your chest up and knees behind your toes',
          'Return to standing position',
        ],
        exerciseTips: [
          'Keep your weight on your heels',
          'Don\'t let your knees cave inward',
        ],
        variations: ['Jump Squats', 'Goblet Squats', 'Bulgarian Split Squats'],
      ),
      Exercise(
        exerciseId: 'planks',
        name: 'Planks',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['abdominals'],
        exerciseType: 'strength',
        targetMuscles: ['abdominals', 'core'],
        secondaryMuscles: ['shoulders', 'back'],
        videoUrl: null,
        overview:
            'An isometric core exercise that strengthens the entire core and improves stability.',
        instructions: [
          'Start in a push-up position',
          'Lower to your forearms',
          'Hold your body in a straight line',
          'Engage your core and hold the position',
        ],
        exerciseTips: [
          'Don\'t let your hips sag or pike up',
          'Breathe steadily throughout the hold',
        ],
        variations: ['Side Plank', 'Plank with Leg Lifts', 'Plank Jacks'],
      ),
      Exercise(
        exerciseId: 'lunges',
        name: 'Lunges',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['quadriceps'],
        exerciseType: 'strength',
        targetMuscles: ['quadriceps', 'glutes'],
        secondaryMuscles: ['hamstrings', 'calves'],
        videoUrl: null,
        overview:
            'A unilateral lower body exercise that improves balance and leg strength.',
        instructions: [
          'Step forward with one leg',
          'Lower your hips until both knees are bent at 90 degrees',
          'Push back to the starting position',
          'Repeat with the other leg',
        ],
        exerciseTips: [
          'Keep your torso upright',
          'Don\'t let your front knee go past your toes',
        ],
        variations: ['Reverse Lunges', 'Lateral Lunges', 'Walking Lunges'],
      ),
      Exercise(
        exerciseId: 'burpees',
        name: 'Burpees',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['chest'],
        exerciseType: 'cardio',
        targetMuscles: ['full body'],
        secondaryMuscles: ['cardiovascular system'],
        videoUrl: null,
        overview:
            'A full-body exercise that combines strength training and cardio.',
        instructions: [
          'Start in standing position',
          'Drop into a squat and place hands on the floor',
          'Jump feet back into a plank position',
          'Do a push-up, then jump feet back to squat',
          'Jump up with arms overhead',
        ],
        exerciseTips: [
          'Modify by stepping back instead of jumping',
          'Focus on proper form over speed',
        ],
        variations: ['Half Burpees', 'Burpee Box Jumps', 'Single-arm Burpees'],
      ),
      Exercise(
        exerciseId: 'dumbbell_curls',
        name: 'Dumbbell Curls',
        imageUrl: null,
        equipments: ['dumbbell'],
        bodyParts: ['biceps'],
        exerciseType: 'strength',
        targetMuscles: ['biceps'],
        secondaryMuscles: ['forearms'],
        videoUrl: null,
        overview:
            'A classic arm exercise that targets the biceps using dumbbells.',
        instructions: [
          'Stand with feet shoulder-width apart, holding dumbbells at your sides',
          'Keep your elbows close to your body',
          'Curl the dumbbells up toward your shoulders',
          'Lower the dumbbells back down with control',
        ],
        exerciseTips: [
          'Keep your back straight and core engaged',
          'Don\'t swing the weights - use controlled movement',
        ],
        variations: ['Hammer Curls', 'Concentration Curls', 'Preacher Curls'],
      ),
      Exercise(
        exerciseId: 'barbell_bench_press',
        name: 'Barbell Bench Press',
        imageUrl: null,
        equipments: ['barbell'],
        bodyParts: ['chest'],
        exerciseType: 'strength',
        targetMuscles: ['chest', 'triceps'],
        secondaryMuscles: ['shoulders'],
        videoUrl: null,
        overview:
            'A compound exercise that primarily targets the chest muscles.',
        instructions: [
          'Lie on a flat bench with your feet on the ground',
          'Grip the barbell slightly wider than shoulder-width',
          'Lower the bar to your chest with control',
          'Press the bar back up to the starting position',
        ],
        exerciseTips: [
          'Keep your back flat on the bench',
          'Don\'t bounce the bar off your chest',
        ],
        variations: [
          'Incline Bench Press',
          'Decline Bench Press',
          'Close-Grip Bench Press',
        ],
      ),
      Exercise(
        exerciseId: 'pull_ups',
        name: 'Pull-ups',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['back'],
        exerciseType: 'strength',
        targetMuscles: ['lats', 'biceps'],
        secondaryMuscles: ['shoulders', 'forearms'],
        videoUrl: null,
        overview: 'An upper body exercise that targets the back and biceps.',
        instructions: [
          'Hang from a pull-up bar with hands shoulder-width apart',
          'Pull your body up until your chin is over the bar',
          'Lower your body back down with control',
          'Repeat for desired number of repetitions',
        ],
        exerciseTips: [
          'Engage your core throughout the movement',
          'Don\'t swing or use momentum',
        ],
        variations: ['Assisted Pull-ups', 'Wide-Grip Pull-ups', 'Chin-ups'],
      ),
      Exercise(
        exerciseId: 'deadlift',
        name: 'Deadlift',
        imageUrl: null,
        equipments: ['barbell'],
        bodyParts: ['back'],
        exerciseType: 'strength',
        targetMuscles: ['hamstrings', 'glutes', 'back'],
        secondaryMuscles: ['core', 'forearms'],
        videoUrl: null,
        overview: 'A compound exercise that targets the posterior chain.',
        instructions: [
          'Stand with feet hip-width apart, barbell on the ground',
          'Bend at hips and knees to grip the bar',
          'Keep your back straight and lift the bar by extending hips and knees',
          'Lower the bar back to the ground with control',
        ],
        exerciseTips: [
          'Keep your back straight throughout the movement',
          'Drive through your heels, not your toes',
        ],
        variations: ['Romanian Deadlift', 'Sumo Deadlift', 'Trap Bar Deadlift'],
      ),
      Exercise(
        exerciseId: 'shoulder_press',
        name: 'Shoulder Press',
        imageUrl: null,
        equipments: ['dumbbell'],
        bodyParts: ['shoulders'],
        exerciseType: 'strength',
        targetMuscles: ['shoulders', 'triceps'],
        secondaryMuscles: ['core'],
        videoUrl: null,
        overview: 'An overhead pressing movement that targets the shoulders.',
        instructions: [
          'Sit or stand with dumbbells at shoulder level',
          'Press the dumbbells overhead until arms are fully extended',
          'Lower the dumbbells back to shoulder level',
          'Repeat for desired number of repetitions',
        ],
        exerciseTips: [
          'Keep your core engaged to maintain stability',
          'Don\'t arch your back excessively',
        ],
        variations: ['Military Press', 'Arnold Press', 'Seated Shoulder Press'],
      ),
      Exercise(
        exerciseId: 'crunches',
        name: 'Crunches',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['abdominals'],
        exerciseType: 'strength',
        targetMuscles: ['abdominals'],
        secondaryMuscles: ['core'],
        videoUrl: null,
        overview:
            'A basic abdominal exercise that targets the rectus abdominis.',
        instructions: [
          'Lie on your back with knees bent and feet flat on the ground',
          'Place your hands behind your head or across your chest',
          'Lift your shoulders off the ground by contracting your abs',
          'Lower back down with control',
        ],
        exerciseTips: [
          'Don\'t pull on your neck with your hands',
          'Focus on contracting your abdominal muscles',
        ],
        variations: ['Bicycle Crunches', 'Reverse Crunches', 'Side Crunches'],
      ),
      Exercise(
        exerciseId: 'calf_raises',
        name: 'Calf Raises',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['calves'],
        exerciseType: 'strength',
        targetMuscles: ['calves'],
        secondaryMuscles: ['ankles'],
        videoUrl: null,
        overview: 'An isolation exercise that targets the calf muscles.',
        instructions: [
          'Stand with feet shoulder-width apart',
          'Raise your heels off the ground by pushing through your toes',
          'Hold the position briefly at the top',
          'Lower your heels back to the ground',
        ],
        exerciseTips: [
          'Keep your knees straight throughout the movement',
          'Focus on the full range of motion',
        ],
        variations: [
          'Seated Calf Raises',
          'Single-Leg Calf Raises',
          'Weighted Calf Raises',
        ],
      ),
      Exercise(
        exerciseId: 'tricep_dips',
        name: 'Tricep Dips',
        imageUrl: null,
        equipments: ['bodyweight'],
        bodyParts: ['triceps'],
        exerciseType: 'strength',
        targetMuscles: ['triceps'],
        secondaryMuscles: ['chest', 'shoulders'],
        videoUrl: null,
        overview: 'A bodyweight exercise that targets the triceps.',
        instructions: [
          'Position yourself on parallel bars or a dip station',
          'Lower your body by bending your elbows',
          'Push back up to the starting position',
          'Keep your body upright throughout the movement',
        ],
        exerciseTips: [
          'Keep your elbows close to your body',
          'Don\'t let your shoulders shrug up',
        ],
        variations: ['Bench Dips', 'Ring Dips', 'Weighted Dips'],
      ),
      Exercise(
        exerciseId: 'leg_press',
        name: 'Leg Press',
        imageUrl: null,
        equipments: ['machine'],
        bodyParts: ['quadriceps'],
        exerciseType: 'strength',
        targetMuscles: ['quadriceps', 'glutes'],
        secondaryMuscles: ['hamstrings'],
        videoUrl: null,
        overview: 'A machine-based exercise that targets the leg muscles.',
        instructions: [
          'Sit in the leg press machine with your back against the pad',
          'Place your feet on the platform shoulder-width apart',
          'Push the platform away by extending your knees and hips',
          'Return to the starting position with control',
        ],
        exerciseTips: [
          'Keep your back pressed against the seat',
          'Don\'t lock out your knees at the top',
        ],
        variations: [
          'Single-Leg Press',
          'Wide-Stance Leg Press',
          'Narrow-Stance Leg Press',
        ],
      ),
      Exercise(
        exerciseId: 'lat_pulldown',
        name: 'Lat Pulldown',
        imageUrl: null,
        equipments: ['cable'],
        bodyParts: ['back'],
        exerciseType: 'strength',
        targetMuscles: ['lats'],
        secondaryMuscles: ['biceps', 'shoulders'],
        videoUrl: null,
        overview: 'A cable exercise that targets the latissimus dorsi muscles.',
        instructions: [
          'Sit at the lat pulldown machine with thighs secured',
          'Grip the bar with hands wider than shoulder-width',
          'Pull the bar down to your upper chest',
          'Return the bar to the starting position with control',
        ],
        exerciseTips: [
          'Keep your chest up and shoulders back',
          'Focus on pulling with your back muscles, not your arms',
        ],
        variations: [
          'Close-Grip Lat Pulldown',
          'Wide-Grip Lat Pulldown',
          'Single-Arm Lat Pulldown',
        ],
      ),
      Exercise(
        exerciseId: 'rowing',
        name: 'Rowing',
        imageUrl: null,
        equipments: ['cardio'],
        bodyParts: ['cardio'],
        exerciseType: 'cardio',
        targetMuscles: ['cardiovascular system'],
        secondaryMuscles: ['back', 'legs'],
        videoUrl: null,
        overview: 'A cardiovascular exercise that also works the upper body.',
        instructions: [
          'Sit on the rowing machine with feet secured',
          'Grip the handle with both hands',
          'Push with your legs and pull with your arms',
          'Return to the starting position and repeat',
        ],
        exerciseTips: [
          'Maintain good posture throughout the movement',
          'Coordinate the leg drive with the arm pull',
        ],
        variations: ['Sprint Rowing', 'Endurance Rowing', 'Interval Rowing'],
      ),
      Exercise(
        exerciseId: 'battle_ropes',
        name: 'Battle Ropes',
        imageUrl: null,
        equipments: ['rope'],
        bodyParts: ['shoulders'],
        exerciseType: 'cardio',
        targetMuscles: ['shoulders', 'arms'],
        secondaryMuscles: ['core', 'cardiovascular system'],
        videoUrl: null,
        overview:
            'A high-intensity exercise using heavy ropes for cardio and strength.',
        instructions: [
          'Stand with feet shoulder-width apart, holding the ropes',
          'Create waves in the ropes by moving your arms up and down',
          'Alternate between different wave patterns',
          'Maintain the movement for the desired duration',
        ],
        exerciseTips: [
          'Keep your core engaged throughout the exercise',
          'Start with shorter intervals and build up',
        ],
        variations: ['Alternating Waves', 'Double Waves', 'Side-to-Side Waves'],
      ),
    ];
  }

  // Fetch all exercises from Free Exercise DB (cached)
  static Future<List<Exercise>> _fetchAllExercisesCached() async {
    if (_allExercisesCache != null) {
      return _allExercisesCache!;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dist/exercises.json'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        if (jsonData.isEmpty) {
          print('No exercises found in API response, using fallback');
          _allExercisesCache = _getFallbackExercises();
          return _allExercisesCache!;
        }

        _allExercisesCache =
            jsonData
                .map((json) => _convertFreeExerciseDbToExercise(json))
                .toList();
        return _allExercisesCache!;
      } else {
        print('API returned ${response.statusCode}, using fallback exercises');
        _allExercisesCache = _getFallbackExercises();
        return _allExercisesCache!;
      }
    } catch (e) {
      print('API failed, using fallback exercises: $e');
      _allExercisesCache = _getFallbackExercises();
      return _allExercisesCache!;
    }
  }

  // Get paginated exercises (default: first 20)
  static Future<List<Exercise>> fetchExercises({
    int page = 0,
    int limit = pageSize,
  }) async {
    final allExercises = await _fetchAllExercisesCached();
    final startIndex = page * limit;
    final endIndex = (startIndex + limit).clamp(0, allExercises.length);

    if (startIndex >= allExercises.length) {
      return [];
    }

    return allExercises.sublist(startIndex, endIndex);
  }

  // Get total count of exercises
  static Future<int> getTotalExerciseCount() async {
    final allExercises = await _fetchAllExercisesCached();
    return allExercises.length;
  }

  // Fetch exercises by body part with pagination
  static Future<List<Exercise>> fetchExercisesByBodyPart(
    String bodyPart, {
    int page = 0,
    int limit = pageSize,
  }) async {
    final allExercises = await _fetchAllExercisesCached();
    final filteredExercises =
        allExercises
            .where(
              (exercise) => exercise.bodyParts.any(
                (bp) => bp.toLowerCase().contains(bodyPart.toLowerCase()),
              ),
            )
            .toList();

    final startIndex = page * limit;
    final endIndex = (startIndex + limit).clamp(0, filteredExercises.length);

    if (startIndex >= filteredExercises.length) {
      return [];
    }

    return filteredExercises.sublist(startIndex, endIndex);
  }

  // Get total count for body part exercises
  static Future<int> getBodyPartExerciseCount(String bodyPart) async {
    final allExercises = await _fetchAllExercisesCached();
    return allExercises
        .where(
          (exercise) => exercise.bodyParts.any(
            (bp) => bp.toLowerCase().contains(bodyPart.toLowerCase()),
          ),
        )
        .length;
  }

  // Fetch exercises by equipment with pagination
  static Future<List<Exercise>> fetchExercisesByEquipment(
    String equipment, {
    int page = 0,
    int limit = pageSize,
  }) async {
    final allExercises = await _fetchAllExercisesCached();
    final filteredExercises =
        allExercises
            .where(
              (exercise) => exercise.equipments.any(
                (eq) => eq.toLowerCase().contains(equipment.toLowerCase()),
              ),
            )
            .toList();

    final startIndex = page * limit;
    final endIndex = (startIndex + limit).clamp(0, filteredExercises.length);

    if (startIndex >= filteredExercises.length) {
      return [];
    }

    return filteredExercises.sublist(startIndex, endIndex);
  }

  // Get total count for equipment exercises
  static Future<int> getEquipmentExerciseCount(String equipment) async {
    final allExercises = await _fetchAllExercisesCached();
    return allExercises
        .where(
          (exercise) => exercise.equipments.any(
            (eq) => eq.toLowerCase().contains(equipment.toLowerCase()),
          ),
        )
        .length;
  }

  // Fetch exercises by target muscle with pagination
  static Future<List<Exercise>> fetchExercisesByTarget(
    String target, {
    int page = 0,
    int limit = pageSize,
  }) async {
    final allExercises = await _fetchAllExercisesCached();
    final filteredExercises =
        allExercises
            .where(
              (exercise) => exercise.targetMuscles.any(
                (tm) => tm.toLowerCase().contains(target.toLowerCase()),
              ),
            )
            .toList();

    final startIndex = page * limit;
    final endIndex = (startIndex + limit).clamp(0, filteredExercises.length);

    if (startIndex >= filteredExercises.length) {
      return [];
    }

    return filteredExercises.sublist(startIndex, endIndex);
  }

  // Get total count for target muscle exercises
  static Future<int> getTargetExerciseCount(String target) async {
    final allExercises = await _fetchAllExercisesCached();
    return allExercises
        .where(
          (exercise) => exercise.targetMuscles.any(
            (tm) => tm.toLowerCase().contains(target.toLowerCase()),
          ),
        )
        .length;
  }

  // Search exercises by name (returns all matching results for search)
  static Future<List<Exercise>> searchExercisesByName(String name) async {
    final allExercises = await _fetchAllExercisesCached();
    return allExercises
        .where(
          (exercise) =>
              exercise.name.toLowerCase().contains(name.toLowerCase()),
        )
        .toList();
  }

  // Get exercise by ID
  static Future<Exercise> fetchExerciseById(String exerciseId) async {
    final allExercises = await _fetchAllExercisesCached();
    final exercise =
        allExercises.where((ex) => ex.exerciseId == exerciseId).firstOrNull;

    if (exercise != null) {
      return exercise;
    } else {
      throw Exception('Exercise not found: $exerciseId');
    }
  }

  // Get available muscle groups
  static Future<List<String>> getMuscleGroups() async {
    final allExercises = await _fetchAllExercisesCached();
    final muscleGroups = <String>{};

    for (var exercise in allExercises) {
      muscleGroups.addAll(exercise.bodyParts);
      muscleGroups.addAll(exercise.targetMuscles);
    }

    final sortedMuscles = muscleGroups.toList()..sort();
    return sortedMuscles.isNotEmpty
        ? sortedMuscles
        : ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core'];
  }

  // Get available equipment types
  static Future<List<String>> getEquipmentTypes() async {
    final allExercises = await _fetchAllExercisesCached();
    final equipmentTypes = <String>{};

    for (var exercise in allExercises) {
      equipmentTypes.addAll(exercise.equipments);
    }

    final sortedEquipment = equipmentTypes.toList()..sort();
    return sortedEquipment.isNotEmpty
        ? sortedEquipment
        : ['barbell', 'dumbbell', 'bodyweight', 'cable', 'machine'];
  }

  // Get available target muscles
  static Future<List<String>> getTargetMuscles() async {
    return getMuscleGroups();
  }

  // Legacy methods for compatibility (these will return first page only)
  static Future<List<Exercise>> fetchAllExercises() async {
    return fetchExercises(page: 0, limit: pageSize);
  }

  static Future<List<Exercise>> fetchExercisesByMuscle(String muscle) async {
    return fetchExercisesByTarget(muscle, page: 0, limit: pageSize);
  }

  static Future<List<String>> getBodyParts() async {
    return getMuscleGroups();
  }

  static Future<List<String>> getExerciseTypes() async {
    final allExercises = await _fetchAllExercisesCached();
    final exerciseTypes = <String>{};

    for (var exercise in allExercises) {
      if (exercise.exerciseType != null) {
        exerciseTypes.add(exercise.exerciseType!);
      }
    }

    final sortedTypes = exerciseTypes.toList()..sort();
    return sortedTypes.isNotEmpty
        ? sortedTypes
        : ['strength', 'cardio', 'flexibility', 'plyometrics'];
  }

  // Clear cache (useful for testing or when you want to refresh data)
  static void clearCache() {
    _allExercisesCache = null;
  }
}
