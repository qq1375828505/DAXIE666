import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:uuid/uuid.dart';

class LocalFileDataSource {
  static final _uuid = Uuid();

  Future<Directory> get _projectsDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'NovelProjects'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> createProjectDir(String novelId, String title) async {
    final dir = await _projectsDir;
    final projectDir = Directory(p.join(dir.path, '${novelId}_${title}'));
    await projectDir.create(recursive: true);
    await Directory(p.join(projectDir.path, 'chapters')).create();
    await Directory(p.join(projectDir.path, 'references')).create();
    await Directory(p.join(projectDir.path, 'prompts')).create();
    await Directory(p.join(projectDir.path, 'assets')).create();
    return projectDir.path;
  }

  Future<String> getProjectDir(String novelId, String title) async {
    final dir = await _projectsDir;
    return p.join(dir.path, '${novelId}_${title}');
  }

  Future<void> saveProjectJson(String projectPath, Map<String, dynamic> data) async {
    final file = File(p.join(projectPath, 'project.json'));
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> saveChapterContent(String projectPath, String chapterId, String content) async {
    final file = File(p.join(projectPath, 'chapters', '$chapterId.md'));
    await file.writeAsString(content, encoding: utf8);
  }

  Future<String> readChapterContent(String projectPath, String chapterId) async {
    final file = File(p.join(projectPath, 'chapters', '$chapterId.md'));
    if (await file.exists()) {
      return await file.readAsString(encoding: utf8);
    }
    return '';
  }

  Future<void> saveVolumesJson(String projectPath, List<Map<String, dynamic>> volumes) async {
    final file = File(p.join(projectPath, 'volumes.json'));
    await file.writeAsString(jsonEncode(volumes));
  }

  Future<void> saveChapterIndex(String projectPath, List<Map<String, dynamic>> chapters) async {
    final file = File(p.join(projectPath, 'chapter_index.json'));
    await file.writeAsString(jsonEncode(chapters));
  }

  Future<void> exportNovelPack(String projectPath, String exportPath) async {
    final encoder = ZipFileEncoder();
    encoder.create(exportPath);
    await encoder.addDirectory(Directory(projectPath));
    encoder.close();
  }

  Future<String> importNovelPack(String packPath) async {
    final bytes = await File(packPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await _projectsDir;
    final novelId = _uuid.v4();
    final extractDir = Directory(p.join(dir.path, novelId));
    await extractDir.create(recursive: true);

    for (final file in archive) {
      if (file.isFile) {
        final outFile = File(p.join(extractDir.path, file.name));
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
    return extractDir.path;
  }

  Future<void> deleteProjectDir(String projectPath) async {
    final dir = Directory(projectPath);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
