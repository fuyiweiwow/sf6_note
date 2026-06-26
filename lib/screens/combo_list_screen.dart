import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/combo.dart';
import '../models/entry.dart';
import '../models/move_step.dart';
import '../providers/app_data_provider.dart';
import 'combo_editor_screen.dart';

/// Shows all combos within an entry.
class ComboListScreen extends ConsumerStatefulWidget {
  const ComboListScreen({
    super.key,
    required this.characterId,
    required this.entryId,
  });

  final String characterId;
  final String entryId;

  @override
  ConsumerState<ComboListScreen> createState() => _ComboListScreenState();
}

class _ComboListScreenState extends ConsumerState<ComboListScreen> {
  int _displayMode = 0; // 0=normal, 1=direction, 2=numpad, 3=mixed

  Future<void> _showAddComboDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建招式'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '招式名称（可选）',
            hintText: '例如: 基础连段',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) {
      ref.read(appDataProvider.notifier).addCombo(widget.characterId, widget.entryId);
      final data = ref.read(appDataProvider);
      for (final c in data.characters) {
        if (c.id == widget.characterId) {
          for (final e in c.entries) {
            if (e.id == widget.entryId && e.combos.isNotEmpty) {
              final newCombo = e.combos.last;
              if (name.isNotEmpty) {
                ref.read(appDataProvider.notifier).renameCombo(
                      widget.characterId, widget.entryId, newCombo.id, name,
                    );
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final data = ref.watch(appDataProvider);

    // Safe lookup
    final characterIdx = data.characters.indexWhere((c) => c.id == widget.characterId);
    if (characterIdx < 0) {
      return Scaffold(appBar: AppBar(title: const Text('条目')), body: Center(child: Text('人物不存在')));
    }
    final character = data.characters[characterIdx];
    final entryIdx = character.entries.indexWhere((e) => e.id == widget.entryId);
    if (entryIdx < 0) {
      return Scaffold(appBar: AppBar(title: const Text('条目')), body: Center(child: Text('条目不存在')));
    }
    final entry = character.entries[entryIdx];
    // Templates a combo can reference: globals + this character's own.
    final effectiveTemplates =
        ref.read(appDataProvider.notifier).effectiveTemplates(widget.characterId);

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.displayName),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
        actions: [
          // Display mode toggle: cycles normal → direction → numpad → mixed
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(switch (_displayMode) {
                0 => Icons.visibility_off,
                1 => Icons.arrow_outward,
                2 => Icons.filter_9_plus,
                3 => Icons.view_column,
                _ => Icons.visibility_off,
              }),
              tooltip: switch (_displayMode) {
                0 => '详细模式: 方向',
                1 => '详细模式: 数字',
                2 => '详细模式: 混合',
                _ => '普通模式',
              },
              onPressed: () => setState(() {
                _displayMode = (_displayMode + 1) % 4;
              }),
            ),
          ),
          if (entry.type == EntryType.custom)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除条目',
              onPressed: () {
                ref.read(appDataProvider.notifier).removeEntry(widget.characterId, widget.entryId);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      backgroundColor: Colors.white,
      body: entry.combos.isEmpty
          ? Center(
              child: Text('还没有招式，点击 + 添加',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 15)))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: entry.combos.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(appDataProvider.notifier)
                    .reorderCombos(widget.characterId, widget.entryId, oldIndex, newIndex);
              },
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, _) => Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                  child: child,
                ),
              ),
              itemBuilder: (context, index) {
                final combo = entry.combos[index];
                return _ComboCard(
                  key: ValueKey(combo.id),
                  combo: combo,
                  index: index,
                  displayMode: _displayMode,
                  templates: effectiveTemplates,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComboEditorScreen(
                          characterId: widget.characterId,
                          entryId: widget.entryId,
                          comboId: combo.id,
                        ),
                      ),
                    );
                  },
                  onDuplicate: combo.locked
                      ? null
                      : () => ref
                          .read(appDataProvider.notifier)
                          .duplicateCombo(widget.characterId, widget.entryId, combo.id),
                  onDelete: combo.locked
                      ? null
                      : () => ref
                          .read(appDataProvider.notifier)
                          .removeCombo(widget.characterId, widget.entryId, combo.id),
                  onToggleLock: () => ref
                      .read(appDataProvider.notifier)
                      .toggleComboLock(widget.characterId, widget.entryId, combo.id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddComboDialog(context, ref),
        backgroundColor: Colors.grey.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({
    super.key,
    required this.combo,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onToggleLock,
    required this.templates,
    this.onDuplicate,
    this.displayMode = 0,
  });

  final Combo combo;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback onToggleLock;
  final List templates;
  final int displayMode;

  /// Build Flutter TextSpans for the detailed display modes (1/2/3) honoring
  /// template colors and attack-strength colors.
  static List<InlineSpan> _coloredSpansFor(
      List<MoveStep> notation, List templates, int displayMode) {
    List<InlineSpan> toSpans(ColoredText ct) => ct.spans
        .map((s) => TextSpan(
              text: s.text,
              style: TextStyle(
                color: s.color == null ? Colors.black : Color(s.color!),
              ),
            ))
        .toList();
    switch (displayMode) {
      case 2:
        return toSpans(buildColoredNotation(notation, templates, useNumpad: true));
      case 3:
        final dir = toSpans(buildColoredNotation(notation, templates, useNumpad: false));
        final num = toSpans(buildColoredNotation(notation, templates, useNumpad: true));
        return [...dir, const TextSpan(text: '\n'), ...num];
      default: // 1
        return toSpans(buildColoredNotation(notation, templates, useNumpad: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        onLongPress: combo.locked ? null : onDelete,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey.shade400),
                ),
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (combo.notation.isNotEmpty)
                      displayMode == 0
                          ? Text(
                              combo.preview,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          : RichText(
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(fontSize: 14, color: Colors.black),
                                children: _coloredSpansFor(
                                  combo.notation,
                                  templates,
                                  displayMode,
                                ),
                              ),
                            ),
                    if (combo.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(combo.notes,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(combo.locked ? Icons.lock : Icons.lock_open,
                    size: 18, color: combo.locked ? Colors.orange.shade400 : Colors.grey.shade400),
                onPressed: onToggleLock,
                tooltip: combo.locked ? '解锁招式' : '锁定招式',
              ),
              if (!combo.locked) ...[
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: Colors.grey.shade400),
                  onPressed: onDuplicate,
                  tooltip: '复制招式',
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                  onPressed: onDelete,
                  tooltip: '删除招式',
                ),
              ],
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
