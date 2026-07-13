/// Der Tarif eines Tisches: Grundpreise + Aufpreis für Laufende/Schneider.
class Tarif {
  double sauspielPreis;
  double soloPreis;
  double aufpreis;

  Tarif({
    this.sauspielPreis = 0.20,
    this.soloPreis = 0.50,
    this.aufpreis = 0.10,
  });

  /// Grundpreis abhängig davon, ob die Spielart ein Einzelspieler-Spiel
  /// (Solo-Tarif) oder ein Partner-Spiel (Sauspiel-Tarif) ist.
  double grundpreis(bool einzelspieler) =>
      einzelspieler ? soloPreis : sauspielPreis;

  Tarif kopie() => Tarif(
        sauspielPreis: sauspielPreis,
        soloPreis: soloPreis,
        aufpreis: aufpreis,
      );

  Map<String, dynamic> toJson() => {
        'sauspielPreis': sauspielPreis,
        'soloPreis': soloPreis,
        'aufpreis': aufpreis,
      };

  factory Tarif.fromJson(Map<String, dynamic> json) => Tarif(
        sauspielPreis: (json['sauspielPreis'] as num).toDouble(),
        soloPreis: (json['soloPreis'] as num).toDouble(),
        aufpreis: (json['aufpreis'] as num).toDouble(),
      );
}
