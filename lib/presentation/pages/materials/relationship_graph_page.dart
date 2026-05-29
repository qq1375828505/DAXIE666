import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/material_models.dart';
import 'package:novel_ide/data/models/character_relationship.dart';
import 'package:novel_ide/data/repositories/material_repository.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

const _nodeRadius = 40.0;
const _labelOffset = 8.0;
const _arrowSize = 10.0;

class RelationshipGraphPage extends ConsumerStatefulWidget {
  final String novelId;
  final String novelTitle;
  const RelationshipGraphPage({
    super.key,
    required this.novelId,
    required this.novelTitle,
  });
  @override
  ConsumerState<RelationshipGraphPage> createState() =>
      _RelationshipGraphPageState();
}

class _RelationshipGraphPageState extends ConsumerState<RelationshipGraphPage> {
  String? _selectedNodeId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final repo = MaterialRepository();
    final graphData = await repo.getRelationshipGraphData(widget.novelId);
    if (!mounted) return;
    ref.read(relationshipsProvider(widget.novelId).notifier).state =
        graphData.relationships;
    final posMap = <String, Offset>{};
    for (final p in graphData.positions) {
      posMap[p.characterId] = Offset(p.x, p.y);
    }
    final characters = ref.read(charactersProvider(widget.novelId));
    if (posMap.isEmpty && characters.isNotEmpty) {
      _assignCircleLayout(characters, posMap);
    }
    ref.read(relationshipPositionsProvider(widget.novelId).notifier).state =
        posMap;
  }

  void _assignCircleLayout(
    List<Character> characters,
    Map<String, Offset> posMap,
  ) {
    const center = Offset(600, 500);
    final radius = max(150.0, characters.length * 50.0);
    for (var i = 0; i < characters.length; i++) {
      final angle = 2 * pi * i / characters.length - pi / 2;
      posMap[characters[i].id] = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    }
  }

  Future<void> _saveData() async {
    final repo = MaterialRepository();
    final relationships = ref.read(relationshipsProvider(widget.novelId));
    final positions = ref.read(relationshipPositionsProvider(widget.novelId));
    final posList = positions.entries
        .map(
          (e) => RelationshipNodePosition(
            characterId: e.key,
            x: e.value.dx,
            y: e.value.dy,
          ),
        )
        .toList();
    await repo.saveRelationshipGraphData(
      widget.novelId,
      RelationshipGraphData(relationships: relationships, positions: posList),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('关系图已保存'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final characters = ref.watch(charactersProvider(widget.novelId));
    final relationships = ref.watch(relationshipsProvider(widget.novelId));
    final positions = ref.watch(relationshipPositionsProvider(widget.novelId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.novelTitle} - 角色关系图'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _saveData,
          ),
        ],
      ),
      body: characters.isEmpty
          ? _buildEmptyState()
          : InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.3,
              maxScale: 3.0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final hitNode = _hitTestNode(
                    details.localPosition,
                    characters,
                    positions,
                  );
                  if (hitNode == null) setState(() => _selectedNodeId = null);
                },
                child: CustomPaint(
                  painter: _RelationshipGraphPainter(
                    characters: characters,
                    relationships: relationships,
                    positions: positions,
                    selectedNodeId: _selectedNodeId,
                    isDark: isDark,
                  ),
                  size: const Size(2000, 1600),
                  child: Stack(
                    children: characters.map((c) {
                      final pos = positions[c.id] ?? Offset.zero;
                      return _buildNodeWidget(c, pos);
                    }).toList(),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCharacterDialog,
        tooltip: '添加角色节点',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            '暂无角色，请先添加角色',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回资料库'),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(Character character, Offset position) {
    final isSelected = _selectedNodeId == character.id;
    final nodeColor = Color(colorForRole(character.role));
    final avatar = character.name.isNotEmpty ? character.name[0] : '?';
    return Positioned(
      left: position.dx - _nodeRadius,
      top: position.dy - _nodeRadius,
      child: GestureDetector(
        onTap: () => _onNodeTap(character),
        onLongPress: () => _showNodeContextMenu(character),
        onPanStart: (_) {},
        onPanUpdate: (details) => _onDragUpdate(character, details.delta),
        onPanEnd: (_) {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _nodeRadius * 2,
              height: _nodeRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nodeColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: isSelected ? AppColors.primary : nodeColor,
                  width: isSelected ? 3.0 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: nodeColor.withValues(alpha: 0.3),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  avatar,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: nodeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _labelOffset),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                character.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNodeTap(Character character) {
    setState(() {
      if (_selectedNodeId == null) {
        _selectedNodeId = character.id;
      } else if (_selectedNodeId == character.id) {
        _selectedNodeId = null;
      } else {
        _showCreateRelationshipDialog(_selectedNodeId!, character.id);
      }
    });
  }

  void _onDragUpdate(Character character, Offset delta) {
    final positions = ref.read(relationshipPositionsProvider(widget.novelId));
    final currentPos = positions[character.id] ?? Offset.zero;
    ref.read(relationshipPositionsProvider(widget.novelId).notifier).state = {
      ...positions,
      character.id: currentPos + delta,
    };
  }

  String? _hitTestNode(
    Offset point,
    List<Character> characters,
    Map<String, Offset> positions,
  ) {
    for (final c in characters.reversed) {
      final pos = positions[c.id] ?? Offset.zero;
      if ((point - pos).distance <= _nodeRadius) return c.id;
    }
    return null;
  }

  void _showNodeContextMenu(Character character) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑角色'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请在资料库中编辑${character.name}的角色信息')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('连接到其他角色'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _selectedNodeId = character.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请点击另一个角色建立连接'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除节点', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCharacterNode(character);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCharacterNode(Character character) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除角色节点'),
        content: Text('确定从关系图中移除${character.name}？(不会删除角色数据)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final rels = ref.read(relationshipsProvider(widget.novelId));
    ref.read(relationshipsProvider(widget.novelId).notifier).state = rels
        .where(
          (r) =>
              r.fromCharacterId != character.id &&
              r.toCharacterId != character.id,
        )
        .toList();
    final positions = Map<String, Offset>.from(
      ref.read(relationshipPositionsProvider(widget.novelId)),
    );
    positions.remove(character.id);
    ref.read(relationshipPositionsProvider(widget.novelId).notifier).state =
        positions;
    setState(() {
      if (_selectedNodeId == character.id) _selectedNodeId = null;
    });
  }

  void _showCreateRelationshipDialog(String fromId, String toId) {
    final characters = ref.read(charactersProvider(widget.novelId));
    final fromChar = characters.where((c) => c.id == fromId).firstOrNull;
    final toChar = characters.where((c) => c.id == toId).firstOrNull;
    if (fromChar == null || toChar == null) return;
    final existing = ref
        .read(relationshipsProvider(widget.novelId))
        .where(
          (r) =>
              (r.fromCharacterId == fromId && r.toCharacterId == toId) ||
              (r.fromCharacterId == toId && r.toCharacterId == fromId),
        )
        .toList();
    if (existing.isNotEmpty) {
      setState(() => _selectedNodeId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('这两个角色已有关系连接'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final descCtrl = TextEditingController();
    String selectedType = '同门';
    final presetTypes = [
      '父女',
      '父子',
      '母子',
      '母女',
      '兄弟',
      '姐妹',
      '师徒',
      '同门',
      '恋人',
      '夫妻',
      '敌人',
      '对手',
      '盟友',
      '朋友',
      '上下级',
      '主仆',
      '宿敌',
      '暗恋',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${fromChar.name} -> ${toChar.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择关系类型：',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presetTypes
                      .map(
                        (type) => ChoiceChip(
                          label: Text(
                            type,
                            style: const TextStyle(fontSize: 13),
                          ),
                          selected: selectedType == type,
                          onSelected: (_) =>
                              setDialogState(() => selectedType = type),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '补充说明关系详情',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedNodeId = null);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final rel = CharacterRelationship(
                  id: const Uuid().v4(),
                  fromCharacterId: fromId,
                  toCharacterId: toId,
                  relationType: selectedType,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
                ref.read(relationshipsProvider(widget.novelId).notifier).state =
                    [...ref.read(relationshipsProvider(widget.novelId)), rel];
                Navigator.pop(ctx);
                setState(() => _selectedNodeId = null);
              },
              child: const Text('创建关系'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCharacterDialog() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加角色到关系图'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  final characters = ref.read(
                    charactersProvider(widget.novelId),
                  );
                  final positions = ref.read(
                    relationshipPositionsProvider(widget.novelId),
                  );
                  final unpositioned = characters
                      .where((c) => !positions.containsKey(c.id))
                      .toList();
                  if (unpositioned.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '已有角色（点击添加到图中）：',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        ...unpositioned.map(
                          (c) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(
                                colorForRole(c.role),
                              ).withValues(alpha: 0.2),
                              child: Text(
                                c.name.isNotEmpty ? c.name[0] : '?',
                                style: TextStyle(
                                  color: Color(colorForRole(c.role)),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(c.name),
                            subtitle: c.role != null ? Text(c.role!) : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _addExistingCharacterToGraph(c);
                            },
                          ),
                        ),
                        const Divider(height: 24),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const Text(
                '或创建新角色：',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '角色名'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: '定位',
                  hintText: '主角/女主/反派/配角',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _createNewCharacterAndAdd(
                nameCtrl.text.trim(),
                roleCtrl.text.trim().isEmpty ? null : roleCtrl.text.trim(),
              );
            },
            child: const Text('新建并添加'),
          ),
        ],
      ),
    );
  }

  void _addExistingCharacterToGraph(Character character) {
    final positions = Map<String, Offset>.from(
      ref.read(relationshipPositionsProvider(widget.novelId)),
    );
    const center = Offset(600, 500);
    final n = positions.length;
    final angle = 2 * pi * n / max(1, n + 1) - pi / 2;
    final radius = max(150.0, (n + 1) * 50.0);
    positions[character.id] = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    ref.read(relationshipPositionsProvider(widget.novelId).notifier).state =
        positions;
  }

  void _createNewCharacterAndAdd(String name, String? role) async {
    final character = Character(
      id: const Uuid().v4(),
      novelId: widget.novelId,
      name: name,
      role: role,
    );
    final list = ref.read(charactersProvider(widget.novelId));
    final newList = [...list, character];
    ref.read(charactersProvider(widget.novelId).notifier).state = newList;
    await MaterialRepository().saveCharacters(widget.novelId, newList);
    _addExistingCharacterToGraph(character);
  }
}

class _RelationshipGraphPainter extends CustomPainter {
  final List<Character> characters;
  final List<CharacterRelationship> relationships;
  final Map<String, Offset> positions;
  final String? selectedNodeId;
  final bool isDark;

  _RelationshipGraphPainter({
    required this.characters,
    required this.relationships,
    required this.positions,
    this.selectedNodeId,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final rel in relationships) {
      final fromPos = positions[rel.fromCharacterId];
      final toPos = positions[rel.toCharacterId];
      if (fromPos == null || toPos == null) continue;
      _drawEdge(canvas, fromPos, toPos, rel);
    }
  }

  void _drawEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    CharacterRelationship rel,
  ) {
    final lineStyle = lineStyleForType(rel.relationType);
    final color = isDark ? Colors.white70 : Colors.grey[600]!;
    final direction = to - from;
    final distance = direction.distance;
    if (distance < 1) return;
    final unitDir = direction / distance;
    final startPt = from + unitDir * _nodeRadius;
    final endPt = to - unitDir * _nodeRadius;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    switch (lineStyle) {
      case RelationLineStyle.solid:
        canvas.drawLine(startPt, endPt, paint);
        break;
      case RelationLineStyle.dashed:
        _drawDashedLine(canvas, startPt, endPt, paint, dashLength: 8);
        break;
      case RelationLineStyle.dotted:
        _drawDashedLine(canvas, startPt, endPt, paint, dashLength: 3);
        break;
    }
    _drawArrow(canvas, endPt, unitDir, color);
    _drawLabel(canvas, (startPt + endPt) / 2, rel.relationType);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    required double dashLength,
  }) {
    final direction = to - from;
    final distance = direction.distance;
    final unitDir = direction / distance;
    var covered = 0.0;
    while (covered < distance) {
      final start = from + unitDir * covered;
      final endDist = min(covered + dashLength, distance);
      canvas.drawLine(start, from + unitDir * endDist, paint);
      covered = endDist + dashLength;
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset direction, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final perp = Offset(-direction.dy, direction.dx);
    final p2 = tip - direction * _arrowSize + perp * (_arrowSize * 0.4);
    final p3 = tip - direction * _arrowSize - perp * (_arrowSize * 0.4);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Offset center, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: textPainter.width + padding.horizontal,
        height: textPainter.height + padding.vertical,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = isDark
            ? const Color(0xFF3A3A5C)
            : Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = isDark ? Colors.white24 : Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _RelationshipGraphPainter oldDelegate) {
    return oldDelegate.relationships != relationships ||
        oldDelegate.positions != positions ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.isDark != isDark;
  }
}
