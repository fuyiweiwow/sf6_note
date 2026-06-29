import 'package:flutter/material.dart';

import '../models/app_data.dart';
import '../models/move_template.dart';
import 'template_chip.dart';

/// The template picker shown at the bottom of the combo editor.
///
/// Renders templates in two collapsible groups (通用 / 本角色). Within a group,
/// when there are more than [_pageSize] templates it paginates — showing
/// "< >"  controls — so a long list never eats the whole editing area on
/// phones. Chips remain draggable into the notation area above.
///
/// All grouping/pagination state lives here, keeping the editor's own state
/// clean. The callbacks mirror what the editor needs (delete, promote to
/// global); the drop itself is handled by the editor's DragTarget.
class TemplatePickerPanel extends StatefulWidget {
  const TemplatePickerPanel({
    super.key,
    required this.appData,
    required this.characterId,
    required this.onDeleteTemplate,
    required this.onMoveToGlobal,
    this.onCreateTemplate,
    this.compact = false,
  });

  final AppData appData;
  final String characterId;

  /// (ownerId, template) — ownerId is null for global templates.
  final void Function(String? ownerId, MoveTemplate t) onDeleteTemplate;
  final void Function(MoveTemplate t) onMoveToGlobal;

  /// Create a new template right from the combo editor (so the user doesn't
  /// have to leave to the template library when a needed template is missing).
  /// ownerId: null = global, otherwise the character id. [templateName] is the
  /// trimmed name the user typed. The editor handles creation + navigation.
  final void Function(String? ownerId, String templateName)? onCreateTemplate;

  /// Compact mode: used in the wide-screen inline column (no "模板" title).
  final bool compact;

  @override
  State<TemplatePickerPanel> createState() => _TemplatePickerPanelState();
}

class _TemplatePickerPanelState extends State<TemplatePickerPanel> {
  static const int _pageSize = 10;

  // Per-group pagination index (keyed by group label).
  final Map<String, int> _pages = {'通用': 0, '本角色': 0};
  // Per-group collapsed state. Default expanded so users see everything first.
  final Map<String, bool> _collapsed = {'通用': false, '本角色': false};

  @override
  Widget build(BuildContext context) {
    final globals = _globals();
    final owns = _owns();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (!widget.compact) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('模板',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600)),
              if (widget.onCreateTemplate != null) ...[
                const SizedBox(width: 8),
                _createButton(),
              ],
            ],
          ),
          const SizedBox(height: 4),
        ] else if (widget.onCreateTemplate != null) ...[
          // Compact (wide-screen inline column): show the create button alone
          // at the top since there's no "模板" title row.
          Align(alignment: Alignment.centerLeft, child: _createButton()),
          const SizedBox(height: 4),
        ],
        if (globals.isEmpty && owns.isEmpty)
          Center(
            child: Text(
              widget.compact ? '选区后保存为模板，或点上方 + 新建' : '还没有模板，点上方 + 新建或选区后保存',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          )
        else ...[
          if (globals.isNotEmpty)
            _group(
              label: '通用',
              iconColor: Colors.blue.shade700,
              templates: globals,
              canMoveToGlobal: false,
            ),
          if (globals.isNotEmpty && owns.isNotEmpty)
            SizedBox(height: widget.compact ? 4 : 6),
          if (owns.isNotEmpty)
            _group(
              label: '本角色',
              iconColor: Colors.purple.shade700,
              templates: owns,
              canMoveToGlobal: true,
            ),
        ],
      ],
    );
  }

  List<MoveTemplate> _globals() {
    final all = _effective();
    return all
        .where((t) => widget.appData.globalTemplates.any((g) => g.id == t.id))
        .toList();
  }

  List<MoveTemplate> _owns() {
    final all = _effective();
    return all
        .where((t) => !widget.appData.globalTemplates.any((g) => g.id == t.id))
        .toList();
  }

  /// Effective templates for this character = globals + its own.
  List<MoveTemplate> _effective() {
    for (final c in widget.appData.characters) {
      if (c.id == widget.characterId) {
        return [...widget.appData.globalTemplates, ...c.templates];
      }
    }
    return [...widget.appData.globalTemplates];
  }

  /// Resolve which scope owns [t] so deletes target the right list.
  String? _ownerOf(MoveTemplate t) {
    if (widget.appData.globalTemplates.any((g) => g.id == t.id)) return null;
    return widget.characterId;
  }

  Widget _group({
    required String label,
    required Color iconColor,
    required List<MoveTemplate> templates,
    required bool canMoveToGlobal,
  }) {
    final collapsed = _collapsed[label] ?? false;
    final totalPages = (templates.length / _pageSize).ceil();
    // Clamp current page in case the list shrank.
    var page = _pages[label] ?? 0;
    if (page >= totalPages) page = totalPages - 1;
    if (page < 0) page = 0;
    _pages[label] = page;
    final showPager = totalPages > 1;
    final pageItems = showPager
        ? templates.skip(page * _pageSize).take(_pageSize).toList()
        : templates;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: icon + label + count, with a collapse toggle.
        InkWell(
          onTap: () => setState(() => _collapsed[label] = !collapsed),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  canMoveToGlobal ? Icons.person_outline : Icons.public,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: iconColor)),
                const SizedBox(width: 4),
                Text('${templates.length}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 2),
                Icon(
                  collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pageItems.map((t) => _chip(t, canMoveToGlobal)).toList(),
          ),
          if (showPager)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pagerButton(
                    icon: Icons.chevron_left,
                    enabled: page > 0,
                    onTap: () => setState(() => _pages[label] = page - 1),
                  ),
                  Text(' ${page + 1}/$totalPages ',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  _pagerButton(
                    icon: Icons.chevron_right,
                    enabled: page < totalPages - 1,
                    onTap: () => setState(() => _pages[label] = page + 1),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _pagerButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon,
            size: 18,
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
    );
  }

  /// Small "新建" button that opens the create-template dialog.
  Widget _createButton() {
    return TextButton.icon(
      onPressed: _showCreateDialog,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('新建', style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  /// Prompt for a template name + scope (本角色 / 通用), then hand off to the
  /// editor's onCreateTemplate callback which creates it and opens the editor.
  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    // Default scope: per-character (the common case when filling in combos).
    var asGlobal = false;

    final result = await showDialog<({String name, bool asGlobal})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('新建招式模板'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '模板名称',
                      hintText: '例如: 波动拳',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('归属',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    groupValue: asGlobal,
                    title: const Text('本角色专属'),
                    onChanged: (v) =>
                        setDialogState(() => asGlobal = v ?? false),
                  ),
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: true,
                    groupValue: asGlobal,
                    title: const Text('通用（对所有角色可见）'),
                    onChanged: (v) =>
                        setDialogState(() => asGlobal = v ?? true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                TextButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(ctx, (name: name, asGlobal: asGlobal));
                    }
                  },
                  child: const Text('新建并编辑'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    final ownerId = result.asGlobal ? null : widget.characterId;
    widget.onCreateTemplate?.call(ownerId, result.name);
  }

  Widget _chip(MoveTemplate t, bool canMoveToGlobal) {
    final ownerId = _ownerOf(t);
    return TemplateChip(
      template: t,
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('删除模板「${t.displayText}」？'),
            content: Text(ownerId == null
                ? '这是通用模板，删除后所有角色都不再可见。'
                : '将删除该角色的此模板。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消')),
              TextButton(
                onPressed: () {
                  widget.onDeleteTemplate(ownerId, t);
                  Navigator.pop(ctx);
                },
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      badge: canMoveToGlobal
          ? GestureDetector(
              onTap: () => widget.onMoveToGlobal(t),
              behavior: HitTestBehavior.opaque,
              child: Tooltip(
                message: '转为通用模板',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.public,
                      size: 16, color: Colors.blue.shade700),
                ),
              ),
            )
          : null,
    );
  }
}
