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
  List<MoveStep> _steps = [];

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
  }

  void _onNameChanged() {
    ref.read(appDataProvider.notifier).renameTemplate(
          widget.characterId, widget.templateId, _nameController!.text);
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
              child: Row(
                children: [
                  Expanded(child: _buildDirectionPad()),
                  Container(width: 1, height: 100, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  Expanded(child: _buildAttackPad()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController?.removeListener(_onNameChanged);
    _nameController?.dispose();
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
