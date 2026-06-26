import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_data.dart';
import '../models/move_template.dart';
import '../models/move_step.dart';
import '../providers/app_data_provider.dart';
import '../widgets/direction_button.dart';
import '../widgets/attack_button.dart';
import '../widgets/notation_drop_target.dart';
import '../widgets/template_chip.dart';

class ComboEditorScreen extends ConsumerStatefulWidget {
  const ComboEditorScreen({
    super.key,
    required this.characterId,
    required this.entryId,
    required this.comboId,
  });

  final String characterId;
  final String entryId;
  final String comboId;

  @override
  ConsumerState<ComboEditorScreen> createState() => _ComboEditorScreenState();
}

class _ComboEditorScreenState extends ConsumerState<ComboEditorScreen> {
  TextEditingController? _notesController;
  TextEditingController? _nameController;
  String _lastSyncedNotes = '';
  String _lastSyncedName = '';
  int? _selStart;
  int? _selEnd;
  int? _selAnchor; // first-tap anchor; null once a range is locked
  // Narrow-screen bottom panel: which pad is expanded (null = only tab row).
  int? _activePad;
  /// Safely find the combo in current state.
  dynamic _findCombo(AppData data) {
    for (final c in data.characters) {
      if (c.id == widget.characterId) {
        for (final e in c.entries) {
          for (final co in e.combos) {
            if (co.id == widget.comboId) return co;
          }
        }
      }
    }
    return null;
  }

  bool _isComboLocked() {
    final combo = _findCombo(ref.read(appDataProvider));
    return combo != null && (combo as dynamic).locked == true;
  }

  /// Get the templates available to this character: globals + its own.
  List<MoveTemplate> _getTemplates(AppData data) {
    final notifier = ref.read(appDataProvider.notifier);
    return notifier.effectiveTemplates(widget.characterId);
  }

  /// Resolve which scope owns [t] so deletes target the right list.
  /// Returns the owning character id, or null if it's a global template.
  String? _ownerOf(MoveTemplate t) {
    final data = ref.read(appDataProvider);
    if (data.globalTemplates.any((g) => g.id == t.id)) return null;
    return widget.characterId;
  }

  /// Sync the notes controller without triggering a loop.
  void _ensureController(String notes) {
    if (_notesController == null) {
      _notesController = TextEditingController(text: notes);
      _lastSyncedNotes = notes;
      _notesController!.addListener(_onNotesChanged);
    } else if (_notesController!.text != notes && _lastSyncedNotes != notes) {
      _lastSyncedNotes = notes;
      Future.microtask(() {
        if (mounted && _notesController != null) {
          _notesController!.text = notes;
        }
      });
    }
  }

  void _ensureNameController(String name) {
    if (_nameController == null) {
      _nameController = TextEditingController(text: name);
      _lastSyncedName = name;
      _nameController!.addListener(_onNameChanged);
    } else if (_nameController!.text != name && _lastSyncedName != name) {
      _lastSyncedName = name;
      Future.microtask(() {
        if (mounted && _nameController != null) {
          _nameController!.text = name;
        }
      });
    }
  }

  void _onNameChanged() {
    final text = _nameController!.text;
    if (text != _lastSyncedName) {
      _lastSyncedName = text;
      ref.read(appDataProvider.notifier).renameCombo(
            widget.characterId, widget.entryId, widget.comboId, text);
    }
  }

  void _onNotesChanged() {
    final text = _notesController!.text;
    if (text != _lastSyncedNotes) {
      _lastSyncedNotes = text;
      ref.read(appDataProvider.notifier).updateComboNotes(
            widget.characterId, widget.entryId, widget.comboId, text);
    }
  }

  void _appendStep(MoveStep step) {
    ref.read(appDataProvider.notifier).appendComboStep(
          widget.characterId, widget.entryId, widget.comboId, step);
  }

  void _deleteStep(int index) {
    ref.read(appDataProvider.notifier).removeComboStep(
          widget.characterId, widget.entryId, widget.comboId, index);
  }

  void _reorderStep(int oldIndex, int newIndex) {
    ref.read(appDataProvider.notifier).reorderComboStep(
          widget.characterId, widget.entryId, widget.comboId, oldIndex, newIndex);
  }

  void _clearNotation() {
    ref.read(appDataProvider.notifier).clearComboNotation(
          widget.characterId, widget.entryId, widget.comboId);
  }

  void _onStepTap(int index) {
    setState(() {
      if (_selAnchor == null) {
        // First tap: set the anchor, selection is just this one step.
        _selAnchor = index;
        _selStart = index;
        _selEnd = index;
      } else {
        // Second tap: extend selection between anchor and this step.
        _selStart = index < _selAnchor! ? index : _selAnchor!;
        _selEnd = index < _selAnchor! ? _selAnchor! : index;
        _selAnchor = null; // next tap starts a fresh selection
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selStart = null;
      _selEnd = null;
      _selAnchor = null;
    });
  }

  bool _isStepSelected(int index) {
    if (_selStart == null) return false;
    return index >= _selStart! && index <= _selEnd!;
  }

  void _showSaveTemplateDialog() {
    if (_selStart == null || _selEnd == null) return;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为招式模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已选中 ${_selEnd! - _selStart! + 1} 个步骤',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true,
              decoration: const InputDecoration(labelText: '模板名称', hintText: '例如: 波动拳')),
          ],
        ),
        actions: [
          TextButton(onPressed: () { _clearSelection(); Navigator.pop(ctx); }, child: const Text('取消')),
          TextButton(onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              ref.read(appDataProvider.notifier).saveSelectionAsTemplate(
                    widget.characterId, widget.entryId, widget.comboId,
                    _selStart!, _selEnd!, name);
              _clearSelection();
            }
            Navigator.pop(ctx);
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Auto-lock combo after editing
    _autoLockCombo();
    _notesController?.removeListener(_onNotesChanged);
    _notesController?.dispose();
    _nameController?.removeListener(_onNameChanged);
    _nameController?.dispose();
    super.dispose();
  }

  void _autoLockCombo() {
    final data = ref.read(appDataProvider);
    for (final c in data.characters) {
      if (c.id == widget.characterId) {
        for (final e in c.entries) {
          for (final co in e.combos) {
            if (co.id == widget.comboId && !co.locked) {
              ref.read(appDataProvider.notifier).toggleComboLock(
                    widget.characterId, widget.entryId, widget.comboId,
                  );
              return;
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final result = _findCombo(data);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑招式'), backgroundColor: Colors.grey.shade100, foregroundColor: Colors.grey.shade900),
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('找不到招式数据', style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('请返回上一页重试', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        )),
      );
    }

    final combo = result;
    final notation = combo.notation;
    _ensureController(combo.notes);
    _ensureNameController(combo.name);
    final templates = _getTemplates(data);
    final hasSelection = _selStart != null;
    final numpadMode = ref.read(appDataProvider.notifier).numpadMode;
    final isLocked = _isComboLocked();

    return Scaffold(
      appBar: AppBar(
        title: Text(combo.name.isNotEmpty ? combo.name : '编辑招式'),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(_isComboLocked() ? Icons.lock : Icons.lock_open),
            tooltip: _isComboLocked() ? '解锁招式' : '锁定招式',
            onPressed: () {
              ref.read(appDataProvider.notifier).toggleComboLock(
                    widget.characterId, widget.entryId, widget.comboId,
                  );
            },
          ),
          if (hasSelection) ...[
            IconButton(icon: const Icon(Icons.bookmark_add_outlined), tooltip: '保存选区为模板', onPressed: _showSaveTemplateDialog),
            IconButton(icon: const Icon(Icons.close), tooltip: '取消选区', onPressed: () => _clearSelection()),
          ],
          if (notation.isNotEmpty && !hasSelection)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: '清空', onPressed: _clearNotation),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    enabled: !isLocked,
                    decoration: InputDecoration(
                      labelText: '招式名称',
                      hintText: '例如: 基础连段',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('招式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      const Spacer(),
                      if (hasSelection)
                        Text(
                          _selAnchor != null
                              ? '已选 1 步，再点击另一端确定范围'
                              : '已选 ${_selEnd! - _selStart! + 1} 步，点右上角保存为模板',
                          style: TextStyle(fontSize: 12, color: Colors.purple.shade600, fontWeight: FontWeight.w600),
                        )
                      else
                        Text('点两个步骤选区 → 右上角保存为模板', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  NotationDropTarget(
                    notation: notation,
                    onAppend: _appendStep,
                    onDelete: _deleteStep,
                    onReorder: _reorderStep,
                    onStepTap: _onStepTap,
                    isStepSelected: _isStepSelected,
                    numpadMode: numpadMode,
                    enabled: !isLocked,
                  ),
                  const SizedBox(height: 24),
                  Text('备注', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: isLocked,
                    child: TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '输入备注...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade500, width: 1.5)),
                      filled: true, fillColor: Colors.grey.shade50,
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom panel (hidden when locked)
          if (!isLocked)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Wide screens (desktop/tablet): keep the classic inline
                  // three-column layout. Narrow screens (phones): show a row
                  // of three tab buttons that each open a popup sheet, so the
                  // three areas don't crowd each other.
                  if (constraints.maxWidth >= 600) {
                    return Row(
                      children: [
                        Expanded(child: _buildDirectionPad()),
                        _divider(),
                        Expanded(child: _buildAttackPad()),
                        _divider(),
                        Expanded(flex: 2, child: _buildTemplateBar(templates)),
                      ],
                    );
                  }
                  return _buildNarrowTabs(templates);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 100, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4));

  /// Narrow-screen bottom panel: three tab buttons that each open a popup
  /// Narrow-screen bottom panel. Three tab buttons; tapping one expands its
  /// pad inline (non-modal, so the DragTarget in the editor above still
  /// receives drops from the buttons here). Tapping the active tab collapses.
  Widget _buildNarrowTabs(List<MoveTemplate> templates) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _padTab(0, Icons.explore_outlined, '方向')),
            Expanded(child: _padTab(1, Icons.sports_martial_arts, '拳脚')),
            Expanded(child: _padTab(2, Icons.bookmark_outline, '模板')),
          ],
        ),
        if (_activePad != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: switch (_activePad) {
              0 => Center(child: _buildDirectionPad()),
              1 => Center(child: _buildAttackPad()),
              _ => _buildTemplateBar(templates, expand: true),
            },
          ),
      ],
    );
  }

  Widget _padTab(int index, IconData icon, String label) {
    final active = _activePad == index;
    return InkWell(
      onTap: () => setState(() => _activePad = active ? null : index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? Colors.purple.shade700 : Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.purple.shade700 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDirectionPad() {
    final numpadMode = ref.read(appDataProvider.notifier).numpadMode;
    const rows = [
      [Direction.upBack, Direction.up, Direction.upForward],
      [Direction.back, null, Direction.forward],
      [Direction.downBack, Direction.down, Direction.downForward],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('方向', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        ...rows.map((row) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((dir) {
                if (dir == null) return const SizedBox(width: 42, height: 42);
                return Padding(padding: const EdgeInsets.all(1), child: DirectionButton(direction: dir, size: 40, numpadMode: numpadMode));
              }).toList(),
            )),
      ],
    );
  }

  Widget _buildAttackPad() {
    const punches = [Attack.lightPunch, Attack.mediumPunch, Attack.heavyPunch];
    const kicks = [Attack.lightKick, Attack.mediumKick, Attack.heavyKick];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('拳脚', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final a in punches) Padding(padding: const EdgeInsets.all(1), child: AttackButton(attack: a, size: 40))]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final a in kicks) Padding(padding: const EdgeInsets.all(1), child: AttackButton(attack: a, size: 40))]),
      ],
    );
  }

  Widget _buildTemplateBar(List<MoveTemplate> templates, {bool expand = false}) {
    // Split into global (visible to all) vs this character's own. Each group
    // is rendered as a labeled block so the user can tell them apart at a
    // glance and drag per-character templates into the global pool.
    final data = ref.read(appDataProvider);
    final globals = templates.where((t) => data.globalTemplates.any((g) => g.id == t.id)).toList();
    final owns = templates.where((t) => !data.globalTemplates.any((g) => g.id == t.id)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: expand ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (!expand)
          Text('模板', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        if (!expand) const SizedBox(height: 4),
        if (templates.isEmpty)
          Center(child: Text(expand ? '还没有模板，先在招式编辑器里选区保存' : '选区后保存为模板', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)))
        else ...[
          // Global block (drag into notation to use; these can't be relocated
          // from here since they already belong to everyone).
          if (globals.isNotEmpty)
            _templateBlock(
              label: '通用',
              iconColor: Colors.blue.shade700,
              templates: globals,
              expand: expand,
              canMoveToGlobal: false,
            ),
          if (globals.isNotEmpty && owns.isNotEmpty)
            SizedBox(height: expand ? 6 : 4),
          // Per-character block (drag into notation to use; long-press the chip
          // to delete, or tap the globe badge to move it into the global pool).
          if (owns.isNotEmpty)
            _templateBlock(
              label: '本角色',
              iconColor: Colors.purple.shade700,
              templates: owns,
              expand: expand,
              canMoveToGlobal: true,
            ),
        ],
      ],
    );
  }

  /// One labeled group of template chips.
  Widget _templateBlock({
    required String label,
    required Color iconColor,
    required List<MoveTemplate> templates,
    required bool expand,
    required bool canMoveToGlobal,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: expand ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(canMoveToGlobal ? Icons.person_outline : Icons.public,
                size: 12, color: iconColor),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: iconColor)),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          alignment: expand ? WrapAlignment.center : WrapAlignment.start,
          spacing: 6,
          runSpacing: 6,
          children: templates.map((t) {
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
              },
              // Per-character chip: a globe badge to promote it to global.
              // Tap shows a confirm snackbar/action rather than a silent move.
              // Sized up so it's tappable on phones.
              badge: canMoveToGlobal
                  ? GestureDetector(
                      onTap: () => _moveToGlobal(t),
                      behavior: HitTestBehavior.opaque,
                      child: Tooltip(
                        message: '转为通用模板',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.public, size: 16, color: Colors.blue.shade700),
                        ),
                      ),
                    )
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Promote a per-character template into the global pool (visible to all).
  void _moveToGlobal(MoveTemplate t) {
    ref.read(appDataProvider.notifier).relocateTemplate(widget.characterId, null, t.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${t.displayText}」已转为通用模板（对所有角色可见）'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
