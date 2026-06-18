import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/move_step.dart';
import '../providers/app_data_provider.dart';
import '../widgets/direction_button.dart';
import '../widgets/attack_button.dart';
import '../widgets/notation_drop_target.dart';

/// Dedicated screen for editing a single move template.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({
    super.key,
    required this.characterId,
    required this.templateId,
  });

  final String characterId;
  final String templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  TextEditingController? _nameController;
  TextEditingController? _notesController;
  String _lastSyncedNotes = '';
  List<MoveStep> _steps = [];
  // Narrow-screen bottom panel: which pad is expanded (null = only tab row).
  int? _activePad;

  void _syncFromState() {
    final data = ref.read(appDataProvider);
    final charIdx = data.characters.indexWhere((c) => c.id == widget.characterId);
    if (charIdx < 0) return;
    final tmplIdx = data.characters[charIdx].templates.indexWhere((t) => t.id == widget.templateId);
    if (tmplIdx < 0) return;
    final tmpl = data.characters[charIdx].templates[tmplIdx];

    final nameChanged = _nameController == null || _nameController!.text != tmpl.name;
    _steps = List.from(tmpl.steps);
    _nameController ??= TextEditingController(text: tmpl.name)
      ..addListener(_onNameChanged);
    if (nameChanged && _nameController!.text != tmpl.name) {
      _nameController!.text = tmpl.name;
    }
    _ensureNotesController(tmpl.notes);
  }

  void _ensureNotesController(String notes) {
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

  void _onNameChanged() {
    ref.read(appDataProvider.notifier).renameTemplate(
          widget.characterId, widget.templateId, _nameController!.text);
  }

  void _onNotesChanged() {
    final text = _notesController!.text;
    if (text != _lastSyncedNotes) {
      _lastSyncedNotes = text;
      ref.read(appDataProvider.notifier).updateTemplateNotes(
            widget.characterId, widget.templateId, text);
    }
  }

  void _appendStep(MoveStep step) {
    setState(() => _steps = [..._steps, step]);
    ref.read(appDataProvider.notifier).appendTemplateStep(
          widget.characterId, widget.templateId, step);
  }

  void _deleteStep(int index) {
    setState(() => _steps = List.from(_steps)..removeAt(index));
    ref.read(appDataProvider.notifier).removeTemplateStep(
          widget.characterId, widget.templateId, index);
  }

  void _reorderStep(int oldIndex, int newIndex) {
    setState(() {
      final s = List<MoveStep>.from(_steps);
      final step = s.removeAt(oldIndex);
      s.insert(newIndex, step);
      _steps = s;
    });
    ref.read(appDataProvider.notifier).updateTemplateSteps(
          widget.characterId, widget.templateId, _steps);
  }

  void _clearSteps() {
    setState(() => _steps = []);
    ref.read(appDataProvider.notifier).updateTemplateSteps(
          widget.characterId, widget.templateId, []);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final charIdx = data.characters.indexWhere((c) => c.id == widget.characterId);
    if (charIdx < 0) {
      return Scaffold(appBar: AppBar(title: const Text('编辑模板')), body: Center(child: Text('人物不存在')));
    }
    final tmplIdx = data.characters[charIdx].templates.indexWhere((t) => t.id == widget.templateId);
    if (tmplIdx < 0) {
      return Scaffold(appBar: AppBar(title: const Text('编辑模板')), body: Center(child: Text('模板不存在')));
    }

    _syncFromState();
    final tmpl = data.characters[charIdx].templates[tmplIdx];

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑招式模板'),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
        actions: [
          if (_steps.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: '清空步骤', onPressed: _clearSteps),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: '删除模板',
            onPressed: () {
              ref.read(appDataProvider.notifier).removeTemplate(
                    widget.characterId, widget.templateId);
              Navigator.pop(context);
            },
          ),
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
                    decoration: InputDecoration(
                      labelText: '模板名称',
                      hintText: '例如: 波动拳',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: tmpl.useNameInPdf,
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(appDataProvider.notifier).setTemplateUseNameInPdf(
                                  widget.characterId, widget.templateId, value);
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          '导出 PDF 时显示模板名而不是具体指令',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('备注', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '输入备注（导出 PDF 时显示在括号内末尾 * 之后）...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade500, width: 1.5)),
                      filled: true, fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('颜色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('导出 PDF 时此模板指令的显示颜色（不选默认黑色）',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  _buildColorPicker(tmpl),
                  const SizedBox(height: 16),
                  Text('步骤', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  NotationDropTarget(
                    notation: _steps,
                    onAppend: _appendStep,
                    onDelete: _deleteStep,
                    onReorder: _reorderStep,
                    numpadMode: ref.read(appDataProvider.notifier).numpadMode,
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 600) {
                    return Row(
                      children: [
                        Expanded(child: _buildDirectionPad()),
                        Container(width: 1, height: 100, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),
                        Expanded(child: _buildAttackPad()),
                      ],
                    );
                  }
                  // Narrow screens: two tab buttons that expand inline
                  // (non-modal, so drops still reach the editor's DragTarget).
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _padTab(0, Icons.explore_outlined, '方向')),
                          Expanded(child: _padTab(1, Icons.sports_martial_arts, '拳脚')),
                        ],
                      ),
                      if (_activePad != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: switch (_activePad) {
                            0 => Center(child: _buildDirectionPad()),
                            _ => Center(child: _buildAttackPad()),
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<Color> _palette = [
    Color(0xFF000000), // black (default)
    Color(0xFFE53935), // red
    Color(0xFFFB8C00), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFF6D4C41), // brown
  ];

  Widget _buildColorPicker(tmpl) {
    final selected = tmpl.colorValue == null ? 0xFF000000 : tmpl.colorValue!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in _palette)
          Builder(builder: (context) {
            final argb = c.toARGB32();
            final isSelected = selected == argb;
            return GestureDetector(
              onTap: () {
                final value = argb == 0xFF000000 ? null : argb;
                ref.read(appDataProvider.notifier).setTemplateColor(
                      widget.characterId, widget.templateId, value);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.grey.shade800 : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected ? Colors.black26 : Colors.transparent,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }),
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

  @override
  void dispose() {
    _nameController?.removeListener(_onNameChanged);
    _nameController?.dispose();
    _notesController?.removeListener(_onNotesChanged);
    _notesController?.dispose();
    super.dispose();
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
}
