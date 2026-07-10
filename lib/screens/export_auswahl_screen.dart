import 'dart:io';

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
  final _tischSucheController = TextEditingController();
  final _spielerSucheController = TextEditingController();
  String _tischSuche = '';
  String _spielerSuche = '';

  Set<String>? _ausgewaehlteTischIds; // null = noch nicht initialisiert
  Set<String>? _ausgewaehlteSpielerIds;

  @override
  void dispose() {
    _tischSucheController.dispose();
    _spielerSucheController.dispose();
    super.dispose();
  }

  bool _tischPasstZurSuche(Tisch tisch) {
    if (_tischSuche.isEmpty) return true;
    final query = _tischSuche.toLowerCase();
    final spielerNamen = tisch.spieler.map((s) => s.name.toLowerCase()).join(' ');
    final datum =
        '${tisch.erstelltAm.day.toString().padLeft(2, '0')}.${tisch.erstelltAm.month.toString().padLeft(2, '0')}.${tisch.erstelltAm.year}';
    return spielerNamen.contains(query) || datum.contains(query);
  }

  Future<void> _exportieren(SpielService service) async {
    try {
      final jsonStr = service.datenExportierenGefiltert(
        tischIds: _ausgewaehlteTischIds!,
        spielerIds: _ausgewaehlteSpielerIds!,
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
    final allePlayerinnen = service.allePlayerinnen;

    // Beim ersten Aufbau standardmäßig alles auswählen (= vollständiger Export).
    _ausgewaehlteTischIds ??= alleTische.map((t) => t.id).toSet();
    _ausgewaehlteSpielerIds ??= allePlayerinnen.map((s) => s.id).toSet();

    final gefilterteTische = alleTische.where(_tischPasstZurSuche).toList();
    final gefiltertePlayerinnen = allePlayerinnen
        .where((s) => s.name.toLowerCase().contains(_spielerSuche.toLowerCase()))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Export auswählen'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Spiele'),
            Tab(text: 'Spieler'),
          ]),
        ),
        body: TabBarView(
          children: [
            // ---------- Spiele-Auswahl ----------
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tischSucheController,
                          decoration: InputDecoration(
                            hintText: 'Nach Spieler oder Datum suchen',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _tischSuche = v),
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
            // ---------- Spieler-Auswahl ----------
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _spielerSucheController,
                          decoration: InputDecoration(
                            hintText: 'Nach Namen suchen',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _spielerSuche = v),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _ausgewaehlteSpielerIds =
                              gefiltertePlayerinnen.map((s) => s.id).toSet();
                        }),
                        child: const Text('Alle'),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _ausgewaehlteSpielerIds!.removeWhere((id) =>
                              gefiltertePlayerinnen.any((s) => s.id == id));
                        }),
                        child: const Text('Keine'),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Spieler aus ausgewählten Spielen werden automatisch mit exportiert.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: gefiltertePlayerinnen.isEmpty
                      ? const Center(child: Text('Keine Treffer'))
                      : ListView.builder(
                    itemCount: gefiltertePlayerinnen.length,
                    itemBuilder: (context, index) {
                      final s = gefiltertePlayerinnen[index];
                      return CheckboxListTile(
                        value: _ausgewaehlteSpielerIds!.contains(s.id),
                        title: Text(s.name),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _ausgewaehlteSpielerIds!.add(s.id);
                            } else {
                              _ausgewaehlteSpielerIds!.remove(s.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
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
                    'Exportieren (${_ausgewaehlteTischIds!.length} Spiele, ${_ausgewaehlteSpielerIds!.length} Spieler)'),
                onPressed: (_ausgewaehlteTischIds!.isEmpty &&
                    _ausgewaehlteSpielerIds!.isEmpty)
                    ? null
                    : () => _exportieren(service),
              ),
            ),
          ),
        ),
      ),
    );
  }
}