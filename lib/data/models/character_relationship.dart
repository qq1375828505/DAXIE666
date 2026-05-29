import 'dart:ui';

/// 角色关系模型
class CharacterRelationship {
  final String id;
  final String fromCharacterId;
  final String toCharacterId;
  final String relationType; // e.g. "父女", "师徒", "敌人", "恋人", "同门"
  final String? description;

  const CharacterRelationship({
    required this.id,
    required this.fromCharacterId,
    required this.toCharacterId,
    required this.relationType,
    this.description,
  });

  CharacterRelationship copyWith({
    String? id,
    String? fromCharacterId,
    String? toCharacterId,
    String? relationType,
    String? description,
  }) => CharacterRelationship(
    id: id ?? this.id,
    fromCharacterId: fromCharacterId ?? this.fromCharacterId,
    toCharacterId: toCharacterId ?? this.toCharacterId,
    relationType: relationType ?? this.relationType,
    description: description ?? this.description,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromCharacterId': fromCharacterId,
    'toCharacterId': toCharacterId,
    'relationType': relationType,
    'description': description,
  };

  factory CharacterRelationship.fromJson(Map<String, dynamic> json) =>
      CharacterRelationship(
        id: json['id'] as String,
        fromCharacterId: json['fromCharacterId'] as String,
        toCharacterId: json['toCharacterId'] as String,
        relationType: json['relationType'] as String,
        description: json['description'] as String?,
      );
}

/// 关系图节点位置信息
class RelationshipNodePosition {
  final String characterId;
  final double x;
  final double y;

  const RelationshipNodePosition({
    required this.characterId,
    required this.x,
    required this.y,
  });

  Offset toOffset() => Offset(x, y);

  Map<String, dynamic> toJson() => {'characterId': characterId, 'x': x, 'y': y};

  factory RelationshipNodePosition.fromJson(Map<String, dynamic> json) =>
      RelationshipNodePosition(
        characterId: json['characterId'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );
}

/// 关系图持久化数据（关系列表 + 节点位置）
class RelationshipGraphData {
  final List<CharacterRelationship> relationships;
  final List<RelationshipNodePosition> positions;

  const RelationshipGraphData({
    required this.relationships,
    required this.positions,
  });

  Map<String, dynamic> toJson() => {
    'relationships': relationships.map((r) => r.toJson()).toList(),
    'positions': positions.map((p) => p.toJson()).toList(),
  };

  factory RelationshipGraphData.fromJson(Map<String, dynamic> json) =>
      RelationshipGraphData(
        relationships:
            (json['relationships'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      CharacterRelationship.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        positions:
            (json['positions'] as List<dynamic>?)
                ?.map(
                  (e) => RelationshipNodePosition.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            [],
      );
}

/// 关系类型 → 线条样式的映射
enum RelationLineStyle { solid, dashed, dotted }

RelationLineStyle lineStyleForType(String type) {
  const familyTypes = {
    '父女',
    '父子',
    '母子',
    '母女',
    '兄弟',
    '姐妹',
    '兄妹',
    '姐弟',
    '亲属',
    '家人',
  };
  const enemyTypes = {'敌人', '对手', '宿敌', '仇人'};
  if (familyTypes.contains(type)) return RelationLineStyle.solid;
  if (enemyTypes.contains(type)) return RelationLineStyle.dashed;
  return RelationLineStyle.dotted;
}

/// 角色类型 → 节点颜色的映射
int colorForRole(String? role) {
  if (role == null) return 0xFF9E9E9E; // gray
  if (role.contains('主角') && !role.contains('女')) return 0xFF42A5F5; // blue
  if (role.contains('女主')) return 0xFFEC407A; // pink
  if (role.contains('反派') || role.contains('敌')) return 0xFFEF5350; // red
  return 0xFF9E9E9E; // gray for 配角 and others
}
