import 'spieler.dart';
import 'runde.dart';
import 'tarif.dart';
import 'spielart.dart';

enum TischStatus { aktiv, beendet }

class Tisch {
  final String id;
  final DateTime erstelltAm;
  DateTime? beendetAm;
  TischStatus status;
  Tarif tarif;

  /// Die für diesen Tisch freigeschalteten Spielarten (Auswahl bei Erstellung).
  final List<Spielart> spielarten;

  /// Reihenfolge ist bewusst eine Liste (nicht Set) -> Sitzordnung bleibt erhalten.
  final List<Spieler> spieler;
  final List<Runde> runden;

  Tisch({
    required this.id,
    required this.erstelltAm,
    required this.spieler,
    Tarif? tarif,
    List<Spielart>? spielarten,
    List<Runde>? runden,
    this.status = TischStatus.aktiv,
    this.beendetAm,
  })  : runden = runden ?? [],
        tarif = tarif ?? Tarif(),
        spielarten = spielarten ?? standardSpielarten();

  /// Aktueller Punktestand (in €) je Spieler-ID, summiert über alle Runden.
  Map<String, double> get punktestand {
    final result = <String, double>{for (final s in spieler) s.id: 0};
    for (final runde in runden) {
      runde.punkteProSpieler.forEach((spielerId, punkte) {
        result[spielerId] = (result[spielerId] ?? 0) + punkte;
      });
    }
    return result;
  }

  void spielerHinzufuegen(Spieler neuer) {
    if (!spieler.contains(neuer)) {
      spieler.add(neuer);
    }
  }

  void spielerVerschieben(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final s = spieler.removeAt(oldIndex);
    spieler.insert(newIndex, s);
  }

  void beenden() {
    status = TischStatus.beendet;
    beendetAm = DateTime.now();
  }
}
