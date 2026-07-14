import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tisch.dart';
import '../services/spiel_service.dart';
import 'runde_erfassen_screen.dart';

class TischDetailScreen extends StatelessWidget {
  final Tisch tisch;
  const TischDetailScreen({super.key, required this.tisch});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final punktestand = tisch.punktestand;
    final istAktiv = tisch.status == TischStatus.aktiv;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tisch vom ${_formatDatum(tisch.erstelltAm)}'),
        actions: [
          if (istAktiv)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () => _beendenBestaetigen(context, service),
              icon: const Icon(Icons.flag),
              label: const Text('Beenden'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Spieler (Reihenfolge)',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tisch.spieler.length,
            onReorder: istAktiv
                ? (oldIndex, newIndex) => service.spielerReihenfolgeAendern(
                    tisch, oldIndex, newIndex)
                : (_, __) {},
            itemBuilder: (context, index) {
              final s = tisch.spieler[index];
              final punkte = punktestand[s.id] ?? 0;
              return ListTile(
                key: ValueKey(s.id),
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(s.name),
                trailing: Text(
                  '${punkte.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: punkte > 0
                        ? Colors.green
                        : punkte < 0
                            ? Colors.red
                            : null,
                  ),
                ),
              );
            },
          ),
          if (istAktiv)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Spieler hinzufügen'),
                    onPressed: () =>
                        _spielerHinzufuegenDialog(context, service),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text('Spiele bearbeiten'),
                    onPressed: () =>
                        _spieleBearbeitenDialog(context, service),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Runden (${tisch.runden.length})',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          Expanded(
            child: tisch.runden.isEmpty
                ? const Center(child: Text('Noch keine Runde erfasst'))
                : ListView.builder(
                    itemCount: tisch.runden.length,
                    itemBuilder: (context, index) {
                      final runde = tisch.runden[
                          tisch.runden.length - 1 - index]; // neueste zuerst
                      final spielerpartei = runde.spielerParteiIds
                          .map((id) =>
                              tisch.spieler.firstWhere((s) => s.id == id).name)
                          .join(' & ');
                      final details = [
                        if (runde.anzahlLaufende > 0)
                          '${runde.anzahlLaufende} Laufende',
                        if (runde.schneider) 'Schneider',
                        if (runde.multiplikator > 1)
                          '${runde.multiplikator}x',
                      ].join(' · ');
                      final titel = runde.unentschieden
                          ? runde.spielartName
                          : '${runde.spielartName}${spielerpartei.isEmpty ? '' : ' – $spielerpartei'}';
                      return ListTile(
                        leading: Icon(
                          runde.unentschieden
                              ? Icons.remove_circle_outline
                              : runde.gewonnen
                                  ? Icons.check_circle
                                  : Icons.cancel,
                          color: runde.unentschieden
                              ? Colors.grey
                              : runde.gewonnen
                                  ? Colors.green
                                  : Colors.red,
                        ),
                        title: Text(titel),
                        subtitle: Text(details.isEmpty
                            ? '${runde.spielwert.toStringAsFixed(2)} € je Verlierer'
                            : '$details · ${runde.spielwert.toStringAsFixed(2)} € je Verlierer'),
                        trailing: Text(
                          runde.unentschieden
                              ? 'unentschieden'
                              : runde.gewonnen
                                  ? 'gewonnen'
                                  : 'verloren',
                          style: TextStyle(
                            color: runde.unentschieden
                                ? Colors.grey
                                : runde.gewonnen
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Divider(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
      floatingActionButton: istAktiv
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Runde erfassen'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RundeErfassenScreen(tisch: tisch, service: service),
                ),
              ),
            )
          : null,
    );
  }

  void _beendenBestaetigen(BuildContext context, SpielService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text(
            'Der Tisch wird als beendet markiert. Es können danach keine weiteren Runden mehr erfasst werden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              service.tischBeenden(tisch);
              Navigator.of(ctx)
                ..pop()
                ..pop();
            },
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
  }

  void _spielerHinzufuegenDialog(BuildContext context, SpielService service) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Spieler hinzufügen'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: 20,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (controller.text.length >= 20)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Maximale Länge von 20 Zeichen erreicht',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: service.allePlayerinnen
                        .where((s) => !tisch.spieler.contains(s))
                        .map((s) => ActionChip(
                      label: Text(s.name),
                      onPressed: () {
                        service.spielerZuTischHinzufuegen(tisch, s);
                        Navigator.of(ctx).pop();
                      },
                    ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final s = service.spielerAnlegen(name);
                service.spielerZuTischHinzufuegen(tisch, s);
                Navigator.of(ctx).pop();
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _spieleBearbeitenDialog(BuildContext context, SpielService service) {
    // Arbeitskopie der Auswahl, damit erst beim Speichern übernommen wird.
    final ausgewaehlt = tisch.spielarten.map((s) => s.id).toSet();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Spiele für diesen Tisch'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (service.spielarten.isEmpty)
                    const Text('Noch keine Spielarten im Katalog')
                  else
                    ...service.spielarten.map((s) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: ausgewaehlt.contains(s.id),
                          title: Text(s.name),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                ausgewaehlt.add(s.id);
                              } else {
                                ausgewaehlt.remove(s.id);
                              }
                            });
                          },
                        )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: ausgewaehlt.isEmpty
                  ? null
                  : () {
                      final neueSpielarten = service.spielarten
                          .where((s) => ausgewaehlt.contains(s.id))
                          .toList();
                      service.spielartenFuerTischAendern(
                          tisch, neueSpielarten);
                      Navigator.of(ctx).pop();
                    },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDatum(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
