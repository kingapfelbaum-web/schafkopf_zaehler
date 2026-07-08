import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tarif.dart';
import '../services/spiel_service.dart';
import 'spiele_bearbeiten_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Standardmäßig ausgewählte Spiele',
                  style: Theme.of(context).textTheme.titleMedium),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _speichern,
              child: const Text('Speichern'),
            ),
          ),
        ],
      ),
    );
  }
}
