import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/spiel_service.dart';
import 'tisch_detail_screen.dart';

class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistik'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Spieler'),
            Tab(text: 'Beendete Spiele'),
          ]),
        ),
        body: const TabBarView(
          children: [
            _SpielerStatistikTab(),
            _BeendeteSpieleTab(),
          ],
        ),
      ),
    );
  }
}

class _SpielerStatistikTab extends StatelessWidget {
  const _SpielerStatistikTab();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final stats = service.statistikProSpieler.values.toList()
      ..sort((a, b) => b.gesamtPunkte.compareTo(a.gesamtPunkte));

    if (stats.isEmpty) {
      return const Center(child: Text('Noch keine Daten'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(s.spieler.name),
            subtitle: Text(
                '${s.anzahlTische} Tische · ${s.anzahlRunden} Runden · '
                '${(s.gewinnquote * 100).toStringAsFixed(0)}% Gewinnquote'),
            trailing: Text(
              '${s.gesamtPunkte > 0 ? '+' : ''}${s.gesamtPunkte.toStringAsFixed(2)} €',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: s.gesamtPunkte > 0
                    ? Colors.green
                    : s.gesamtPunkte < 0
                        ? Colors.red
                        : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeendeteSpieleTab extends StatelessWidget {
  const _BeendeteSpieleTab();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpielService>();
    final tische = service.beendeteTische;

    if (tische.isEmpty) {
      return const Center(child: Text('Noch keine beendeten Spiele'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tische.length,
      itemBuilder: (context, index) {
        final tisch = tische[index];
        return Card(
          child: ListTile(
            title: Text(tisch.spieler.map((s) => s.name).join(', ')),
            subtitle: Text(
                '${tisch.runden.length} Runden · beendet am '
                '${tisch.beendetAm?.day}.${tisch.beendetAm?.month}.${tisch.beendetAm?.year}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TischDetailScreen(tisch: tisch)),
            ),
          ),
        );
      },
    );
  }
}
