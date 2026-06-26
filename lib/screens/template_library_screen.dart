import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/character.dart';
import '../models/move_template.dart';
import '../providers/app_data_provider.dart';
import 'template_editor_screen.dart';

/// Dedicated page that lists ALL move templates in one place.
///
/// Shown from two entry points:
///   * HomeScreen AppBar → manage global templates only
///   * CharacterScreen AppBar → manage global + that character's templates
///
/// [characterId] controls which character scope is shown alongside the
/// global group. null = "global only" mode (launched from the home page).
class TemplateLibraryScreen extends ConsumerWidget {
  const TemplateLibraryScreen({super.key, this.characterId});

  /// Character whose templates are shown; null for global-only mode.
  final String? characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final globals = data.globalTemplates;
    final owner = _findOwner(data.characters);

    return Scaffold(
      appBar: AppBar(
        title: Text(owner == null ? '通用招式模板' : '招式模板 · ${owner.name}'),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _GlobalGroup(
            templates: globals,
            onCreate: () => _createTemplate(context, ref, null),
            onOpen: (t) => _openEditor(context, t, null),
            onDelete: (t) => _confirmDelete(context, ref, null, t),
            onRelocate: (t) => _moveGlobalToCharacter(context, ref, t),
          ),
          if (owner != null) ...[
            const SizedBox(height: 8),
            _CharacterGroup(
              character: owner,
              templates: owner.templates,
              onCreate: () => _createTemplate(context, ref, owner.id),
              onOpen: (t) => _openEditor(context, t, owner.id),
              onDelete: (t) => _confirmDelete(context, ref, owner.id, t),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              owner == null
                  ? '通用模板对所有角色可见。在角色页面可把通用模板转为某角色的专属模板。'
                  : '「通用模板」对所有角色可见；「本角色专属」仅当前角色可见，可转为通用。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTemplate(context, ref, owner?.id),
        backgroundColor: Colors.grey.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Resolve the owner character, tolerating a stale/removed id.
  Character? _findOwner(List<Character> characters) {
    if (characterId == null) return null;
    for (final c in characters) {
      if (c.id == characterId) return c;
    }
    return null;
  }

  Future<void> _createTemplate(
    BuildContext context,
    WidgetRef ref,
    String? ownerId,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ownerId == null ? '新建通用模板' : '新建专属模板'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '模板名称',
            hintText: '例如: 波动拳',
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
    if (name == null) return;

    final notifier = ref.read(appDataProvider.notifier);
    final tmpl = MoveTemplate(name: name);
    notifier.addTemplate(ownerId, tmpl);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TemplateEditorScreen(
            characterId: ownerId,
            templateId: tmpl.id,
          ),
        ),
      );
    }
  }

  void _openEditor(BuildContext context, MoveTemplate t, String? ownerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(
          characterId: ownerId,
          templateId: t.id,
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String? ownerId,
    MoveTemplate t,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除模板「${t.displayText}」？'),
        content: Text(ownerId == null ? '这是通用模板，删除后所有角色都不再可见。' : '将删除该角色的此模板。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(appDataProvider.notifier).removeTemplate(ownerId, t.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Move a global template into a chosen character's scope.
  Future<void> _moveGlobalToCharacter(
    BuildContext context,
    WidgetRef ref,
    MoveTemplate t,
  ) async {
    final data = ref.read(appDataProvider);
    if (data.characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有人物，无法转为专属')),
      );
      return;
    }
    final destId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('转为哪个角色的专属模板？'),
        children: data.characters
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c.id),
                  child: Text(c.name),
                ))
            .toList(),
      ),
    );
    if (destId == null) return;
    ref.read(appDataProvider.notifier).relocateTemplate(null, destId, t.id);
  }
}

/// Section showing the global (all-character) templates.
class _GlobalGroup extends StatelessWidget {
  const _GlobalGroup({
    required this.templates,
    required this.onCreate,
    required this.onOpen,
    required this.onDelete,
    required this.onRelocate,
  });

  final List<MoveTemplate> templates;
  final VoidCallback onCreate;
  final void Function(MoveTemplate) onOpen;
  final void Function(MoveTemplate) onDelete;
  final void Function(MoveTemplate) onRelocate;

  @override
  Widget build(BuildContext context) {
    return _GroupCard(
      icon: Icons.public,
      iconColor: Colors.blue.shade700,
      title: '通用模板',
      subtitle: '对所有角色可见',
      count: templates.length,
      emptyHint: '还没有通用模板，点击 + 新建',
      templates: templates,
      onOpen: onOpen,
      onDelete: onDelete,
      onRelocate: onRelocate,
      onCreate: onCreate,
    );
  }
}

/// Section showing one character's own templates.
class _CharacterGroup extends StatelessWidget {
  const _CharacterGroup({
    required this.character,
    required this.templates,
    required this.onCreate,
    required this.onOpen,
    required this.onDelete,
  });

  final Character character;
  final List<MoveTemplate> templates;
  final VoidCallback onCreate;
  final void Function(MoveTemplate) onOpen;
  final void Function(MoveTemplate) onDelete;

  @override
  Widget build(BuildContext context) {
    return _GroupCard(
      icon: Icons.person_outline,
      iconColor: Colors.purple.shade700,
      title: '「${character.name}」专属',
      subtitle: '仅该角色可见',
      count: templates.length,
      emptyHint: '还没有专属模板',
      templates: templates,
      onOpen: onOpen,
      onDelete: onDelete,
      onCreate: onCreate,
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.emptyHint,
    required this.templates,
    required this.onOpen,
    required this.onDelete,
    required this.onCreate,
    this.onRelocate,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int count;
  final String emptyHint;
  final List<MoveTemplate> templates;
  final void Function(MoveTemplate) onOpen;
  final void Function(MoveTemplate) onDelete;
  final VoidCallback onCreate;
  final void Function(MoveTemplate)? onRelocate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: templates
                    .map((t) => _TemplateChipTile(
                          template: t,
                          iconColor: iconColor,
                          onTap: () => onOpen(t),
                          onLongPress: () => onDelete(t),
                          trailing: onRelocate == null
                              ? null
                              : IconButton(
                                  tooltip: '转为专属',
                                  icon: const Icon(Icons.account_circle_outlined,
                                      size: 20),
                                  padding: const EdgeInsets.only(left: 4),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  onPressed: () => onRelocate!(t),
                                ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChipTile extends StatelessWidget {
  const _TemplateChipTile({
    required this.template,
    required this.iconColor,
    required this.onTap,
    required this.onLongPress,
    this.trailing,
  });

  final MoveTemplate template;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Larger padding/font so each chip is a comfortable touch target.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: iconColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: template.colorValue == null
                    ? Colors.black
                    : Color(template.colorValue!),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              template.name.isNotEmpty ? template.name : template.stepsPreview,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
