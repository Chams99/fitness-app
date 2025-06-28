import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/workouts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/food_scanner_screen.dart';
import 'models/user.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';
import 'services/units_service.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await ThemeService().init();
  await UnitsService().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  User? _savedUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');

      if (userJson != null && userJson.isNotEmpty) {
        final data = jsonDecode(userJson) as Map<String, dynamic>;

        // Validate required fields
        if (data.containsKey('name') &&
            data.containsKey('weight') &&
            data.containsKey('height')) {
          _savedUser = User(
            name: data['name'] as String,
            goal: data['goal'] as String? ?? '10,000 steps daily',
            dailySteps: (data['dailySteps'] as num?)?.toInt() ?? 0,
            dailyCalories: (data['dailyCalories'] as num?)?.toInt() ?? 0,
            dailyWorkoutMinutes:
                (data['dailyWorkoutMinutes'] as num?)?.toInt() ?? 0,
            weight: (data['weight'] as num).toDouble(),
            height: (data['height'] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      // If there's any error, _savedUser remains null
      _savedUser = null;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'FitLite',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home:
              _isLoading
                  ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                  : _savedUser != null
                  ? MainScreen(user: _savedUser!)
                  : const OnboardingScreen(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is User) {
                return MainScreen(user: args);
              } else if (_savedUser != null) {
                return MainScreen(user: _savedUser!);
              } else {
                return const OnboardingScreen();
              }
            },
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final User user;

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(user: widget.user),
      const WorkoutsScreen(),
      const FoodScannerScreen(),
      ProfileScreen(user: widget.user),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Iconsax.home5), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.weight_15),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Food Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.personalcard5),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
