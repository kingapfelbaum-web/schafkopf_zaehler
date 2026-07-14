import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/spielart.dart';
import '../services/spiel_service.dart';

class SpieleBearbeitenScreen extends StatelessWidget {
  const SpieleBearbeitenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Spiele bearbeiten')),
      body: service.spielarten.isEmpty
          ? const Center(child: Text('Noch keine Spielarten angelegt'))
          : ListView.builder(
              padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom+80),
              itemCount: service.spielarten.length,
              itemBuilder: (context, index) {
                final s = service.spielarten[index];
                return Card(
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(_untertitel(s)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _bearbeitenDialog(context, service, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _loeschenBestaetigen(context, service, s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Spielart hinzufügen'),
        onPressed: () => _bearbeitenDialog(context, service, null),
      ),
    );
  }

  String _untertitel(Spielart s) {
    final tarif = s.einzelspieler
        ? 'Solo-Tarif (Grundpreis: Solo)'
        : 'Sauspiel-Tarif (Grundpreis: Sauspiel)';
    final modus = s.individuelleGewinner
        ? 'individuelle Gewinner, Unentschieden möglich'
        : 'feste Partei (${s.anzahlSpielerpartei} gegen ${4 - s.anzahlSpielerpartei})';
    return '$tarif · $modus';
  }

  void _bearbeitenDialog(
      BuildContext context, SpielService service, Spielart? bestehende) {
    final nameController = TextEditingController(text: bestehende?.name ?? '');
    bool einzelspieler = bestehende?.einzelspieler ?? true;
    bool individuelleGewinner = bestehende?.individuelleGewinner ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(bestehende == null
              ? 'Neue Spielart'
              : 'Spielart bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Grundpreis'),
                const SizedBox(height: 4),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sauspiel')),
                    ButtonSegment(value: true, label: Text('Solo')),
                  ],
                  selected: {einzelspieler},
                  onSelectionChanged: (selection) =>
                      setState(() => einzelspieler = selection.first),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Individuelle Gewinner'),
                  subtitle: const Text(
                      'Statt fester Partei werden Gewinner pro Runde einzeln gewählt (0, 1 oder 2). Ermöglicht Unentschieden, z.B. für Ramsch.'),
                  value: individuelleGewinner,
                  onChanged: (v) =>
                      setState(() => individuelleGewinner = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (bestehende == null) {
                  service.spielartHinzufuegen(name, einzelspieler,
                      individuelleGewinner: individuelleGewinner);
                } else {
                  service.spielartAktualisieren(
                      bestehende, name, einzelspieler,
                      individuelleGewinner: individuelleGewinner);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _loeschenBestaetigen(
      BuildContext context, SpielService service, Spielart s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spielart löschen?'),
        content: Text(
            '"${s.name}" wird aus dem Katalog entfernt. Bereits gespielte Runden bleiben unverändert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              service.spielartLoeschen(s);
              Navigator.of(ctx).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
