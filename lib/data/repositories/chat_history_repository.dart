import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:novel_ide/data/models/ai_chat_session_model.dart';

/// AI 对话历史记录仓库
/// 将会话列表持久化到本地 JSON 文件
class ChatHistoryRepository {
  static const String _fileName = 'ai_chat_history.json';
  static const int _maxSessions = 100; // 最多保存 100 个会话
  static const int _maxMessagesPerSession = 200; // 单个会话最多 200 条消息

  /// 获取存储文件路径
  Future<String> _getFilePath() async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    return '${dir.path}/NovelProjects/$_fileName';
  }

  /// 确保目录存在
  Future<void> _ensureDirectory() async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final path = '${dir.path}/NovelProjects';
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// 加载所有会话
  Future<List<AiChatSessionModel>> loadSessions() async {
    try {
      await _ensureDirectory();
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final sessionList = AiChatSessionList.fromJsonString(jsonString);

      // 按更新时间排序（最新的在前）
      final sorted = List.of(sessionList.sessions)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return sorted;
    } catch (e) {
      print('ChatHistoryRepository load error: $e');
      return [];
    }
  }

  /// 保存所有会话
  Future<void> saveSessions(List<AiChatSessionModel> sessions) async {
    try {
      await _ensureDirectory();

      // 限制会话数量
      var trimmedSessions = sessions;
      if (sessions.length > _maxSessions) {
        // 按更新时间排序，保留最新的
        sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        trimmedSessions = sessions.take(_maxSessions).toList();
      }

      // 限制每个会话的消息数量
      for (final session in trimmedSessions) {
        if (session.messages.length > _maxMessagesPerSession) {
          // 保留最新的消息
          session.messages = session.messages
              .sublist(session.messages.length - _maxMessagesPerSession);
        }
      }

      final sessionList = AiChatSessionList(sessions: trimmedSessions);
      final filePath = await _getFilePath();
      final file = File(filePath);

      await file.writeAsString(sessionList.toJsonString());
    } catch (e) {
      print('ChatHistoryRepository save error: $e');
      rethrow;
    }
  }

  /// 添加或更新单个会话
  Future<void> saveSession(AiChatSessionModel session) async {
    final sessions = await loadSessions();

    // 查找是否已存在
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }

    await saveSessions(sessions);
  }

  /// 删除单个会话
  Future<void> deleteSession(String sessionId) async {
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveSessions(sessions);
  }

  /// 清空所有会话
  Future<void> clearAllSessions() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('ChatHistoryRepository clear error: $e');
    }
  }

  /// 获取会话数量
  Future<int> getSessionCount() async {
    final sessions = await loadSessions();
    return sessions.length;
  }

  /// 获取存储文件大小（字节）
  Future<int> getStorageSize() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
