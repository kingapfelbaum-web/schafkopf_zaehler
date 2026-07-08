import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/spiel_service.dart';
import 'neues_spiel_screen.dart';
import 'tisch_detail_screen.dart';

class AktiveSpieleScreen extends StatelessWidget {
  const AktiveSpieleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final tische = service.aktiveTische;

    return Scaffold(
      appBar: AppBar(title: const Text('Aktive Spiele')),
      body: tische.isEmpty
          ? const Center(child: Text('Noch kein aktives Spiel'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: tische.length,
              itemBuilder: (context, index) {
                final tisch = tische[index];
                return Card(
                  child: ListTile(
                    title: Text(
                        '${tisch.spieler.map((s) => s.name).join(', ')}'),
                    subtitle: Text(
                        '${tisch.runden.length} Runden · seit ${tisch.erstelltAm.day}.${tisch.erstelltAm.month}.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TischDetailScreen(tisch: tisch),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Neues Spiel'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NeuesSpielScreen()),
        ),
      ),
    );
  }
}
