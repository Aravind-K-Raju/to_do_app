import 'package:flutter/material.dart';
import 'screens/course_list_screen.dart';
import 'screens/study_timer_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/hackathon_list_screen.dart';
import 'screens/insights_screen.dart';

class NavigationScaffold extends StatefulWidget {
  const NavigationScaffold({super.key});

  @override
  State<NavigationScaffold> createState() => _NavigationScaffoldState();
}

class _NavigationScaffoldState extends State<NavigationScaffold> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const CourseListScreen(),
    const PlannerScreen(),
    const HackathonListScreen(),
    const StudyTimerScreen(),
    const InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Needed for 4+ items
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Courses'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Planner',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Study'),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
