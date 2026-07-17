import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/tisch.dart';
import '../services/spiel_service.dart';

class ExportAuswahlScreen extends StatefulWidget {
  const ExportAuswahlScreen({super.key});

  @override
  State<ExportAuswahlScreen> createState() => _ExportAuswahlScreenState();
}

class _ExportAuswahlScreenState extends State<ExportAuswahlScreen> {
  final _sucheController = TextEditingController();
  String _suche = '';

  Set<String>? _ausgewaehlteTischIds; // null = noch nicht initialisiert

  @override
  void dispose() {
    _sucheController.dispose();
    super.dispose();
  }

  bool _tischPasstZurSuche(Tisch tisch) {
    if (_suche.isEmpty) return true;
    final query = _suche.toLowerCase();
    final spielerNamen = tisch.spieler.map((s) => s.name.toLowerCase()).join(' ');
    final datum =
        '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year}';
    return spielerNamen.contains(query) || datum.contains(query);
  }

  Future<void> _exportieren(SpielService service) async {
    try {
      final jsonStr = service.datenExportierenGefiltert(
        tischIds: _ausgewaehlteTischIds!,
      );
      final zeitstempel =
      DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
      await Share.share(
        jsonStr,
        subject: 'schafkopf_export_$zeitstempel.json',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final alleTische = service.alleTische;

    // Beim ersten Aufbau standardmäßig alles auswählen (= vollständiger Export).
    _ausgewaehlteTischIds ??= alleTische.map((t) => t.id).toSet();

    final gefilterteTische = alleTische.where(_tischPasstZurSuche).toList();

    // Vorschau, wie viele Spieler durch die aktuelle Auswahl mit exportiert würden.
    final betroffenePlayerinnen = <String>{
      for (final t in alleTische.where((t) => _ausgewaehlteTischIds!.contains(t.id)))
        ...t.spieler.map((s) => s.id),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Export auswählen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sucheController,
                    decoration: InputDecoration(
                      hintText: 'Nach Spieler oder Datum suchen',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _suche = v),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _ausgewaehlteTischIds =
                        gefilterteTische.map((t) => t.id).toSet();
                  }),
                  child: const Text('Alle'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _ausgewaehlteTischIds!.removeWhere(
                            (id) => gefilterteTische.any((t) => t.id == id));
                  }),
                  child: const Text('Keine'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Spieler, die an den ausgewählten Spielen teilgenommen haben, werden automatisch mit exportiert.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: gefilterteTische.isEmpty
                ? const Center(child: Text('Keine Treffer'))
                : ListView.builder(
              itemCount: gefilterteTische.length,
              itemBuilder: (context, index) {
                final tisch = gefilterteTische[index];
                final istAktiv = tisch.status == TischStatus.aktiv;
                return CheckboxListTile(
                  value: _ausgewaehlteTischIds!.contains(tisch.id),
                  title: Text(tisch.spieler.map((s) => s.name).join(', ')),
                  subtitle: Text(
                    '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year} · '
                        '${tisch.runden.length} Runden · ${istAktiv ? 'aktiv' : 'beendet'}',
                  ),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _ausgewaehlteTischIds!.add(tisch.id);
                      } else {
                        _ausgewaehlteTischIds!.remove(tisch.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.upload),
              label: Text(
                  'Exportieren (${_ausgewaehlteTischIds!.length} Spiele, ${betroffenePlayerinnen.length} Spieler)'),
              onPressed: _ausgewaehlteTischIds!.isEmpty
                  ? null
                  : () => _exportieren(service),
            ),
          ),
        ),
      ),
    );
  }
}