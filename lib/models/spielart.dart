/// Eine konfigurierbare Spielart (z.B. "Sauspiel", "Wenz", "Ramsch", ...).
/// Der Katalog ist vom Nutzer editierbar (siehe SpieleBearbeitenScreen).
class Spielart {
  final String id;
  String name;

  /// true  = Grundpreis wird über den Solo-Tarif berechnet
  /// false = Grundpreis wird über den Sauspiel-Tarif berechnet
  bool einzelspieler;

  /// true  = Spezialspiel (z.B. Ramsch): die Gewinner werden bei jeder
  ///         Runde individuell ausgewählt (0, 1 oder 2 Spieler) statt
  ///         einer festen Partei-Größe. 0 Gewinner = Unentschieden.
  /// false = klassisches Spiel mit fester Spielerpartei
  ///         (1 Spieler bei Solo-Tarif, 2 Spieler bei Sauspiel-Tarif)
  ///         und einem Gewonnen/Verloren-Ergebnis.
  bool individuelleGewinner;

  Spielart({
    required this.id,
    required this.name,
    required this.einzelspieler,
    this.individuelleGewinner = false,
  });

  int get anzahlSpielerpartei => einzelspieler ? 1 : 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'einzelspieler': einzelspieler,
        'individuelleGewinner': individuelleGewinner,
      };

  factory Spielart.fromJson(Map<String, dynamic> json) => Spielart(
        id: json['id'] as String,
        name: json['name'] as String,
        einzelspieler: json['einzelspieler'] as bool,
        individuelleGewinner: json['individuelleGewinner'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is Spielart && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Der Standard-Katalog, mit dem die App startet.
List<Spielart> standardSpielarten() => [
      Spielart(id: 'sauspiel', name: 'Sauspiel', einzelspieler: false),
      Spielart(id: 'wenz', name: 'Wenz', einzelspieler: true),
      Spielart(id: 'geier', name: 'Geier', einzelspieler: true),
      Spielart(id: 'solo', name: 'Solo', einzelspieler: true),
      Spielart(
        id: 'ramsch',
        name: 'Ramsch',
        einzelspieler: false,
        individuelleGewinner: true,
      ),
    ];
