import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/spiel_service.dart';
import 'screens/aktive_spiele_screen.dart';
import 'screens/statistik_screen.dart';
import 'screens/einstellungen_screen.dart';

void main() {
  runApp(const SchafkopfApp());
}

class SchafkopfApp extends StatelessWidget {
  const SchafkopfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SpielService(),
      child: MaterialApp(
        title: 'Schafkopf',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade800),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screens = [
    AktiveSpieleScreen(),
    StatistikScreen(),
    EinstellungenScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.sports_esports), label: 'Aktive Spiele'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Statistik'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'Einstellungen'),
        ],
      ),
    );
  }
}
