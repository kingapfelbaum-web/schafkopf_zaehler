import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/spieler.dart';
import '../models/tisch.dart';
import '../models/runde.dart';
import '../models/tarif.dart';
import '../models/spielart.dart';

class SpielService extends ChangeNotifier {
  final _uuid = const Uuid();
  static const _storageKey = 'schafkopf_daten_v1';

  /// Globaler Spieler-Pool, damit man beim Anlegen eines Tisches
  /// bereits bekannte Spieler wiederverwenden kann statt Namen neu zu tippen.
  final List<Spieler> _allePlayerinnen = [];
  final List<Tisch> _tische = [];

  /// Editierbarer Katalog aller verfügbaren Spielarten.
  List<Spielart> _spielarten = standardSpielarten();

  /// Standard-Einstellungen für neue Tische.
  Tarif _standardTarif = Tarif();
  Set<String> _standardAusgewaehlteSpielartenIds =
      standardSpielarten().map((s) => s.id).toSet();

  bool _geladen = false;
  bool _speichernAktiv = false;

  List<Spieler> get allePlayerinnen => List.unmodifiable(_allePlayerinnen);
  List<Tisch> get aktiveTische =>
      _tische.where((t) => t.status == TischStatus.aktiv).toList();
  List<Tisch> get beendeteTische =>
      _tische.where((t) => t.status == TischStatus.beendet).toList();

  /// Alle Tische, unabhängig vom Status (z.B. für Spieler-Detailstatistiken).
  List<Tisch> get alleTische => List.unmodifiable(_tische);

  List<Spielart> get spielarten => List.unmodifiable(_spielarten);
  Tarif get standardTarif => _standardTarif;
  Set<String> get standardAusgewaehlteSpielartenIds =>
      Set.unmodifiable(_standardAusgewaehlteSpielartenIds);

  /// Jede Zustandsänderung (überall im Service via notifyListeners genutzt)
  /// löst automatisch ein Speichern auf dem Gerät aus.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _speichern();
  }

  // ---------- Persistenz & Export/Import (gemeinsame JSON-Basis) ----------

  Map<String, dynamic> _zustandAlsJson() => {
        'allePlayerinnen': _allePlayerinnen.map((p) => p.toJson()).toList(),
        'spielarten': _spielarten.map((s) => s.toJson()).toList(),
        'standardTarif': _standardTarif.toJson(),
        'standardAusgewaehlteSpielartenIds':
            _standardAusgewaehlteSpielartenIds.toList(),
        'tische': _tische.map((t) => t.toJson()).toList(),
      };

  void _zustandAusJson(Map<String, dynamic> json) {
    final geladenePlayerinnen = <Spieler>[];
    for (final p in (json['allePlayerinnen'] as List? ?? [])) {
      try {
        geladenePlayerinnen.add(Spieler.fromJson(p as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Spieler konnte nicht geladen werden: $e');
      }
    }
    _allePlayerinnen
      ..clear()
      ..addAll(geladenePlayerinnen);

    final geladeneSpielarten = <Spielart>[];
    for (final s in (json['spielarten'] as List? ?? [])) {
      try {
        geladeneSpielarten.add(Spielart.fromJson(s as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Spielart konnte nicht geladen werden: $e');
      }
    }
    _spielarten = geladeneSpielarten.isEmpty ? standardSpielarten() : geladeneSpielarten;

    try {
      _standardTarif =
          Tarif.fromJson(json['standardTarif'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Standard-Tarif konnte nicht geladen werden: $e');
      _standardTarif = Tarif();
    }

    try {
      _standardAusgewaehlteSpielartenIds =
      Set<String>.from(json['standardAusgewaehlteSpielartenIds'] as List? ?? []);
    } catch (e) {
      debugPrint('Standard-Auswahl konnte nicht geladen werden: $e');
      _standardAusgewaehlteSpielartenIds = _spielarten.map((s) => s.id).toSet();
    }

    final geladeneTische = <Tisch>[];
    for (final t in (json['tische'] as List? ?? [])) {
      try {
        geladeneTische.add(Tisch.fromJson(
          t as Map<String, dynamic>,
          allePlayerinnen: _allePlayerinnen,
          alleSpielarten: _spielarten,
        ));
      } catch (e) {
        debugPrint('Tisch konnte nicht geladen werden: $e');
      }
    }
    _tische
      ..clear()
      ..addAll(geladeneTische);
  }

  /// Lädt gespeicherte Daten vom Gerät. Muss einmalig beim App-Start
  /// aufgerufen werden (siehe main.dart), bevor die UI aufgebaut wird.
  Future<void> ladeDaten() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) {
        _geladen = true;
        return;
      }
      _zustandAusJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Fehler beim Laden der gespeicherten Daten: $e');
    } finally {
      _geladen = true;
    }
  }

  Future<void> _speichern() async {
    // Vor dem ersten ladeDaten() nicht speichern, sonst würde ein evtl.
    // vorhandener gespeicherter Stand versehentlich überschrieben.
    if (!_geladen || _speichernAktiv) return;
    _speichernAktiv = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_zustandAlsJson()));
    } catch (e) {
      debugPrint('Fehler beim Speichern der Daten: $e');
    } finally {
      _speichernAktiv = false;
    }
  }

  /// Liefert den gesamten App-Zustand als JSON-String (für den Datenexport).
  String datenExportieren() =>
      const JsonEncoder.withIndent('  ').convert(_zustandAlsJson());

  /// Ersetzt den kompletten App-Zustand durch die übergebenen JSON-Daten
  /// (z.B. aus einer zuvor exportierten Datei). Wirft bei ungültigen Daten.
  Future<void> datenImportieren(String jsonStr) async {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    _zustandAusJson(json);
    notifyListeners();
  }

  /// Fügt die Daten aus einem Export zum bestehenden Zustand hinzu, statt
  /// ihn zu ersetzen. Spieler werden anhand ihres Namens abgeglichen
  /// (Duplikate zusammengeführt, damit importierte Tische auf bestehende
  /// Spieler zeigen), Spielarten anhand ihres Namens, Tische werden immer
  /// als neue Einträge hinzugefügt (auch wenn inhaltlich identisch), damit
  /// nichts unbeabsichtigt verloren geht.
  Future<int> datenImportierenHinzufuegen(String jsonStr) async {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    // 1) Spieler zusammenführen: Name → vorhandene oder neue ID.
    final idUmschreibungSpieler = <String, String>{};
    for (final p in (json['allePlayerinnen'] as List? ?? [])) {
      try {
        final importiert = Spieler.fromJson(p as Map<String, dynamic>);
        final vorhandener = _allePlayerinnen.firstWhere(
              (s) => s.name.toLowerCase() == importiert.name.toLowerCase(),
          orElse: () => importiert,
        );
        if (!_allePlayerinnen.contains(vorhandener)) {
          _allePlayerinnen.add(vorhandener);
        }
        idUmschreibungSpieler[importiert.id] = vorhandener.id;
      } catch (e) {
        debugPrint('Spieler beim Zusammenführen übersprungen: $e');
      }
    }

    // 2) Spielarten zusammenführen: Name → vorhandene oder neue ID.
    final idUmschreibungSpielart = <String, String>{};
    for (final s in (json['spielarten'] as List? ?? [])) {
      try {
        final importiert = Spielart.fromJson(s as Map<String, dynamic>);
        final vorhandene = _spielarten.firstWhere(
              (sa) => sa.name.toLowerCase() == importiert.name.toLowerCase(),
          orElse: () => importiert,
        );
        if (!_spielarten.contains(vorhandene)) {
          _spielarten.add(vorhandene);
        }
        idUmschreibungSpielart[importiert.id] = vorhandene.id;
      } catch (e) {
        debugPrint('Spielart beim Zusammenführen übersprungen: $e');
      }
    }

    // 3) Tische mit umgeschriebenen IDs neu hinzufügen (nie überschreiben,
    // damit auch inhaltlich gleiche/ähnliche Tische nicht verloren gehen).
    var importierteTische = 0;
    for (final t in (json['tische'] as List? ?? [])) {
      try {
        final tischJson = Map<String, dynamic>.from(t as Map<String, dynamic>);

        tischJson['id'] = _uuid.v4(); // neue eindeutige ID vergeben

        final urspruenglicheSpielerIds =
        List<String>.from(tischJson['spielerIds'] as List? ?? []);
        tischJson['spielerIds'] = urspruenglicheSpielerIds
            .map((id) => idUmschreibungSpieler[id] ?? id)
            .toList();

        final urspruenglicheSpielartenIds =
        List<String>.from(tischJson['spielartenIds'] as List? ?? []);
        tischJson['spielartenIds'] = urspruenglicheSpielartenIds
            .map((id) => idUmschreibungSpielart[id] ?? id)
            .toList();

        final tisch = Tisch.fromJson(
          tischJson,
          allePlayerinnen: _allePlayerinnen,
          alleSpielarten: _spielarten,
        );
        _tische.add(tisch);
        importierteTische += 1;
      } catch (e) {
        debugPrint('Tisch beim Import übersprungen: $e');
      }
    }

    notifyListeners();
    return importierteTische;
  }

  /// Wie `datenExportieren()`, aber nur mit den ausgewählten Tischen und
  /// Spielern. Spieler, die an einem ausgewählten Tisch teilnehmen, werden
  /// automatisch mit exportiert (sonst wären die Tisch-Daten beim Import
  /// nicht auflösbar) – auch wenn sie nicht explizit ausgewählt wurden.
  String datenExportierenGefiltert({
    required Set<String> tischIds,
    required Set<String> spielerIds,
  }) {
    final ausgewaehlteTische =
    _tische.where((t) => tischIds.contains(t.id)).toList();

    final spielerIdsGesamt = <String>{
      ...spielerIds,
      for (final t in ausgewaehlteTische) ...t.spieler.map((s) => s.id),
    };
    final ausgewaehltePlayerinnen =
    _allePlayerinnen.where((s) => spielerIdsGesamt.contains(s.id)).toList();

    final json = {
      'allePlayerinnen': ausgewaehltePlayerinnen.map((p) => p.toJson()).toList(),
      'spielarten': _spielarten.map((s) => s.toJson()).toList(),
      'standardTarif': _standardTarif.toJson(),
      'standardAusgewaehlteSpielartenIds':
      _standardAusgewaehlteSpielartenIds.toList(),
      'tische': ausgewaehlteTische.map((t) => t.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  // ---------- Spieler ----------

  Spieler spielerAnlegen(String name) {
    final bereinigt = name.trim();
    final begrenzt =
    bereinigt.length > 20 ? bereinigt.substring(0, 20) : bereinigt;
    final vorhandener = _allePlayerinnen.firstWhere(
          (s) => s.name.toLowerCase() == begrenzt.toLowerCase(),
      orElse: () => Spieler(id: _uuid.v4(), name: begrenzt),
    );
    if (!_allePlayerinnen.contains(vorhandener)) {
      _allePlayerinnen.add(vorhandener);
      notifyListeners();
    }
    return vorhandener;
  }

  bool spielerKannGeloeschtWerden(Spieler spieler) => !_tische.any(
          (t) => t.status == TischStatus.aktiv && t.spieler.contains(spieler));

  void spielerLoeschen(Spieler spieler) {
    if (!spielerKannGeloeschtWerden(spieler)) return;
    _allePlayerinnen.remove(spieler);
    notifyListeners();
  }

  // ---------- Spielarten-Katalog ----------

  Spielart spielartHinzufuegen(
      String name,
      bool einzelspieler, {
        bool individuelleGewinner = false,
        int individuelleAnzahl = 0,
        bool eigeneBetraege = false,
        double siegBetrag = 0,
        double verlustBetrag = 0,
      }) {
    final s = Spielart(
      id: _uuid.v4(),
      name: name,
      einzelspieler: einzelspieler,
      individuelleGewinner: individuelleGewinner,
      individuelleAnzahl: individuelleAnzahl,
      eigeneBetraege: eigeneBetraege,
      siegBetrag: siegBetrag,
      verlustBetrag: verlustBetrag,
    );
    _spielarten.add(s);
    _standardAusgewaehlteSpielartenIds.add(s.id);
    notifyListeners();
    return s;
  }

  void spielartAktualisieren(
      Spielart spielart,
      String name,
      bool einzelspieler, {
        bool individuelleGewinner = false,
        int individuelleAnzahl = 0,
        bool eigeneBetraege = false,
        double siegBetrag = 0,
        double verlustBetrag = 0,
      }) {
    spielart.name = name;
    spielart.einzelspieler = einzelspieler;
    spielart.individuelleGewinner = individuelleGewinner;
    spielart.individuelleAnzahl = individuelleAnzahl;
    spielart.eigeneBetraege = eigeneBetraege;
    spielart.siegBetrag = siegBetrag;
    spielart.verlustBetrag = verlustBetrag;
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

  bool spielerVonTischEntfernen(Tisch tisch, Spieler spieler) {
    final entfernt = tisch.spielerEntfernen(spieler);
    if (entfernt) notifyListeners();
    return entfernt;
  }

  void spielerReihenfolgeAendern(Tisch tisch, int oldIndex, int newIndex) {
    tisch.spielerVerschieben(oldIndex, newIndex);
    notifyListeners();
  }

  void tarifAendern(Tisch tisch, Tarif tarif) {
    tisch.tarif = tarif;
    notifyListeners();
  }

  /// Ändert die für diesen Tisch freigeschalteten Spielarten nachträglich
  /// (z.B. wenn nach dem Erstellen noch eine Spielart ergänzt werden soll).
  void spielartenFuerTischAendern(Tisch tisch, List<Spielart> neueSpielarten) {
    tisch.spielarten
      ..clear()
      ..addAll(neueSpielarten);
    notifyListeners();
  }

  void rundeHinzufuegen(Tisch tisch, Runde runde) {
    tisch.runden.add(runde);
    notifyListeners();
  }

  void rundeAktualisieren(Tisch tisch, Runde alteRunde, Runde neueRunde) {
    final index = tisch.runden.indexWhere((r) => r.id == alteRunde.id);
    if (index == -1) return;
    tisch.runden[index] = neueRunde;
    notifyListeners();
  }

  void rundeLoeschen(Tisch tisch, Runde runde) {
    tisch.runden.removeWhere((r) => r.id == runde.id);
    notifyListeners();
  }

  void tischBeenden(Tisch tisch) {
    tisch.beenden();
    notifyListeners();
  }

  void tischLoeschen(Tisch tisch) {
    if (tisch.status != TischStatus.beendet) return;
    _tische.remove(tisch);
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

  List<SpielartStatistik> get statistikProSpielart {
    final Map<String, SpielartStatistik> stats = {};

    for (final tisch in _tische) {
      for (final runde in tisch.runden) {
        final s = stats.putIfAbsent(
          runde.spielartName,
              () => SpielartStatistik(name: runde.spielartName),
        );
        s.anzahlRunden += 1;
        if (!runde.unentschieden && runde.gewonnen) {
          s.gewonneneRunden += 1;
        }
      }
    }

    final liste = stats.values.toList()
      ..sort((a, b) => b.anzahlRunden.compareTo(a.anzahlRunden));
    return liste;
  }

  /// Detaillierte Statistik für einen einzelnen Spieler, u.a. aufgeschlüsselt
  /// nach Spielart, sowie die Liste aller Tische, an denen er teilnahm.
  SpielerDetailStatistik detailStatistikFuer(Spieler spieler) {
    final proSpielart = <String, SpielartStatistik>{};
    double gesamtPunkte = 0;
    int anzahlRunden = 0;
    int gewonneneRunden = 0;
    int unentschiedenRunden = 0;
    final tischeDesSpielers = <Tisch>[];

    for (final tisch in _tische) {
      if (!tisch.spieler.contains(spieler)) continue;
      tischeDesSpielers.add(tisch);

      for (final runde in tisch.runden) {
        final punkte = runde.punkteProSpieler[spieler.id];
        if (punkte == null) continue; // Spieler hat in dieser Runde ausgesetzt

        gesamtPunkte += punkte;
        anzahlRunden += 1;
        if (runde.unentschieden) {
          unentschiedenRunden += 1;
        } else if (punkte > 0) {
          gewonneneRunden += 1;
        }

        final sa = proSpielart.putIfAbsent(
          runde.spielartName,
          () => SpielartStatistik(name: runde.spielartName),
        );
        sa.anzahlRunden += 1;
        sa.gesamtPunkte += punkte;
        if (!runde.unentschieden && punkte > 0) sa.gewonneneRunden += 1;
      }
    }

    tischeDesSpielers.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));

    return SpielerDetailStatistik(
      spieler: spieler,
      gesamtPunkte: gesamtPunkte,
      anzahlRunden: anzahlRunden,
      gewonneneRunden: gewonneneRunden,
      unentschiedenRunden: unentschiedenRunden,
      anzahlTische: tischeDesSpielers.length,
      proSpielart: proSpielart.values.toList()
        ..sort((a, b) => b.anzahlRunden.compareTo(a.anzahlRunden)),
      tische: tischeDesSpielers,
    );
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

/// Feingranulare Statistik einer einzelnen Spielart für einen Spieler.
class SpielartStatistik {
  final String name;
  int anzahlRunden = 0;
  int gewonneneRunden = 0;
  double gesamtPunkte = 0;

  SpielartStatistik({required this.name});

  double get gewinnquote =>
      anzahlRunden == 0 ? 0 : gewonneneRunden / anzahlRunden;
}

/// Detaillierte Statistik für einen einzelnen Spieler (siehe SpielerDetailScreen).
class SpielerDetailStatistik {
  final Spieler spieler;
  final double gesamtPunkte;
  final int anzahlRunden;
  final int gewonneneRunden;
  final int unentschiedenRunden;
  final int anzahlTische;
  final List<SpielartStatistik> proSpielart;
  final List<Tisch> tische;

  SpielerDetailStatistik({
    required this.spieler,
    required this.gesamtPunkte,
    required this.anzahlRunden,
    required this.gewonneneRunden,
    required this.unentschiedenRunden,
    required this.anzahlTische,
    required this.proSpielart,
    required this.tische,
  });

  double get gewinnquote =>
      anzahlRunden == 0 ? 0 : gewonneneRunden / anzahlRunden;
}
