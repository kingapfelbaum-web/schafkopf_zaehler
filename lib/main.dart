import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/spiel_service.dart';
import 'screens/aktive_spiele_screen.dart';
import 'screens/statistik_screen.dart';
import 'screens/einstellungen_screen.dart';
import 'screens/neues_spiel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = SpielService();
  await service.ladeDaten();
  runApp(SchafkopfApp(service: service));
}

class SchafkopfApp extends StatelessWidget {
  final SpielService service;
  const SchafkopfApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: service,
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
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_index == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Neues Spiel'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NeuesSpielScreen()),
                    ),
                  ),
                ),
              ),
            NavigationBar(
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
          ],
        ),
      ),
    );
  }
}
