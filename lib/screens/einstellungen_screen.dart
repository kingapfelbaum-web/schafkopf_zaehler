import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/tarif.dart';
import '../services/spiel_service.dart';
import 'spiele_bearbeiten_screen.dart';
import 'spieler_verwalten_screen.dart';

import 'export_auswahl_screen.dart';

class EinstellungenScreen extends StatefulWidget {
  const EinstellungenScreen({super.key});

  @override
  State<EinstellungenScreen> createState() => _EinstellungenScreenState();
}

class _EinstellungenScreenState extends State<EinstellungenScreen> {
  late TextEditingController _sauspielController;
  late TextEditingController _soloController;
  late TextEditingController _aufpreisController;
  late Set<String> _ausgewaehlteIds;

  @override
  void initState() {
    super.initState();
    final service = context.read<SpielService>();
    final tarif = service.standardTarif;
    _sauspielController =
        TextEditingController(text: tarif.sauspielPreis.toStringAsFixed(2));
    _soloController =
        TextEditingController(text: tarif.soloPreis.toStringAsFixed(2));
    _aufpreisController =
        TextEditingController(text: tarif.aufpreis.toStringAsFixed(2));
    _ausgewaehlteIds = Set.of(service.standardAusgewaehlteSpielartenIds);
  }

  @override
  void dispose() {
    _sauspielController.dispose();
    _soloController.dispose();
    _aufpreisController.dispose();
    super.dispose();
  }

  void _speichern() {
    final service = context.read<SpielService>();
    service.standardTarifAendern(Tarif(
      sauspielPreis:
          double.tryParse(_sauspielController.text.replaceAll(',', '.')) ??
              0.20,
      soloPreis:
          double.tryParse(_soloController.text.replaceAll(',', '.')) ?? 0.50,
      aufpreis:
          double.tryParse(_aufpreisController.text.replaceAll(',', '.')) ??
              0.20,
    ));
    service.standardAuswahlAendern(_ausgewaehlteIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard-Einstellungen gespeichert')),
      );
    }
  }

  Future<void> _importieren(SpielService service) async {
    final controller = TextEditingController();

    // Falls in der Zwischenablage bereits JSON liegt (z.B. weil der Nutzer
    // die exportierte Datei zuvor geöffnet und den Inhalt kopiert hat),
    // gleich vorbefüllen.
    final zwischenablage = await Clipboard.getData(Clipboard.kTextPlain);
    if (zwischenablage?.text != null &&
        zwischenablage!.text!.trim().startsWith('{')) {
      controller.text = zwischenablage.text!;
    }

    if (!mounted) return;
    final inhalt = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daten importieren'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Öffne die exportierte .json-Datei (z.B. über deine Dateien-App), '
                      'kopiere ihren gesamten Inhalt und füge ihn hier ein.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{ "allePlayerinnen": [...], ... }',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.paste),
                  label: const Text('Aus Zwischenablage einfügen'),
                  onPressed: () async {
                    final daten = await Clipboard.getData(Clipboard.kTextPlain);
                    if (daten?.text != null) {
                      controller.text = daten!.text!;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );

    if (inhalt == null || inhalt.trim().isEmpty) return;

    if (!mounted) return;
    // null = abgebrochen, true = hinzufügen, false = ersetzen
    final modus = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wie importieren?'),
        content: const Text(
            '"Hinzufügen" ergänzt die eingefügten Spiele und Spieler zu deinen bestehenden Daten. '
                '"Ersetzen" löscht vorher alle aktuellen Spieler, Tische und Einstellungen unwiderruflich.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ersetzen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (modus == null) return;

    try {
      if (modus) {
        final anzahl = await service.datenImportierenHinzufuegen(inhalt);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$anzahl Spiel(e) hinzugefügt')),
        );
      } else {
        await service.datenImportieren(inhalt);
        if (!mounted) return;
        // Eingabefelder mit den importierten Standardwerten aktualisieren.
        final tarif = service.standardTarif;
        setState(() {
          _sauspielController.text = tarif.sauspielPreis.toStringAsFixed(2);
          _soloController.text = tarif.soloPreis.toStringAsFixed(2);
          _aufpreisController.text = tarif.aufpreis.toStringAsFixed(2);
          _ausgewaehlteIds = Set.of(service.standardAusgewaehlteSpielartenIds);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daten erfolgreich ersetzt')),
        );
      }
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eingefügter Text ist kein gültiges Backup')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();

    return Scaffold(
      appBar: AppBar(
          title: const Text('Einstellungen'),
          actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _speichern,
            child: const Text('Speichern'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Standard-Tarif für neue Tische',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
              'Diese Werte werden beim Erstellen eines neuen Tisches vorausgefüllt.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sauspielController,
                  decoration: const InputDecoration(
                      labelText: 'Sauspiel (€)', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _soloController,
                  decoration: const InputDecoration(
                      labelText: 'Solo (€)', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aufpreisController,
            decoration: const InputDecoration(
                labelText: 'Aufpreis je Laufendem / Schneider (€)',
                border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Standardmäßig ausgewählte Spiele',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('Spiele bearbeiten'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SpieleBearbeitenScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Diese Spielarten sind beim Erstellen eines neuen Tisches vorausgewählt.',
              style: TextStyle(color: Colors.grey)),
          if (service.spielarten.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Noch keine Spielarten im Katalog'),
            )
          else
            ...service.spielarten.map((s) => CheckboxListTile(
                  value: _ausgewaehlteIds.contains(s.id),
                  title: Text(s.name),
                  subtitle:
                      Text(s.einzelspieler ? 'Solo' : 'Sauspiel'),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _ausgewaehlteIds.add(s.id);
                      } else {
                        _ausgewaehlteIds.remove(s.id);
                      }
                    });
                  },
                )),
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Spieler',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.group),
                label: const Text('Spieler verwalten'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SpielerVerwaltenScreen()),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          Text('Daten sichern', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
              'Sichere alle Spieler, Tische, Runden und Einstellungen als Datei oder stelle einen früheren Stand wieder her.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text('Exportieren'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExportAuswahlScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Importieren'),
                  onPressed: () => _importieren(service),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
