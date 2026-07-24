class Player {
  final String id;
  final String name;
  final String color;

  const Player({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color,
  };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
    id: map['id'] as String,
    name: map['name'] as String,
    color: map['color'] as String,
  );

  Player copyWith({String? name, String? color}) => Player(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
  );
}

const defaultPlayers = [
  Player(id: 'p1', name: '吕布', color: '#E53935'),
  Player(id: 'p2', name: '赵云', color: '#1E88E5'),
  Player(id: 'p3', name: '司马懿', color: '#8E24AA'),
  Player(id: 'p4', name: '周瑜', color: '#43A047'),
  Player(id: 'p5', name: '张飞', color: '#FB8C00'),
];
