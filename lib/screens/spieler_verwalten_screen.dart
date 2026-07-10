import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spieler.dart';
import '../services/spiel_service.dart';

class SpielerVerwaltenScreen extends StatelessWidget {
  const SpielerVerwaltenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final spieler = service.allePlayerinnen;

    return Scaffold(
      appBar: AppBar(title: const Text('Spieler verwalten')),
      body: spieler.isEmpty
          ? const Center(child: Text('Noch keine Spieler angelegt'))
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: spieler.length,
        itemBuilder: (context, index) {
          final s = spieler[index];
          final kannGeloeschtWerden =
          service.spielerKannGeloeschtWerden(s);
          return Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: kannGeloeschtWerden
                  ? null
                  : const Text(
                'Nimmt an einem aktiven Spiel teil',
                style: TextStyle(color: Colors.orange),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: kannGeloeschtWerden
                    ? () => _loeschenBestaetigen(context, service, s)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  void _loeschenBestaetigen(
      BuildContext context, SpielService service, Spieler spieler) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spieler löschen?'),
        content: Text(
            '"${spieler.name}" wird aus der Liste entfernt. Bereits gespielte Runden bleiben unverändert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              service.spielerLoeschen(spieler);
              Navigator.of(ctx).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}