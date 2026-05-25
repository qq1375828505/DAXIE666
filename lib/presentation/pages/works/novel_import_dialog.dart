import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/services/novel_import_service.dart';
import 'package:novel_ide/data/services/ai_analysis_service.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

/// 小说文件导入对话框
/// 支持 TXT/MD/DOCX 文件导入，自动拆章，可选 AI 分析填充资料库
class NovelImportDialog extends ConsumerStatefulWidget {
  final String novelId;
  final String novelTitle;

  const NovelImportDialog({
    super.key,
    required this.novelId,
    required this.novelTitle,
  });

  @override
  ConsumerState<NovelImportDialog> createState() => _NovelImportDialogState();
}

class _NovelImportDialogState extends ConsumerState<NovelImportDialog> {
  String? _filePath;
  String? _fileName;
  bool _isImporting = false;
  bool _isAnalyzing = false;
  String _statusText = '';
  double _progress = 0;
  ImportResult? _importResult;
  AnalysisResult? _analysisResult;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              const Icon(Icons.file_upload, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('导入小说文件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // 支持格式说明
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '支持 TXT、MD、DOCX 格式，自动识别章节标题并拆分导入',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),

          // 文件选择区域
          GestureDetector(
            onTap: _isImporting || _isAnalyzing ? null : _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _filePath != null ? AppColors.primary : Colors.grey[300]!,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _filePath != null
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : Colors.grey[50],
              ),
              child: _filePath != null
                  ? Column(
                      children: [
                        const Icon(Icons.description, size: 36, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(
                          _fileName ?? '',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('点击更换文件', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('点击选择文件', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Text('TXT / MD / DOCX', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // 状态信息
          if (_statusText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _importResult?.success == true
                    ? Colors.green.shade50
                    : _importResult?.success == false
                        ? Colors.red.shade50
                        : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusText, style: const TextStyle(fontSize: 13)),
                  if (_isImporting || _isAnalyzing) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // AI 分析选项
          if (_importResult?.success == true) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 智能分析', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: const Text('自动提取角色、设定、地点、势力、道具、伏笔'),
              value: true,
              onChanged: _isAnalyzing ? null : (v) {},
              secondary: const Icon(Icons.auto_awesome, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
          ],

          const Spacer(),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_isImporting || _isAnalyzing) ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isImporting
                      ? '导入中...'
                      : _isAnalyzing
                          ? '分析中...'
                          : _importResult?.success == true
                              ? '完成'
                              : '开始导入'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: (_isImporting || _isAnalyzing || _importResult?.success == true)
                      ? null
                      : _startImport,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择小说文件',
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
        _importResult = null;
        _analysisResult = null;
        _statusText = '';
      });
    }
  }

  Future<void> _startImport() async {
    if (_filePath == null) {
      setState(() => _statusText = '请先选择文件');
      return;
    }

    setState(() {
      _isImporting = true;
      _progress = 0;
      _statusText = '正在读取文件并拆分章节...';
    });

    final service = NovelImportService();
    final result = await service.importFromFile(
      novelId: widget.novelId,
      novelTitle: widget.novelTitle,
      filePath: _filePath!,
    );

    if (!mounted) return;

    setState(() {
      _isImporting = false;
      _importResult = result;
      _progress = 0.5;
    });

    if (result.success) {
      setState(() {
        _statusText = '导入成功！共 ${result.chapterCount} 章，${result.totalWords} 字';
      });

      // 刷新章节列表
      ref.invalidate(chaptersProvider(widget.novelId));

      // 自动触发 AI 分析
      await _startAiAnalysis();
    } else {
      setState(() {
        _statusText = '导入失败：${result.error}';
      });
    }
  }

  Future<void> _startAiAnalysis() async {
    final config = ref.read(selectedAiConfigProvider);
    if (config == null) {
      setState(() {
        _statusText = '导入成功！未配置 AI，跳过智能分析。\n请前往「我的 → AI模型配置」设置后重试。';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusText = '正在启动 AI 分析...';
    });

    try {
      // 读取导入的章节内容（取前 10 章用于分析）
      final content = await _getChaptersContent(maxChapters: 10);
      if (content.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _statusText = '导入成功！但章节内容为空，无法进行 AI 分析。';
        });
        return;
      }

      final analysisService = AiAnalysisService();
      final result = await analysisService.analyzeAndFillMaterials(
        content: content,
        config: config,
        novelId: widget.novelId,
        onProgress: (step, progress) {
          if (mounted) {
            setState(() {
              _statusText = step;
              _progress = 0.5 + progress * 0.5;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _analysisResult = result;
        _progress = 1.0;
        _statusText = '全部完成！\n导入 ${_importResult?.chapterCount ?? 0} 章 → AI 提取 $result';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _statusText = 'AI 分析失败：$e\n（章节已成功导入，可稍后手动分析）';
      });
    }
  }

  /// 获取前 N 章的内容用于 AI 分析
  Future<String> _getChaptersContent({int maxChapters = 10}) async {
    final chapters = ref.read(chaptersProvider(widget.novelId)).value ?? [];
    if (chapters.isEmpty) return '';

    final buffer = StringBuffer();
    final take = chapters.length > maxChapters ? maxChapters : chapters.length;

    for (int i = 0; i < take; i++) {
      final ch = chapters[i];
      buffer.writeln('=== ${ch.title} ===');
      // 简单读取章节内容（通过 repository）
      try {
        final repo = ref.read(chapterRepoProvider);
        final fullChapter = await repo.getChapter(ch.id);
        if (fullChapter != null && fullChapter.content.isNotEmpty) {
          buffer.writeln(fullChapter.content);
        }
      } catch (_) {
        // 跳过读取失败的章节
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
