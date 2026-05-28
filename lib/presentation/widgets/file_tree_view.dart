import 'package:flutter/material.dart';

/// 文件树节点数据模型
class FileTreeNode {
  final String id;
  final String name;
  final String? content;
  final List<FileTreeNode> children;
  final bool isFolder;
  bool isExpanded;
  final String? fileType;
  final String? parentType; // 'character', 'setting', 'reference', 'location', etc.

  FileTreeNode({
    required this.id,
    required this.name,
    this.content,
    this.children = const [],
    this.isFolder = false,
    this.isExpanded = false,
    this.fileType,
    this.parentType,
  });
}

/// 层级文件树组件（类似VSCode工作树）
class FileTreeView extends StatelessWidget {
  final List<FileTreeNode> nodes;
  final Function(FileTreeNode)? onNodeTap;
  final Function(FileTreeNode)? onNodeLongPress;
  final Function(FileTreeNode)? onToggleExpand;

  const FileTreeView({
    super.key,
    required this.nodes,
    this.onNodeTap,
    this.onNodeLongPress,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _flattenNodes(nodes).length,
      itemBuilder: (context, index) {
        final item = _flattenNodes(nodes)[index];
        return _buildNodeItem(item.node, item.level);
      },
    );
  }

  List<({FileTreeNode node, int level})> _flattenNodes(List<FileTreeNode> nodes, {int level = 0}) {
    final result = <({FileTreeNode node, int level})>[];
    for (final node in nodes) {
      result.add((node: node, level: level));
      if (node.isFolder && node.isExpanded) {
        result.addAll(_flattenNodes(node.children, level: level + 1));
      }
    }
    return result;
  }

  Widget _buildNodeItem(FileTreeNode node, int level) {
    final indent = level * 20.0;
    
    return InkWell(
      onTap: () {
        if (node.isFolder) {
          onToggleExpand?.call(node);
        } else {
          onNodeTap?.call(node);
        }
      },
      onLongPress: () => onNodeLongPress?.call(node),
      child: Container(
        padding: EdgeInsets.only(left: 8 + indent, right: 16, top: 8, bottom: 8),
        child: Row(
          children: [
            // 展开/折叠箭头或文件图标
            if (node.isFolder)
              Icon(
                node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                size: 20,
                color: Colors.grey[600],
              )
            else
              Icon(
                _getFileIcon(node.fileType),
                size: 18,
                color: _getFileColor(node.fileType),
              ),
            const SizedBox(width: 6),
            // 文件夹或文件名
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: node.isFolder ? FontWeight.w500 : FontWeight.normal,
                  color: node.isFolder ? Colors.grey[800] : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 文件类型标签
            if (!node.isFolder && node.fileType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getFileColor(node.fileType)!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  node.fileType!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getFileColor(node.fileType),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType) {
      case 'md':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color? _getFileColor(String? fileType) {
    switch (fileType) {
      case 'md':
        return Colors.blue[600];
      case 'txt':
        return Colors.green[600];
      default:
        return Colors.grey[600];
    }
  }
}
