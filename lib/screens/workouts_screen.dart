import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/exercise_api_service.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<Exercise> exercises = [];
  List<Exercise> filteredExercises = [];
  List<String> bodyParts = [];
  List<String> equipmentTypes = [];
  bool isLoading = true;
  String? selectedBodyPart;
  String? selectedEquipment;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Load exercises and filter options in parallel
      final results = await Future.wait([
        ExerciseApiService.fetchExercises(page: 0, limit: 20),
        ExerciseApiService.getMuscleGroups(),
        ExerciseApiService.getEquipmentTypes(),
      ]);

      exercises = results[0] as List<Exercise>;
      bodyParts = results[1] as List<String>;
      equipmentTypes = results[2] as List<String>;

      setState(() {
        isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exercises: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredExercises =
          exercises.where((exercise) {
            // Search filter
            if (searchQuery.isNotEmpty &&
                !exercise.name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                )) {
              return false;
            }

            // Body part filter - make it more flexible
            if (selectedBodyPart != null) {
              bool hasMatchingBodyPart = exercise.bodyParts.any(
                (bp) =>
                    bp.toLowerCase().contains(
                      selectedBodyPart!.toLowerCase(),
                    ) ||
                    selectedBodyPart!.toLowerCase().contains(bp.toLowerCase()),
              );

              // Also check target muscles for body part matches
              bool hasMatchingTarget = exercise.targetMuscles.any(
                (tm) =>
                    tm.toLowerCase().contains(
                      selectedBodyPart!.toLowerCase(),
                    ) ||
                    selectedBodyPart!.toLowerCase().contains(tm.toLowerCase()),
              );

              if (!hasMatchingBodyPart && !hasMatchingTarget) {
                return false;
              }
            }

            // Equipment filter - make it more flexible
            if (selectedEquipment != null) {
              bool hasMatchingEquipment = exercise.equipments.any(
                (eq) =>
                    eq.toLowerCase().contains(
                      selectedEquipment!.toLowerCase(),
                    ) ||
                    selectedEquipment!.toLowerCase().contains(eq.toLowerCase()),
              );

              if (!hasMatchingEquipment) {
                return false;
              }
            }

            return true;
          }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      selectedBodyPart = null;
      selectedEquipment = null;
      searchQuery = '';
    });
    _applyFilters();
  }

  Future<void> _performSearch() async {
    if (searchQuery.isEmpty) {
      _loadData();
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final searchResults = await ExerciseApiService.searchExercisesByName(
        searchQuery,
      );

      setState(() {
        exercises = searchResults;
        filteredExercises = searchResults;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching exercises: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
          if (selectedBodyPart != null ||
              selectedEquipment != null ||
              searchQuery.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear), onPressed: _clearFilters),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search exercises...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              searchQuery = value;
                            },
                            onSubmitted: (value) {
                              _performSearch();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _performSearch,
                        ),
                      ],
                    ),
                  ),

                  // Active filters
                  if (selectedBodyPart != null || selectedEquipment != null)
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (selectedBodyPart != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Chip(
                                label: Text('Body: $selectedBodyPart'),
                                onDeleted: () {
                                  setState(() {
                                    selectedBodyPart = null;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                          if (selectedEquipment != null)
                            Chip(
                              label: Text('Equipment: $selectedEquipment'),
                              onDeleted: () {
                                setState(() {
                                  selectedEquipment = null;
                                });
                                _loadData();
                              },
                            ),
                        ],
                      ),
                    ),

                  // Results count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        searchQuery.isNotEmpty
                            ? '${filteredExercises.length} search results'
                            : '${filteredExercises.length} exercises shown (search for more)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                  // Exercise list
                  Expanded(
                    child:
                        filteredExercises.isEmpty
                            ? const Center(
                              child: Text(
                                'No exercises found.\nTry adjusting your filters or search for specific exercises.',
                                textAlign: TextAlign.center,
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: filteredExercises.length,
                              itemBuilder: (context, index) {
                                final exercise = filteredExercises[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16.0),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16.0),
                                    leading:
                                        exercise.imageUrl != null
                                            ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: Image.network(
                                                exercise.imageUrl!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[300],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8.0,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.fitness_center,
                                                      color: Colors.grey,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                            : Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: const Icon(
                                                Icons.fitness_center,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    title: Text(
                                      exercise.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        if (exercise.bodyParts.isNotEmpty)
                                          Wrap(
                                            spacing: 4.0,
                                            children:
                                                exercise.bodyParts.take(2).map((
                                                  bodyPart,
                                                ) {
                                                  return Chip(
                                                    label: Text(
                                                      bodyPart,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  );
                                                }).toList(),
                                          ),
                                        const SizedBox(height: 8),
                                        if (exercise.equipments.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.fitness_center,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  exercise.equipments.join(
                                                    ', ',
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      _showExerciseDetails(exercise);
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Exercises'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Body part filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Body Part',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedBodyPart,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Body Parts'),
                        ),
                        ...bodyParts.map((bodyPart) {
                          return DropdownMenuItem<String>(
                            value: bodyPart,
                            child: Text(bodyPart),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedBodyPart = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Equipment filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedEquipment,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Equipment'),
                        ),
                        ...equipmentTypes.map((equipment) {
                          return DropdownMenuItem<String>(
                            value: equipment,
                            child: Text(equipment),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedEquipment = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _loadData(); // Reload data with new filters
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExerciseDetails(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Exercise name
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Exercise details
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Image
                        if (exercise.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              exercise.imageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Overview
                        if (exercise.overview != null &&
                            exercise.overview!.isNotEmpty) ...[
                          Text(
                            'Overview',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(exercise.overview!),
                          const SizedBox(height: 16),
                        ],

                        // Body parts and equipment
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Body Parts',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4.0,
                                    children:
                                        exercise.bodyParts.map((bodyPart) {
                                          return Chip(label: Text(bodyPart));
                                        }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Equipment',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4.0,
                                    children:
                                        exercise.equipments.map((equipment) {
                                          return Chip(label: Text(equipment));
                                        }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Target muscles
                        if (exercise.targetMuscles.isNotEmpty) ...[
                          Text(
                            'Target Muscles',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4.0,
                            children:
                                exercise.targetMuscles.map((muscle) {
                                  return Chip(
                                    label: Text(muscle),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Instructions
                        if (exercise.instructions.isNotEmpty) ...[
                          Text(
                            'Instructions',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...exercise.instructions.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.key + 1}. ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(child: Text(entry.value)),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                        ],

                        // Tips
                        if (exercise.exerciseTips.isNotEmpty) ...[
                          Text(
                            'Tips',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...exercise.exerciseTips.map((tip) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(child: Text(tip)),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
