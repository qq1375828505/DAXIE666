import 'package:flutter/material.dart';

class Character {
  final String id;
  final String novelId;
  String name;
  String? role;
  String? description;
  String? appearance;
  String? personality;
  String? background;
  List<SettingTag> tags;
  DateTime createdAt;
  DateTime updatedAt;

  Character({
    required this.id,
    required this.novelId,
    required this.name,
    this.role,
    this.description,
    this.appearance,
    this.personality,
    this.background,
    List<SettingTag>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'novelId': novelId,
        'name': name,
        'role': role,
        'description': description,
        'appearance': appearance,
        'personality': personality,
        'background': background,
        'tags': tags.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] as String,
        novelId: json['novelId'] as String,
        name: json['name'] as String,
        role: json['role'] as String?,
        description: json['description'] as String?,
        appearance: json['appearance'] as String?,
        personality: json['personality'] as String?,
        background: json['background'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((t) => SettingTag.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class SettingCard {
  final String id;
  final String novelId;
  String name;
  String? category;
  String? description;
  List<SettingTag> tags;
  DateTime createdAt;
  DateTime updatedAt;

  SettingCard({
    required this.id,
    required this.novelId,
    required this.name,
    this.category,
    this.description,
    List<SettingTag>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'novelId': novelId,
        'name': name,
        'category': category,
        'description': description,
        'tags': tags.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SettingCard.fromJson(Map<String, dynamic> json) => SettingCard(
        id: json['id'] as String,
        novelId: json['novelId'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        description: json['description'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((t) => SettingTag.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class SettingTag {
  String key;
  String value;

  SettingTag({required this.key, required this.value});

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  factory SettingTag.fromJson(Map<String, dynamic> json) =>
      SettingTag(key: json['key'] as String, value: json['value'] as String);
}

class PlotHook {
  final String id;
  final String novelId;
  String title;
  String? description;
  bool isRevealed;
  int? chapterPlantedId;
  int? chapterRevealedId;
  int idleChapters;
  DateTime createdAt;
  DateTime updatedAt;

  PlotHook({
    required this.id,
    required this.novelId,
    required this.title,
    this.description,
    this.isRevealed = false,
    this.chapterPlantedId,
    this.chapterRevealedId,
    this.idleChapters = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get statusColor => isRevealed ? Colors.green : (idleChapters > 10 ? Colors.red : Colors.orange);

  String get statusLabel => isRevealed ? '已回收' : (idleChapters > 10 ? '闲置超10章' : '待回收');

  Map<String, dynamic> toJson() => {
        'id': id,
        'novelId': novelId,
        'title': title,
        'description': description,
        'isRevealed': isRevealed,
        'chapterPlantedId': chapterPlantedId,
        'chapterRevealedId': chapterRevealedId,
        'idleChapters': idleChapters,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlotHook.fromJson(Map<String, dynamic> json) => PlotHook(
        id: json['id'] as String,
        novelId: json['novelId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        isRevealed: json['isRevealed'] as bool? ?? false,
        chapterPlantedId: json['chapterPlantedId'] as int?,
        chapterRevealedId: json['chapterRevealedId'] as int?,
        idleChapters: json['idleChapters'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class ReferenceMaterial {
  final String id;
  final String novelId;
  String title;
  String? content;
  String? source;
  String? sourceUrl;
  DateTime createdAt;
  DateTime updatedAt;

  ReferenceMaterial({
    required this.id,
    required this.novelId,
    required this.title,
    this.content,
    this.source,
    this.sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'novelId': novelId,
        'title': title,
        'content': content,
        'source': source,
        'sourceUrl': sourceUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReferenceMaterial.fromJson(Map<String, dynamic> json) => ReferenceMaterial(
        id: json['id'] as String,
        novelId: json['novelId'] as String,
        title: json['title'] as String,
        content: json['content'] as String?,
        source: json['source'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class SettingReminder {
  final String id;
  final String novelId;
  String keyword;
  String? relatedCharacter;
  String? relatedSetting;
  List<String> conflicts;
  String? note;
  DateTime createdAt;

  SettingReminder({
    required this.id,
    required this.novelId,
    required this.keyword,
    this.relatedCharacter,
    this.relatedSetting,
    List<String>? conflicts,
    this.note,
    DateTime? createdAt,
  })  : conflicts = conflicts ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'novelId': novelId,
        'keyword': keyword,
        'relatedCharacter': relatedCharacter,
        'relatedSetting': relatedSetting,
        'conflicts': conflicts,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SettingReminder.fromJson(Map<String, dynamic> json) => SettingReminder(
        id: json['id'] as String,
        novelId: json['novelId'] as String,
        keyword: json['keyword'] as String,
        relatedCharacter: json['relatedCharacter'] as String?,
        relatedSetting: json['relatedSetting'] as String?,
        conflicts: (json['conflicts'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
