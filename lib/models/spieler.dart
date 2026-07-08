class Spieler {
  final String id;
  String name;

  Spieler({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Spieler.fromJson(Map<String, dynamic> json) =>
      Spieler(id: json['id'] as String, name: json['name'] as String);

  @override
  bool operator ==(Object other) => other is Spieler && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
