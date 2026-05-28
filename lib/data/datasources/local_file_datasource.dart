import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';

class LocalFileDataSource {
  static final _uuid = Uuid();

  /// 获取基础目录（NovelProjects 的父目录）
  /// 用于备份服务等需要访问根目录的场景
  Future<Directory> getBaseDir() async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    return dir;
  }

  /// 根目录：使用外部存储公共持久化目录，升级/卸载不丢失
  /// Android: /storage/emulated/0/Android/data/{package}/files/NovelProjects/
  /// 使用 getExternalStorageDirectory() 确保数据持久化
  Future<Directory> get _rootDir async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'NovelProjects'));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  /// 作品区目录
  Future<Directory> get _worksDir async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, '作品区'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 资料区目录
  Future<Directory> get _materialsDir async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, '资料区'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 记忆包目录
  Future<Directory> get _memoryDir async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, '记忆包'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Skill目录
  Future<Directory> get skillDir async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, 'Skill'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Agent目录
  Future<Directory> get agentDir async {
    final root = await _rootDir;
    final dir = Directory(p.join(root.path, 'Agent'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ===== 作品区操作 =====

  Future<String> createProjectDir(String novelId, String title) async {
    final dir = await _worksDir;
    final projectDir = Directory(p.join(dir.path, '${novelId}_${title}'));
    await projectDir.create(recursive: true);
    await Directory(p.join(projectDir.path, 'chapters')).create();
    return projectDir.path;
  }

  Future<String> getProjectDir(String novelId, String title) async {
    final dir = await _worksDir;
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

  Future<void> deleteProjectDir(String projectPath) async {
    final dir = Directory(projectPath);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// 导出作品为 .novelpack 压缩包
  Future<void> exportNovelPack(String projectPath, String exportPath) async {
    final archive = Archive();
    final projectDir = Directory(projectPath);
    await _addDirectoryToArchive(projectDir, projectDir.path, archive);
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('ZIP编码失败');
    await File(exportPath).writeAsBytes(zipData);
  }

  /// 递归将目录添加到 Archive
  Future<void> _addDirectoryToArchive(Directory dir, String rootPath, Archive archive) async {
    final entities = dir.listSync();
    for (final entity in entities) {
      final relativePath = p.relative(entity.path, from: rootPath);
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      } else if (entity is Directory) {
        await _addDirectoryToArchive(entity, rootPath, archive);
      }
    }
  }

  /// 导入 .novelpack 压缩包，返回解压目录路径
  Future<String> importNovelPack(String packPath) async {
    final bytes = await File(packPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await _worksDir;
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

  // ===== 资料区操作 =====

  /// 获取某作品的资料目录：资料区/{novelId}_{title}/
  Future<String> getMaterialsDir(String novelId, String title) async {
    final dir = await _materialsDir;
    final matDir = Directory(p.join(dir.path, '${novelId}_${title}'));
    if (!await matDir.exists()) await matDir.create(recursive: true);
    return matDir.path;
  }

  // ===== 记忆包操作 =====

  /// 获取某作品的记忆文件路径：记忆包/{novelId}_{title}_memory.txt
  Future<String> getMemoryPath(String novelId, String title) async {
    final dir = await _memoryDir;
    return p.join(dir.path, '${novelId}_${title}_memory.txt');
  }

  // ===== 原始文件备份 =====

  /// 保存导入文件的原始备份
  /// 备份路径：NovelProjects/original/{novelId}/{timestamp}_{fileName}
  /// 返回备份文件路径
  Future<String> saveOriginalBackup(String novelId, String fileName, List<int> fileBytes) async {
    final baseDir = await getBaseDir();
    final originalDir = Directory(p.join(baseDir.path, 'NovelProjects', 'original', novelId));
    if (!await originalDir.exists()) {
      await originalDir.create(recursive: true);
    }
    // 文件名加时间戳避免重复
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = p.join(originalDir.path, '${timestamp}_$fileName');
    final backupFile = File(backupPath);
    await backupFile.writeAsBytes(fileBytes);
    return backupPath;
  }

  // ===== 数据迁移 =====

  /// 迁移旧目录结构到新结构（兼容旧版本数据）
  Future<void> migrateIfNeeded() async {
    final root = await _rootDir;

    // 检查是否有旧格式数据（直接在 NovelProjects/ 下的作品目录）
    final oldEntries = await root.list().toList();
    final oldWorkDirs = oldEntries.whereType<Directory>().where((d) {
      final name = p.basename(d.path);
      // 旧格式：{novelId}_{title} 直接在 NovelProjects/ 下
      // 新格式：作品区/资料区/Skill/Agent/记忆包
      return !['作品区', '资料区', 'Skill', 'Agent', '记忆包', 'materials', 'memories', 'skills'].contains(name);
    }).toList();

    if (oldWorkDirs.isEmpty) return; // 无需迁移

    // 迁移作品目录
    final worksDir = await _worksDir;
    for (final oldDir in oldWorkDirs) {
      final name = p.basename(oldDir.path);
      final newDir = Directory(p.join(worksDir.path, name));
      if (!await newDir.exists()) {
        await oldDir.rename(newDir.path);
      }
    }

    // 迁移旧的 materials 目录
    final oldMaterials = Directory(p.join(root.path, 'materials'));
    if (await oldMaterials.exists()) {
      final materialsDir = await _materialsDir;
      final files = await oldMaterials.list().toList();
      for (final file in files) {
        if (file is File) {
          final name = p.basename(file.path);
          final newFile = File(p.join(materialsDir.path, name));
          if (!await newFile.exists()) {
            await file.rename(newFile.path);
          }
        }
      }
      try { await oldMaterials.delete(); } catch (_) {}
    }

    // 迁移旧的 memories 目录
    final oldMemories = Directory(p.join(root.path, 'memories'));
    if (await oldMemories.exists()) {
      final memoryDir = await _memoryDir;
      final files = await oldMemories.list().toList();
      for (final file in files) {
        if (file is File) {
          final name = p.basename(file.path);
          final newFile = File(p.join(memoryDir.path, name));
          if (!await newFile.exists()) {
            await file.rename(newFile.path);
          }
        }
      }
      try { await oldMemories.delete(); } catch (_) {}
    }

    // 迁移旧的 skills 目录
    final oldSkills = Directory(p.join(root.path, 'skills'));
    if (await oldSkills.exists()) {
      final skillDirPath = await skillDir;
      final files = await oldSkills.list().toList();
      for (final file in files) {
        if (file is File) {
          final name = p.basename(file.path);
          final newFile = File(p.join(skillDirPath.path, name));
          if (!await newFile.exists()) {
            await file.rename(newFile.path);
          }
        }
      }
      try { await oldSkills.delete(); } catch (_) {}
    }
  }
}
