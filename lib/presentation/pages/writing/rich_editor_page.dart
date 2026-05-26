import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

/// 基于 WebView 的富文本编辑器页面
/// 复用起点作家的 rich_editor.js + WeReadApi.js
class RichEditorPage extends ConsumerStatefulWidget {
  final String novelId;
  final String chapterId;
  final String initialTitle;
  final String initialContent;

  const RichEditorPage({
    super.key,
    required this.novelId,
    required this.chapterId,
    this.initialTitle = '',
    this.initialContent = '',
  });

  @override
  ConsumerState<RichEditorPage> createState() => _RichEditorPageState();
}

class _RichEditorPageState extends ConsumerState<RichEditorPage> {
  late final WebViewController _webController;
  bool _isEditorReady = false;
  String _currentText = '';
  int _wordCount = 0;

  // 当前选区状态（从JS同步过来）
  bool _isBold = false;
  bool _isItalic = false;
  bool _isInLink = false;
  String _currentFormat = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _onEditorReady(),
      ))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onJsMessage,
      );

    // 加载内联HTML
    final html = await _buildEditorHtml();
    _webController.loadHtmlString(html);
  }

  /// 构建自包含的编辑器HTML（CSS/JS内联）
  Future<String> _buildEditorHtml() async {
    // 加载资源文件
    final normalizeCss = await rootBundle.loadString('assets/editor/normalize.css');
    final styleCss = await rootBundle.loadString('assets/editor/style.css');
    final newsCss = await rootBundle.loadString('assets/editor/news.css');
    final editorJs = await rootBundle.loadString('assets/editor/rich_editor.js');

    // 修改JS：将 wereadBridge 调用改为 FlutterBridge
    final modifiedEditorJs = editorJs
        .replaceAll("wereadBridge.handleWithRichEditor(", "_sendToFlutter(")
        .replaceAll("wereadBridge.confirmDispatchMessage()", "void(0)");

    // 构建完整HTML
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>$normalizeCss</style>
    <style>$styleCss</style>
    <style>$newsCss</style>
    <style>
      body { padding: 0; margin: 0; }
      #editor {
        padding: 16px;
        min-height: 100vh;
        font-size: 18px;
        line-height: 1.8;
        font-family: 'Noto Serif SC', serif;
        color: #333;
      }
      #editor:focus { outline: none; }
    </style>
</head>
<body>
<div id="fakeEditor" contenteditable="true" style="width:0px;height:0px;"></div>
<div id="titleInput" style="display:none;">
    <textarea id="titleInput_text" placeholder="请输入标题"></textarea>
</div>
<div id="editor" class="re re_Write" contentEditable="true"></div>

<script>
// FlutterBridge 替代 WeReadBridge
function _sendToFlutter(apiName, params) {
    try {
        FlutterBridge.postMessage(JSON.stringify({api: apiName, params: params}));
    } catch(e) {}
}

// 兼容 wereadBridge
var wereadBridge = {
    handleWithRichEditor: function(apiName, params) {
        _sendToFlutter(apiName, params);
    },
    confirmDispatchMessage: function() {}
};
</script>
<script>$modifiedEditorJs</script>
</body>
</html>''';
  }

  /// 编辑器加载完成
  void _onEditorReady() {
    setState(() => _isEditorReady = true);

    // 设置初始内容
    if (widget.initialContent.isNotEmpty) {
      final escapedContent = widget.initialContent
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      _webController.runJavaScript("RE.setHtml('<p>${escapedContent.replaceAll('\n', '</p><p>')}</p>')");
    }
  }

  /// 接收JS消息
  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      final api = data['api'] as String;
      final params = data['params'] as Map<String, dynamic>?;

      switch (api) {
        case 'onTextChange':
          _currentText = params?['param'] ?? '';
          _wordCount = _currentText.replaceAll(RegExp(r'\s'), '').length;
          ref.read(wordCountProvider.notifier).state = _wordCount;
          break;

        case 'onHtmlChange':
          break;

        case 'onSelectionChange':
          _updateSelectionState(params?['param'] ?? '');
          break;

        case 'onArticleTextChange':
        case 'onHtmlForEpubChange':
        case 'onTextContentLengthChange':
          // 忽略，用 onTextChange 即可
          break;
      }
    } catch (_) {}
  }

  /// 解析选区状态
  void _updateSelectionState(String stateStr) {
    final items = stateStr.split('r_e_ds');
    setState(() {
      _isBold = items.contains('bold');
      _isItalic = items.contains('italic');
      _isInLink = items.contains('isEditingLink:1');
      _currentFormat = items.where((i) =>
          i == 'blockquote' || i.startsWith('h') || i == 'orderedList' || i == 'unorderedList'
      ).join(', ');
    });
  }

  /// 调用JS方法
  void _callJs(String js) {
    if (_isEditorReady) {
      _webController.runJavaScript(js);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('富文本编辑器', style: TextStyle(fontSize: 16)),
            Text(
              '$_wordCount字',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, size: 22),
            tooltip: '保存',
            onPressed: _saveContent,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // 格式工具栏
          _buildFormatToolbar(),
          // WebView 编辑器
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webController),
                if (!_isEditorReady)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 格式工具栏（加粗/斜体/标题/引用/列表等）
  Widget _buildFormatToolbar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _FormatButton(
            icon: Icons.format_bold,
            isActive: _isBold,
            onPressed: () => _callJs('RE.setBold()'),
          ),
          _FormatButton(
            icon: Icons.format_italic,
            isActive: _isItalic,
            onPressed: () => _callJs('RE.setItalic()'),
          ),
          _FormatButton(
            icon: Icons.title,
            label: 'H1',
            isActive: _currentFormat.contains('h1'),
            onPressed: () => _callJs("RE.setHeading('h1')"),
          ),
          _FormatButton(
            icon: Icons.title,
            label: 'H2',
            isActive: _currentFormat.contains('h2'),
            onPressed: () => _callJs("RE.setHeading('h2')"),
          ),
          _FormatButton(
            icon: Icons.format_quote,
            isActive: _currentFormat.contains('blockquote'),
            onPressed: () => _callJs('RE.setBlockquote()'),
          ),
          _FormatButton(
            icon: Icons.format_list_bulleted,
            isActive: _currentFormat.contains('unorderedList'),
            onPressed: () => _callJs('RE.setUnorderedList()'),
          ),
          _FormatButton(
            icon: Icons.format_list_numbered,
            isActive: _currentFormat.contains('orderedList'),
            onPressed: () => _callJs('RE.setOrderedList()'),
          ),
          const VerticalDivider(width: 16),
          _FormatButton(
            icon: Icons.undo,
            onPressed: () => _callJs('RE.undo()'),
          ),
          _FormatButton(
            icon: Icons.redo,
            onPressed: () => _callJs('RE.redo()'),
          ),
          const VerticalDivider(width: 16),
          _FormatButton(
            icon: Icons.insert_photo,
            onPressed: _insertImage,
          ),
          _FormatButton(
            icon: Icons.link,
            isActive: _isInLink,
            onPressed: _insertLink,
          ),
          _FormatButton(
            icon: Icons.format_clear,
            onPressed: () => _callJs('RE.removeFormat()'),
          ),
        ],
      ),
    );
  }

  /// 保存内容
  void _saveContent() {
    _callJs("RE.getHtml()");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('内容已获取'), duration: Duration(seconds: 1)),
    );
  }

  /// 插入图片
  void _insertImage() {
    // TODO: 打开文件选择器选择图片，获取URL后调用 _callJs("RE.insertImage([...])")
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片插入功能开发中')),
    );
  }

  /// 插入链接
  void _insertLink() {
    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('插入链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '链接文本')),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL地址')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final text = titleCtrl.text.replaceAll("'", "\\'");
              final href = urlCtrl.text.replaceAll("'", "\\'");
              _callJs("RE.insertLink('$text', '$href', '$text')");
              Navigator.pop(ctx);
            },
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }

  /// 更多菜单
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制全部内容'),
              onTap: () {
                Navigator.pop(ctx);
                _callJs("RE.getHtml()");
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_paint),
              title: const Text('清除所有格式'),
              onTap: () {
                Navigator.pop(ctx);
                _callJs('RE.removeFormat()');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('清空编辑器'),
              onTap: () {
                Navigator.pop(ctx);
                _callJs('RE.emptyEditor()');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 格式工具栏按钮
class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback? onPressed;

  const _FormatButton({
    required this.icon,
    this.label,
    this.isActive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: label != null
            ? Text(label!, style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.primary : Colors.grey[700],
              ))
            : Icon(icon, size: 20, color: isActive ? AppColors.primary : Colors.grey[700]),
      ),
    );
  }
}
