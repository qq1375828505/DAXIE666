import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/models/character_relationship.dart';

class MaterialRepository {
  Future<Directory> _getMaterialsDir(String novelId) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final matDir = Directory(p.join(dir.path, 'NovelProjects', '资料区'));
    if (!await matDir.exists()) await matDir.create(recursive: true);
    return matDir;
  }

  // Characters
  Future<List<Character>> getCharacters(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_characters.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => Character.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveCharacters(String novelId, List<Character> characters) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_characters.json'));
    await file.writeAsString(jsonEncode(characters.map((c) => c.toJson()).toList()));
  }

  // Setting Cards
  Future<List<SettingCard>> getSettingCards(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_settings.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => SettingCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSettingCards(String novelId, List<SettingCard> cards) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_settings.json'));
    await file.writeAsString(jsonEncode(cards.map((c) => c.toJson()).toList()));
  }

  // Plot Hooks
  Future<List<PlotHook>> getPlotHooks(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_hooks.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => PlotHook.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> savePlotHooks(String novelId, List<PlotHook> hooks) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_hooks.json'));
    await file.writeAsString(jsonEncode(hooks.map((h) => h.toJson()).toList()));
  }

  // References
  Future<List<ReferenceMaterial>> getReferences(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_references.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => ReferenceMaterial.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveReferences(String novelId, List<ReferenceMaterial> refs) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_references.json'));
    await file.writeAsString(jsonEncode(refs.map((r) => r.toJson()).toList()));
  }

  // Setting Reminders
  Future<List<SettingReminder>> getSettingReminders(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_reminders.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => SettingReminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSettingReminders(String novelId, List<SettingReminder> reminders) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_reminders.json'));
    await file.writeAsString(jsonEncode(reminders.map((r) => r.toJson()).toList()));
  }

  // --- V2: Locations ---
  Future<List<Location>> getLocations(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_locations.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => Location.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveLocations(String novelId, List<Location> locations) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_locations.json'));
    await file.writeAsString(jsonEncode(locations.map((l) => l.toJson()).toList()));
  }

  // --- V2: Factions ---
  Future<List<Faction>> getFactions(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_factions.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => Faction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveFactions(String novelId, List<Faction> factions) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_factions.json'));
    await file.writeAsString(jsonEncode(factions.map((f) => f.toJson()).toList()));
  }

  // --- V2: Items ---
  Future<List<Item>> getItems(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_items.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveItems(String novelId, List<Item> items) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_items.json'));
    await file.writeAsString(jsonEncode(items.map((i) => i.toJson()).toList()));
  }

  // --- V3: Custom Folders ---
  Future<List<CustomMaterialFolder>> getCustomFolders(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_custom_folders.json'));
    if (!await file.exists()) return [];
    final content = await file.readAsString(encoding: utf8);
    final list = jsonDecode(content) as List<dynamic>;
    return list.map((j) => CustomMaterialFolder.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> saveCustomFolders(String novelId, List<CustomMaterialFolder> folders) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_custom_folders.json'));
    final json = folders.map((f) => f.toJson()).toList();
    await file.writeAsString(jsonEncode(json), encoding: utf8);
  }


  // --- V4: Character Relationships ---
  Future<RelationshipGraphData> getRelationshipGraphData(String novelId) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_relationships.json'));
    if (!await file.exists()) {
      return const RelationshipGraphData(relationships: [], positions: []);
    }
    final contentStr = await file.readAsString(encoding: utf8);
    final json = jsonDecode(contentStr) as Map<String, dynamic>;
    return RelationshipGraphData.fromJson(json);
  }

  Future<void> saveRelationshipGraphData(
    String novelId,
    RelationshipGraphData data,
  ) async {
    final dir = await _getMaterialsDir(novelId);
    final file = File(p.join(dir.path, '${novelId}_relationships.json'));
    await file.writeAsString(jsonEncode(data.toJson()), encoding: utf8);
  }

}