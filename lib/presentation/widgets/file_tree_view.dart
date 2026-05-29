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
  final String? parentType;
  final IconData? icon;
  final Color? iconColor;
  final String? badge;
  final Color? badgeColor;
  final String? trailing;

  FileTreeNode({
    required this.id,
    required this.name,
    this.content,
    this.children = const [],
    this.isFolder = false,
    this.isExpanded = false,
    this.fileType,
    this.parentType,
    this.icon,
    this.iconColor,
    this.badge,
    this.badgeColor,
    this.trailing,
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
    final items = _flattenNodes(nodes);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildNodeItem(context, item.node, item.level);
      },
    );
  }

  List<({FileTreeNode node, int level})> _flattenNodes(
    List<FileTreeNode> nodes, {
    int level = 0,
  }) {
    final result = <({FileTreeNode node, int level})>[];
    for (final node in nodes) {
      result.add((node: node, level: level));
      if (node.isFolder && node.isExpanded) {
        result.addAll(_flattenNodes(node.children, level: level + 1));
      }
    }
    return result;
  }

  Widget _buildNodeItem(BuildContext context, FileTreeNode node, int level) {
    final indent = level * 20.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderColor = isDark ? Colors.grey[300] : Colors.grey[800];
    final fileColor = isDark ? Colors.grey[400] : Colors.grey[700];

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
        padding: EdgeInsets.only(
          left: 8 + indent,
          right: 16,
          top: 7,
          bottom: 7,
        ),
        child: Row(
          children: [
            // 缩进引导线
            if (level > 0)
              ...List.generate(level, (i) {
                return Container(
                  width: 1,
                  margin: const EdgeInsets.only(right: 19),
                  color: (isDark ? Colors.grey[700] : Colors.grey[300]),
                );
              }),
            // 展开/折叠箭头或文件图标
            if (node.isFolder)
              Icon(
                node.isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 20,
                color: folderColor,
              )
            else if (node.icon != null)
              Icon(
                node.icon,
                size: 18,
                color: node.iconColor ?? (isDark ? Colors.grey[500] : Colors.grey[500]),
              )
            else
              Icon(
                _getFileIcon(node.fileType),
                size: 18,
                color: node.iconColor ?? _getFileColor(node.fileType, isDark),
              ),
            const SizedBox(width: 6),
            // 文件夹或文件名
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      node.isFolder ? FontWeight.w600 : FontWeight.normal,
                  color: node.isFolder ? folderColor : fileColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 状态 badge
            if (node.badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (node.badgeColor ?? Colors.grey).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  node.badge!,
                  style: TextStyle(
                    fontSize: 10,
                    color: node.badgeColor ?? Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            // 右侧统计信息
            if (node.trailing != null)
              Text(
                node.trailing!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            // 文件类型标签
            if (!node.isFolder &&
                node.fileType != null &&
                node.badge == null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      (_getFileColor(node.fileType, isDark) ?? Colors.grey)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  node.fileType!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getFileColor(node.fileType, isDark),
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

  Color? _getFileColor(String? fileType, bool isDark) {
    switch (fileType) {
      case 'md':
        return isDark ? Colors.blue[300] : Colors.blue[600];
      case 'txt':
        return isDark ? Colors.green[300] : Colors.green[600];
      default:
        return isDark ? Colors.grey[500] : Colors.grey[600];
    }
  }
}
