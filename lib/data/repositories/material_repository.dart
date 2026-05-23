import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:novel_ide/data/models/material_models.dart';

class MaterialRepository {
  static final _uuid = Uuid();

  Future<Directory> _getMaterialsDir(String novelId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'NovelProjects', 'materials'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
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
}
