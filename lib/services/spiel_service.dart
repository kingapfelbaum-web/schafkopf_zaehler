import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/spieler.dart';
import '../models/tisch.dart';
import '../models/runde.dart';
import '../models/tarif.dart';
import '../models/spielart.dart';

class SpielService extends ChangeNotifier {
  final _uuid = const Uuid();

  /// Globaler Spieler-Pool, damit man beim Anlegen eines Tisches
  /// bereits bekannte Spieler wiederverwenden kann statt Namen neu zu tippen.
  final List<Spieler> _allePlayerinnen = [];
  final List<Tisch> _tische = [];

  /// Editierbarer Katalog aller verfügbaren Spielarten.
  final List<Spielart> _spielarten = standardSpielarten();

  /// Standard-Einstellungen für neue Tische.
  Tarif _standardTarif = Tarif();
  Set<String> _standardAusgewaehlteSpielartenIds =
      standardSpielarten().map((s) => s.id).toSet();

  List<Spieler> get allePlayerinnen => List.unmodifiable(_allePlayerinnen);
  List<Tisch> get aktiveTische =>
      _tische.where((t) => t.status == TischStatus.aktiv).toList();
  List<Tisch> get beendeteTische =>
      _tische.where((t) => t.status == TischStatus.beendet).toList();

  List<Spielart> get spielarten => List.unmodifiable(_spielarten);
  Tarif get standardTarif => _standardTarif;
  Set<String> get standardAusgewaehlteSpielartenIds =>
      Set.unmodifiable(_standardAusgewaehlteSpielartenIds);

  // ---------- Spieler ----------

  Spieler spielerAnlegen(String name) {
    final vorhandener = _allePlayerinnen.firstWhere(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
      orElse: () => Spieler(id: _uuid.v4(), name: name),
    );
    if (!_allePlayerinnen.contains(vorhandener)) {
      _allePlayerinnen.add(vorhandener);
      notifyListeners();
    }
    return vorhandener;
  }

  // ---------- Spielarten-Katalog ----------

  Spielart spielartHinzufuegen(String name, bool einzelspieler,
      {bool individuelleGewinner = false}) {
    final s = Spielart(
      id: _uuid.v4(),
      name: name,
      einzelspieler: einzelspieler,
      individuelleGewinner: individuelleGewinner,
    );
    _spielarten.add(s);
    _standardAusgewaehlteSpielartenIds.add(s.id);
    notifyListeners();
    return s;
  }

  void spielartAktualisieren(
      Spielart spielart, String name, bool einzelspieler,
      {bool individuelleGewinner = false}) {
    spielart.name = name;
    spielart.einzelspieler = einzelspieler;
    spielart.individuelleGewinner = individuelleGewinner;
    notifyListeners();
  }

  void spielartLoeschen(Spielart spielart) {
    _spielarten.remove(spielart);
    _standardAusgewaehlteSpielartenIds.remove(spielart.id);
    notifyListeners();
  }

  // ---------- Standard-Einstellungen ----------

  void standardTarifAendern(Tarif tarif) {
    _standardTarif = tarif;
    notifyListeners();
  }

  void standardAuswahlAendern(Set<String> spielartenIds) {
    _standardAusgewaehlteSpielartenIds = spielartenIds;
    notifyListeners();
  }

  // ---------- Tische ----------

  Tisch tischAnlegen(
    List<Spieler> spielerInReihenfolge, {
    Tarif? tarif,
    List<Spielart>? spielarten,
  }) {
    assert(spielerInReihenfolge.length >= 4,
        'Ein Tisch braucht mindestens vier Spieler');
    final tisch = Tisch(
      id: _uuid.v4(),
      erstelltAm: DateTime.now(),
      spieler: List.of(spielerInReihenfolge),
      tarif: tarif,
      spielarten: spielarten,
    );
    _tische.add(tisch);
    notifyListeners();
    return tisch;
  }

  void spielerZuTischHinzufuegen(Tisch tisch, Spieler spieler) {
    tisch.spielerHinzufuegen(spieler);
    notifyListeners();
  }

  void spielerReihenfolgeAendern(Tisch tisch, int oldIndex, int newIndex) {
    tisch.spielerVerschieben(oldIndex, newIndex);
    notifyListeners();
  }

  void tarifAendern(Tisch tisch, Tarif tarif) {
    tisch.tarif = tarif;
    notifyListeners();
  }

  void rundeHinzufuegen(Tisch tisch, Runde runde) {
    tisch.runden.add(runde);
    notifyListeners();
  }

  void tischBeenden(Tisch tisch) {
    tisch.beenden();
    notifyListeners();
  }

  // ---------- Statistik ----------

  /// Aggregierte Statistik über alle (auch aktive) Tische, pro Spieler.
  Map<Spieler, SpielerStatistik> get statistikProSpieler {
    final Map<String, SpielerStatistik> stats = {};

    for (final tisch in _tische) {
      for (final spieler in tisch.spieler) {
        stats.putIfAbsent(
          spieler.id,
          () => SpielerStatistik(spieler: spieler),
        );
      }
      for (final runde in tisch.runden) {
        runde.punkteProSpieler.forEach((spielerId, punkte) {
          final spieler = tisch.spieler.firstWhere((s) => s.id == spielerId);
          final s = stats.putIfAbsent(
            spielerId,
            () => SpielerStatistik(spieler: spieler),
          );
          s.gesamtPunkte += punkte;
          s.anzahlRunden += 1;
          if (punkte > 0) s.gewonneneRunden += 1;
        });
      }
    }

    for (final tisch in _tische) {
      for (final spieler in tisch.spieler) {
        stats[spieler.id]?.anzahlTische += 1;
      }
    }

    return {for (final s in stats.values) s.spieler: s};
  }
}

class SpielerStatistik {
  final Spieler spieler;
  double gesamtPunkte = 0;
  int anzahlRunden = 0;
  int gewonneneRunden = 0;
  int anzahlTische = 0;

  SpielerStatistik({required this.spieler});

  double get gewinnquote =>
      anzahlRunden == 0 ? 0 : gewonneneRunden / anzahlRunden;
}
