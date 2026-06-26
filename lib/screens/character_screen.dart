import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entry.dart';
import '../models/character.dart';
import '../providers/app_data_provider.dart';
import 'combo_list_screen.dart';
import 'template_library_screen.dart';
import '../services/pdf_export_service.dart';

class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({
    super.key,
    required this.characterId,
  });

  final String characterId;

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  Future<void> _showAddCustomEntryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建自定义条目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '条目名称',
            hintText: '例如: 防守反击连段',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) {
      ref.read(appDataProvider.notifier).addCustomEntry(widget.characterId, name);
    }
  }

  void _showPdfExportDialog(Character character) {
    final notifier = ref.read(appDataProvider.notifier);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择 PDF 导出模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...PdfNotationMode.values.map((mode) {
              final label = switch (mode) {
                PdfNotationMode.direction => '方向模式 (↑↘→LP)',
                PdfNotationMode.numpad => '数字模式 (236LP)',
                PdfNotationMode.mixed => '混合模式',
              };
              // groupValue is intentionally null: no default selection, so
              // tapping any option always fires onChanged (and exports),
              // even the one matching the last-used mode.
              return RadioListTile<PdfNotationMode>(
                title: Text(label),
                value: mode,
                groupValue: null,
                onChanged: (value) {
                  if (value != null) {
                    notifier.setPdfExportMode(value);
                    Navigator.pop(ctx);
                    PdfExportService().exportCharacter(
                      character,
                      value,
                      templates: notifier.effectiveTemplates(character.id),
                    );
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteCharacterDialog() {
    final data = ref.read(appDataProvider);
    final character = data.characters.firstWhere((c) => c.id == widget.characterId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除人物'),
        content: Text('确定要删除「${character.name}」及其所有招式数据吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(appDataProvider.notifier).removeCharacter(widget.characterId);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final character = data.characters.firstWhere((c) => c.id == widget.characterId);
    // Templates available to this character = globals + its own.
    final effectiveCount =
        data.globalTemplates.length + character.templates.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
        actions: [
          // Templates moved to a dedicated page so the entry list stays clean.
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '招式模板 ($effectiveCount)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TemplateLibraryScreen(
                    characterId: widget.characterId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: '导出PDF',
            onPressed: () => _showPdfExportDialog(character),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除人物',
            onPressed: _showDeleteCharacterDialog,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Entry list
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: character.entries.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(appDataProvider.notifier)
                    .reorderEntries(widget.characterId, oldIndex, newIndex);
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
                final entry = character.entries[index];
                return _EntryCard(
                  key: ValueKey(entry.id),
                  entry: entry,
                  index: index,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComboListScreen(
                          characterId: widget.characterId,
                          entryId: entry.id,
                        ),
                      ),
                    );
                  },
                  onDelete: entry.type == EntryType.custom
                      ? () => ref.read(appDataProvider.notifier).removeEntry(widget.characterId, entry.id)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomEntryDialog,
        backgroundColor: Colors.grey.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.onTap,
    this.onDelete,
  });

  final Entry entry;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBadgeColor(),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.type == EntryType.custom ? '自定义' : _getShortLabel(),
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('${entry.comboCount} 个招式',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                  onPressed: onDelete,
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBadgeColor() => switch (entry.type) {
        EntryType.lightStarter => Colors.blue.shade400,
        EntryType.mediumStarter => Colors.amber.shade500,
        EntryType.heavyStarter => Colors.red.shade400,
        EntryType.okizeme => Colors.orange.shade400,
        EntryType.punishCounter => Colors.purple.shade400,
        EntryType.wallCombo => Colors.teal.shade400,
        EntryType.custom => Colors.grey.shade500,
      };

  String _getShortLabel() => switch (entry.type) {
        EntryType.lightStarter => '轻起手',
        EntryType.mediumStarter => '中起手',
        EntryType.heavyStarter => '重起手',
        EntryType.okizeme => '压起身',
        EntryType.punishCounter => '确反',
        EntryType.wallCombo => '迸墙',
        EntryType.custom => '自定义',
      };
}
