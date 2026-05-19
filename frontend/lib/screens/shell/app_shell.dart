import 'package:flutter/material.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../home/home_screen.dart';
import '../bookings/bookings_screen.dart';
import '../composer/chat_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => AppShellState();

  static AppShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();
}

class AppShellState extends State<AppShell> {
  int _index = 0;

  void switchTo(int index) => setState(() => _index = index);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          BookingsScreen(),
          ChatScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: EzBottomNav(
        activeIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
