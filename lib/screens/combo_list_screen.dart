import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/combo.dart';
import '../models/entry.dart';
import '../providers/app_data_provider.dart';
import 'combo_editor_screen.dart';

/// Shows all combos within an entry.
class ComboListScreen extends ConsumerWidget {
  const ComboListScreen({
    super.key,
    required this.characterId,
    required this.entryId,
  });

  final String characterId;
  final String entryId;

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
      ref.read(appDataProvider.notifier).addCombo(characterId, entryId);
      final data = ref.read(appDataProvider);
      for (final c in data.characters) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId && e.combos.isNotEmpty) {
              final newCombo = e.combos.last;
              if (name.isNotEmpty) {
                ref.read(appDataProvider.notifier).renameCombo(
                      characterId, entryId, newCombo.id, name,
                    );
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);

    // Safe lookup
    final characterIdx = data.characters.indexWhere((c) => c.id == characterId);
    if (characterIdx < 0) {
      return Scaffold(appBar: AppBar(title: const Text('条目')), body: Center(child: Text('人物不存在')));
    }
    final character = data.characters[characterIdx];
    final entryIdx = character.entries.indexWhere((e) => e.id == entryId);
    if (entryIdx < 0) {
      return Scaffold(appBar: AppBar(title: const Text('条目')), body: Center(child: Text('条目不存在')));
    }
    final entry = character.entries[entryIdx];

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.displayName),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
        actions: [
          if (entry.type == EntryType.custom)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除条目',
              onPressed: () {
                ref.read(appDataProvider.notifier).removeEntry(characterId, entryId);
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
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: entry.combos.length,
              itemBuilder: (context, index) {
                final combo = entry.combos[index];
                return _ComboCard(
                  combo: combo,
                  index: index,
                  numpadMode: ref.read(appDataProvider.notifier).numpadMode,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComboEditorScreen(
                          characterId: characterId,
                          entryId: entryId,
                          comboId: combo.id,
                        ),
                      ),
                    );
                  },
                  onDelete: () => ref
                      .read(appDataProvider.notifier)
                      .removeCombo(characterId, entryId, combo.id),
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
    required this.combo,
    required this.index,
    required this.onTap,
    required this.onDelete,
    this.numpadMode = false,
  });

  final Combo combo;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool numpadMode;

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
                      Text(
                        numpadMode
                            ? (combo.name.isNotEmpty
                                ? combo.name
                                : combo.numpadNotationPreview)
                            : combo.preview,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
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
                icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
                onPressed: onDelete,
                tooltip: '删除招式',
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
