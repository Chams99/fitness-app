class StepData {
  final DateTime date;
  final int steps;
  final double calories;
  final double distance;
  final DateTime timestamp;

  const StepData({
    required this.date,
    required this.steps,
    this.calories = 0.0,
    this.distance = 0.0,
    required this.timestamp,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String().substring(0, 10), // YYYY-MM-DD format
      'steps': steps,
      'calories': calories,
      'distance': distance,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create from Map for database retrieval
  factory StepData.fromMap(Map<String, dynamic> map) {
    return StepData(
      date: DateTime.parse(map['date']),
      steps: map['steps'] as int,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Get day of week for weekly comparison
  String get dayOfWeek {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  // Check if this is today's data
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Check if this is within the current week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  @override
  String toString() {
    return 'StepData(date: $date, steps: $steps, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepData &&
        other.date == date &&
        other.steps == steps &&
        other.calories == calories &&
        other.distance == distance;
  }

  @override
  int get hashCode =>
      date.hashCode ^ steps.hashCode ^ calories.hashCode ^ distance.hashCode;
}
