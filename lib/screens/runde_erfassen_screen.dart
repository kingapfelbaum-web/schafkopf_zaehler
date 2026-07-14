import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/spieler.dart';
import '../models/tisch.dart';
import '../models/runde.dart';
import '../models/spielart.dart';
import '../services/spiel_service.dart';

class RundeErfassenScreen extends StatefulWidget {
  final Tisch tisch;
  final SpielService service;

  const RundeErfassenScreen(
      {super.key, required this.tisch, required this.service});

  @override
  State<RundeErfassenScreen> createState() => _RundeErfassenScreenState();
}

class _RundeErfassenScreenState extends State<RundeErfassenScreen> {
  late Set<String> _aktiveSpielerIds;
  late Spielart _spielart;

  /// Bei klassischen Spielen: die Spielerpartei. Bei individuellen
  /// Gewinnern: die ausgewählten Gewinner (kann leer sein = unentschieden).
  final Set<String> _spielerParteiIds = {};

  int _anzahlLaufende = 0;
  bool _schneider = false;
  bool _gewonnen = true;
  int _multiplikator = 1;

  @override
  void initState() {
    super.initState();
    // Standardmäßig die ersten 4 Spieler der Tisch-Reihenfolge aktiv setzen.
    _aktiveSpielerIds =
        widget.tisch.spieler.take(4).map((s) => s.id).toSet();
    _spielart = widget.tisch.spielarten.first;
  }

  List<Spieler> get _aktiveSpieler => widget.tisch.spieler
      .where((s) => _aktiveSpielerIds.contains(s.id))
      .toList();

  bool get _individuell => _spielart.individuelleGewinner;

  /// Bei klassischen Spielen fest (1 oder 2), bei individuellen Gewinnern
  /// eine Obergrenze (0, 1 oder 2 sind erlaubt).
  int get _maxSpielerpartei =>
      _individuell ? 2 : _spielart.anzahlSpielerpartei;

  bool get _auswahlGueltig {
    if (_aktiveSpielerIds.length != 4) return false;
    if (_individuell) {
      // 0 (unentschieden), 1 oder 2 Gewinner sind erlaubt.
      return _spielerParteiIds.length <= 2 &&
          _spielerParteiIds.every(_aktiveSpielerIds.contains);
    }
    return _spielerParteiIds.length == _maxSpielerpartei &&
        _spielerParteiIds.every(_aktiveSpielerIds.contains);
  }

  bool get _unentschieden => _individuell && _spielerParteiIds.isEmpty;

  double get _vorschauSpielwert {
    final tarif = widget.tisch.tarif;
    final grundpreis = tarif.grundpreis(_spielart.einzelspieler);
    final zuschlag =
        tarif.aufpreis * _anzahlLaufende + (_schneider ? tarif.aufpreis : 0);
    return (grundpreis + zuschlag) * _multiplikator;
  }

  @override
  Widget build(BuildContext context) {
    final alleSpieler = widget.tisch.spieler;
    final brauchtAuswahl = alleSpieler.length > 4;
    final spielarten = widget.tisch.spielarten;

    if (spielarten.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Runde erfassen')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Für diesen Tisch sind keine Spielarten freigeschaltet. '
              'Bitte beim Erstellen eines neuen Tisches mindestens eine Spielart auswählen.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Runde erfassen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (brauchtAuswahl) ...[
            _abschnittsTitel(context, 'Wer spielt mit? (genau 4)'),
            ...alleSpieler.map((s) => CheckboxListTile(
                  value: _aktiveSpielerIds.contains(s.id),
                  title: Text(s.name),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        if (_aktiveSpielerIds.length < 4) {
                          _aktiveSpielerIds.add(s.id);
                        }
                      } else {
                        _aktiveSpielerIds.remove(s.id);
                        _spielerParteiIds.remove(s.id);
                      }
                    });
                  },
                )),
            const SizedBox(height: 8),
          ],
          _abschnittsTitel(context, 'Spielart'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: spielarten
                .map((s) => ChoiceChip(
                      label: Text(s.name),
                      selected: _spielart == s,
                      onSelected: (_) {
                        setState(() {
                          _spielart = s;
                          _spielerParteiIds.clear();
                        });
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _abschnittsTitel(
            context,
            _individuell
                ? 'Gewinner (${_spielerParteiIds.length}/2, 0 = unentschieden)'
                : 'Spielerpartei (${_spielerParteiIds.length}/$_maxSpielerpartei)',
          ),
          ..._aktiveSpieler.map((s) => CheckboxListTile(
                value: _spielerParteiIds.contains(s.id),
                title: Text(s.name),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      if (_spielerParteiIds.length < _maxSpielerpartei) {
                        _spielerParteiIds.add(s.id);
                      }
                    } else {
                      _spielerParteiIds.remove(s.id);
                    }
                  });
                },
              )),
          if (_individuell && _unentschieden)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Kein Gewinner ausgewählt → Runde gilt als unentschieden, es werden keine Punkte verteilt.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const Divider(height: 32),
          _abschnittsTitel(context, 'Details'),
          Row(
            children: [
              const Expanded(child: Text('Laufende')),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _anzahlLaufende > 0
                    ? () => setState(() => _anzahlLaufende--)
                    : null,
              ),
              Text('$_anzahlLaufende',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _anzahlLaufende < 8
                    ? () => setState(() => _anzahlLaufende++)
                    : null,
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Schneider'),
            value: _schneider,
            onChanged: (v) => setState(() => _schneider = v),
          ),
          if (!_individuell)
            SwitchListTile(
              title: const Text('Spielerpartei gewonnen'),
              value: _gewonnen,
              onChanged: (v) => setState(() => _gewonnen = v),
            ),
          Row(
            children: [
              const Expanded(
                  child: Text('Multiplikator (z.B. Kontra/Re, Tout)')),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _multiplikator > 1
                    ? () => setState(() => _multiplikator--)
                    : null,
              ),
              Text('${_multiplikator}x',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _multiplikator++),
              ),
            ],
          ),
          const Divider(height: 32),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_unentschieden
                      ? 'Unentschieden'
                      : 'Spielwert (je Verlierer)'),
                  Text(
                    _unentschieden
                        ? '0,00 €'
                        : '${_vorschauSpielwert.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _auswahlGueltig ? _speichern : null,
            child: const Text('Speichern'),
          ),
          Divider(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _abschnittsTitel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  void _speichern() {
    final gegenParteiIds = _aktiveSpielerIds
        .where((id) => !_spielerParteiIds.contains(id))
        .toList();

    final runde = Runde.berechnet(
      id: const Uuid().v4(),
      tarif: widget.tisch.tarif,
      spielart: _spielart,
      spielerParteiIds: _spielerParteiIds.toList(),
      gegenParteiIds: gegenParteiIds,
      anzahlLaufende: _anzahlLaufende,
      schneider: _schneider,
      gewonnen: _individuell ? true : _gewonnen,
      unentschieden: _unentschieden,
      multiplikator: _multiplikator,
    );

    widget.service.rundeHinzufuegen(widget.tisch, runde);
    Navigator.of(context).pop();
  }
}
