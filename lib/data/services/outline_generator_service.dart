import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/data/models/ai_config_model.dart';
import 'package:novel_ide/data/models/chapter_model.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

/// 大纲层级节点
class OutlineNode {
  final String title;
  final String? summary;
  final List<OutlineNode> children;
  final String nodeType; // 'volume' | 'outline' | 'chapter'

  OutlineNode({
    required this.title,
    this.summary,
    this.children = const [],
    required this.nodeType,
  });

  factory OutlineNode.fromJson(Map<String, dynamic> json) {
    return OutlineNode(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => OutlineNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nodeType: json['type'] as String? ?? 'chapter',
    );
  }
}

/// AI大纲生成服务
class OutlineGeneratorService {
  final AiService _aiService = AiService();

  /// 从所有章节生成三级大纲结构
  Future<List<OutlineNode>> generateOutline({
    required List<Chapter> chapters,
    required AiConfig aiConfig,
  }) async {
    // 构建章节摘要
    final chapterSummaries = chapters
        .where((c) => c.content.isNotEmpty)
        .map((c) => '【${c.title}】\n${c.content.length > 500 ? c.content.substring(0, 500) : c.content}')
        .join('\n\n---\n\n');

    if (chapterSummaries.isEmpty) {
      throw Exception('没有可分析的章节内容，请先写一些章节');
    }

    final messages = [
      {
        'role': 'system',
        'content': '''你是一个专业的小说大纲分析助手。请根据提供的小说章节内容，自动生成三级层级结构的大纲。

输出要求：
1. 必须返回纯JSON格式，不要任何其他文字
2. JSON结构为一个数组，每个元素代表一个分卷
3. 每个分卷包含 title、summary、children 字段
4. children 是细纲数组，每个细纲包含 title、summary、children 字段
5. 最内层 children 是章纲数组，每个章纲包含 title、summary 字段
6. type 字段：分卷用 "volume"，细纲用 "outline"，章纲用 "chapter"

JSON格式示例：
[
  {
    "title": "第一卷：初入江湖",
    "summary": "主角踏入修仙之路",
    "type": "volume",
    "children": [
      {
        "title": "篇一：拜入宗门",
        "summary": "主角加入青云宗",
        "type": "outline",
        "children": [
          {
            "title": "第1章：少年下山",
            "summary": "主角离开家乡",
            "type": "chapter"
          }
        ]
      }
    ]
  }
]

请根据以下章节内容生成大纲：''',
      },
      {
        'role': 'user',
        'content': chapterSummaries,
      },
    ];

    final response = await _aiService.chat(aiConfig, messages, taskType: 'outline_generate');

    // 解析JSON
    return _parseOutlineResponse(response);
  }

  List<OutlineNode> _parseOutlineResponse(String response) {
    // 尝试提取JSON
    String jsonStr = response.trim();

    // 去掉可能的 markdown 代码块
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '');
      jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
    }

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => OutlineNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('AI返回格式解析失败，请重试: $e');
    }
  }
}
