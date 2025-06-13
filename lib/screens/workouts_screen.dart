import 'package:flutter/material.dart';
import '../models/workout.dart';

class WorkoutsScreen extends StatelessWidget {
  // Dummy workout data
  final List<Workout> workouts = const [
    Workout(
      name: 'Push-ups',
      description: '3 sets of 15 reps',
      duration: '10 min',
      calories: '100',
    ),
    Workout(
      name: 'Squats',
      description: '4 sets of 20 reps',
      duration: '15 min',
      calories: '150',
    ),
    Workout(
      name: 'Running',
      description: '5km run at moderate pace',
      duration: '30 min',
      calories: '300',
    ),
    Workout(
      name: 'Plank',
      description: '3 sets of 1 minute',
      duration: '5 min',
      calories: '50',
    ),
    Workout(
      name: 'Jumping Jacks',
      description: '3 sets of 50 reps',
      duration: '10 min',
      calories: '120',
    ),
  ];

  WorkoutsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          final workout = workouts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              title: Text(
                workout.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(workout.description),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(workout.duration),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text('${workout.calories} cal'),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to workout details
              },
            ),
          );
        },
      ),
    );
  }
}
