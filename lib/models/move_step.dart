/// Direction in fighting game notation.
enum Direction {
  up,
  down,
  back,
  forward,
  upBack,
  downBack,
  upForward,
  downForward;

  String get symbol => switch (this) {
        Direction.up => '↑',
        Direction.down => '↓',
        Direction.back => '←',
        Direction.forward => '→',
        Direction.upBack => '↖',
        Direction.downBack => '↙',
        Direction.upForward => '↗',
        Direction.downForward => '↘',
      };

  /// Numpad notation number (fighting game standard).
  int get numpad => switch (this) {
        Direction.upBack => 7,
        Direction.up => 8,
        Direction.upForward => 9,
        Direction.back => 4,
        Direction.forward => 6,
        Direction.downBack => 1,
        Direction.down => 2,
        Direction.downForward => 3,
      };

  String get jsonKey => name;

  static Direction fromJson(String key) => Direction.values.firstWhere(
        (d) => d.jsonKey == key,
        orElse: () => Direction.up,
      );
}

/// Attack button in fighting game notation.
enum Attack {
  lightPunch,
  mediumPunch,
  heavyPunch,
  lightKick,
  mediumKick,
  heavyKick;

  String get label => switch (this) {
        Attack.lightPunch => 'LP',
        Attack.mediumPunch => 'MP',
        Attack.heavyPunch => 'HP',
        Attack.lightKick => 'LK',
        Attack.mediumKick => 'MK',
        Attack.heavyKick => 'HK',
      };

  bool get isPunch => switch (this) {
        Attack.lightPunch || Attack.mediumPunch || Attack.heavyPunch => true,
        _ => false,
      };

  bool get isKick => !isPunch;

  bool get isLight => switch (this) {
        Attack.lightPunch || Attack.lightKick => true,
        _ => false,
      };

  bool get isMedium => switch (this) {
        Attack.mediumPunch || Attack.mediumKick => true,
        _ => false,
      };

  bool get isHeavy => switch (this) {
        Attack.heavyPunch || Attack.heavyKick => true,
        _ => false,
      };

  /// Unicode character for display in buttons.
  String get symbol => isPunch ? '✊' : '脚';

  String get jsonKey => name;

  static Attack fromJson(String key) => Attack.values.firstWhere(
        (a) => a.jsonKey == key,
        orElse: () => Attack.lightPunch,
      );
}

/// A single step in move notation.
sealed class MoveStep {
  Map<String, dynamic> toJson();
  String get displayText;
  String get numpadText;
  String get kind;
}

class MoveStepDirection extends MoveStep {
  MoveStepDirection(this.direction);
  final Direction direction;

  @override
  String get kind => 'direction';
  @override
  String get displayText => direction.symbol;
  @override
  String get numpadText => direction.numpad.toString();

  @override
  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'value': direction.jsonKey,
      };

  static MoveStepDirection fromJson(Map<String, dynamic> json) =>
      MoveStepDirection(Direction.fromJson(json['value'] as String));
}

class MoveStepAttack extends MoveStep {
  MoveStepAttack(this.attack);
  final Attack attack;

  @override
  String get kind => 'attack';
  @override
  String get displayText => attack.label;
  @override
  String get numpadText => '5${attack.label}';

  @override
  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'value': attack.jsonKey,
      };
}

/// A move step referencing a reusable template.
class MoveStepTemplate extends MoveStep {
  MoveStepTemplate({
    required this.templateId,
    required this.templateName,
    required this.templateSteps,
  });

  final String templateId;
  String templateName;
  List<MoveStep> templateSteps;

  String get stepsPreview =>
      templateSteps.map((s) => s.displayText).join(' ');

  @override
  String get kind => 'template';
  @override
  String get displayText =>
      templateName.isNotEmpty ? templateName : stepsPreview;
  @override
  String get numpadText =>
      templateSteps.map((s) => s.numpadText).join(' ');

  @override
  @override
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'templateId': templateId,
        'name': templateName,
        'steps': templateSteps.map((s) => s.toJson()).toList(),
      };
}

MoveStep moveStepFromJson(Map<String, dynamic> json) {
  final kind = json['kind'] as String;
  return switch (kind) {
    'direction' => MoveStepDirection.fromJson(json),
    'template' => MoveStepTemplate(
        templateId: json['templateId'] as String,
        templateName: json['name'] as String? ?? '',
        templateSteps: (json['steps'] as List<dynamic>?)
                ?.map((s) => moveStepFromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      ),
    _ => MoveStepAttack(Attack.fromJson(json['value'] as String)),
  };
}

/// Build numpad notation string from a step list.
/// Merges adjacent direction+attack (e.g., "2MK" instead of "2 MK").
/// Attacks without preceding direction get "5" prefix (e.g., "5LP").
String numpadPreview(List<MoveStep> notation) {
  final buf = StringBuffer();
  for (int i = 0; i < notation.length; i++) {
    final step = notation[i];
    if (i > 0) buf.write(' > ');
    if (step is MoveStepTemplate) {
      buf.write(step.numpadText);
    } else if (step is MoveStepDirection) {
      // Check if next step is an attack — merge them
      if (i + 1 < notation.length &&
          notation[i + 1] is MoveStepAttack) {
        buf.write(step.numpadText);
        // Don't add separator — attack will be written without "5"
      } else {
        buf.write(step.numpadText);
      }
    } else if (step is MoveStepAttack) {
      // If previous step was a direction, skip the "5" prefix
      if (i > 0 && notation[i - 1] is MoveStepDirection) {
        buf.write(step.attack.label);
      } else {
        buf.write(step.numpadText);
      }
    }
  }
  return buf.toString();
}

/// Group steps into slots: consecutive directions + optional trailing attack = one slot.
/// Templates are always their own slot (expanded to inner steps).
List<List<MoveStep>> groupNotationSlots(List<MoveStep> steps) {
  final slots = <List<MoveStep>>[];
  List<MoveStep>? currentSlot;
  for (final step in steps) {
    if (step is MoveStepTemplate) {
      if (currentSlot != null) {
        slots.add(currentSlot);
        currentSlot = null;
      }
      slots.add(List.from(step.templateSteps));
    } else if (step is MoveStepDirection) {
      currentSlot ??= [];
      currentSlot.add(step);
    } else if (step is MoveStepAttack) {
      currentSlot ??= [];
      currentSlot.add(step);
      slots.add(currentSlot);
      currentSlot = null;
    }
  }
  if (currentSlot != null) slots.add(currentSlot);
  return slots;
}

/// A segment of a combo for PDF rendering. Either a template reference
/// (kept whole so its name/notes can be applied) or a run of plain steps.
class NotationSegment {
  NotationSegment({this.template, this.steps});
  final MoveStepTemplate? template;
  final List<MoveStep>? steps;
  bool get isTemplate => template != null;
}

/// Split a combo's notation into segments: each MoveStepTemplate is its own
/// segment (preserved, not expanded), and the rest are grouped by the same
/// rule as [groupNotationSlots] (consecutive directions + optional attack).
List<NotationSegment> splitNotationSegments(List<MoveStep> steps) {
  final segments = <NotationSegment>[];
  List<MoveStep>? current;
  void flush() {
    if (current != null) {
      segments.add(NotationSegment(steps: current));
      current = null;
    }
  }

  for (final step in steps) {
    if (step is MoveStepTemplate) {
      flush();
      segments.add(NotationSegment(template: step));
    } else if (step is MoveStepDirection) {
      current ??= [];
      current!.add(step);
    } else if (step is MoveStepAttack) {
      current ??= [];
      current!.add(step);
      flush();
    }
  }
  flush();
  return segments;
}

/// Build slot string (no internal connectors).
/// Merges direction+attack, adds 5 prefix for standalone attacks.
String buildSlotText(List<MoveStep> steps, bool useNumpad) {
  final buf = StringBuffer();
  for (final step in steps) {
    if (step is MoveStepDirection) {
      buf.write(useNumpad ? step.direction.numpad.toString() : step.direction.symbol);
    } else if (step is MoveStepAttack) {
      final hasDir = buf.isNotEmpty && steps[steps.indexOf(step) - 1] is MoveStepDirection;
      buf.write(hasDir ? step.attack.label : '5${step.attack.label}');
    }
  }
  return buf.toString();
}

/// Full notation using grouped slots joined with '+', matching PDF export format.
String groupedNotationPreview(List<MoveStep> steps, {bool useNumpad = false}) {
  final slots = groupNotationSlots(steps);
  return slots.map((slot) => buildSlotText(slot, useNumpad)).join(' + ');
}

/// Build notation text honoring template boundaries. Each MoveStepTemplate
/// becomes a parenthesized segment, optionally showing its name (if the
/// referenced [MoveTemplate] has [MoveTemplate.useNameInPdf]) and its remark
/// (`* notes`, if [MoveTemplate.notes] is non-empty). Non-template steps are
/// grouped as usual. Segments are joined with ' + '.
///
/// [templates] is the owning character's template list, used to look up the
/// live `useNameInPdf` / `notes`. Templates missing from [templates] fall back
/// to plain expansion with no name/notes.
String buildNotationWithTemplates(
  List<MoveStep> notation,
  List templates, {
  bool useNumpad = false,
}) {
  final segments = splitNotationSegments(notation);
  final parts = <String>[];
  for (final seg in segments) {
    if (seg.isTemplate) {
      final tpl = seg.template!;
      // Look up the live template by id (carries useNameInPdf + notes).
      dynamic live;
      for (final t in templates) {
        if (t.id == tpl.templateId) {
          live = t;
          break;
        }
      }
      final useName = live != null && live.useNameInPdf == true && live.name.isNotEmpty;
      final notes = live != null ? (live.notes as String? ?? '') : '';
      String body;
      if (useName) {
        body = live.name as String;
      } else {
        body = groupedNotationPreview(tpl.templateSteps, useNumpad: useNumpad);
      }
      parts.add(notes.isNotEmpty ? '($body* $notes)' : '($body)');
    } else {
      parts.add(groupedNotationPreview(seg.steps!, useNumpad: useNumpad));
    }
  }
  return parts.join(' + ');
}

/// A colored text fragment. [color] is an ARGB int (0xAARRGGBB).
/// Used as a UI/PDF-agnostic intermediate representation so colored notation
/// can be rendered into both Flutter TextSpans and pdf TextSpans.
class ColoredTextSpan {
  const ColoredTextSpan(this.text, {this.color});
  final String text;
  final int? color;
}

/// A sequence of colored text spans representing one combo's notation.
class ColoredText {
  const ColoredText(this.spans);
  final List<ColoredTextSpan> spans;

  /// Flatten to a single plain string (drops colors).
  String get plain => spans.map((s) => s.text).join();

  bool get isEmpty => spans.isEmpty;
}

/// ARGB color ints for attack strength, matching the in-app AttackButton scheme.
int _attackColor(Attack a) {
  if (a.isLight) return 0xFF1976D2; // blue
  if (a.isMedium) return 0xFFF57F17; // amber
  return 0xFFC62828; // red (heavy)
}

/// Build colored notation honoring template boundaries.
///
/// Color rules:
/// - Direction characters → default (null = black).
/// - Attack labels → light=blue / medium=amber / heavy=red (always, even when
///   shown as detailed instructions inside a template that has its own color).
/// - Template segment shown as its **name** (useNameInPdf) → the whole segment
///   (including parentheses, name, and `* notes`) uses the template's color.
/// - Template segment shown as **detailed instructions** → template color is
///   ignored; attacks within keep their own strength colors.
/// - Connectors (` + `, `(`, `)`, `*`) → default black.
///
/// [templates] is the owning character's template list (dynamic to avoid an
/// import cycle with move_template.dart). Returns a [ColoredText] with one
/// span per colored run.
ColoredText buildColoredNotation(
  List<MoveStep> notation,
  List templates, {
  bool useNumpad = false,
}) {
  final segments = splitNotationSegments(notation);
  final out = <ColoredTextSpan>[];
  void emit(String text, int? color) {
    if (text.isEmpty) return;
    if (out.isNotEmpty && out.last.color == color) {
      out[out.length - 1] = ColoredTextSpan(out.last.text + text, color: color);
    } else {
      out.add(ColoredTextSpan(text, color: color));
    }
  }

  for (int si = 0; si < segments.length; si++) {
    final seg = segments[si];
    if (si > 0) emit(' + ', null);

    if (seg.isTemplate) {
      final tpl = seg.template!;
      dynamic live;
      for (final t in templates) {
        if (t.id == tpl.templateId) {
          live = t;
          break;
        }
      }
      final useName = live != null && live.useNameInPdf == true && live.name.isNotEmpty;
      final notes = live != null ? (live.notes as String? ?? '') : '';
      final tplColor = live != null ? live.colorValue as int? : null;

      if (useName) {
        // Whole segment colored with the template's color (incl. parens/notes).
        final notesSuffix = notes.isNotEmpty ? '* $notes' : '';
        emit('(${live.name}$notesSuffix)', tplColor);
      } else {
        // Detailed instructions: ignore template color; attacks keep their own.
        emit('(', null);
        _emitColoredSteps(tpl.templateSteps, useNumpad, emit);
        if (notes.isNotEmpty) emit('* $notes', null);
        emit(')', null);
      }
    } else {
      _emitColoredSteps(seg.steps!, useNumpad, emit);
    }
  }
  return ColoredText(out);
}

/// Emit a run of plain steps as colored spans (attacks colored by strength).
void _emitColoredSteps(
  List<MoveStep> steps,
  bool useNumpad,
  void Function(String, int?) emit,
) {
  final slots = groupNotationSlots(steps);
  for (int i = 0; i < slots.length; i++) {
    if (i > 0) emit(' + ', null);
    final slot = slots[i];
    for (final step in slot) {
      if (step is MoveStepDirection) {
        emit(
          useNumpad ? step.direction.numpad.toString() : step.direction.symbol,
          null,
        );
      } else if (step is MoveStepAttack) {
        // Determine whether this attack was merged with a preceding direction.
        final merged = slot.indexOf(step) > 0 && slot[slot.indexOf(step) - 1] is MoveStepDirection;
        if (merged) {
          // No "5" prefix — the whole label takes the attack color.
          emit(step.attack.label, _attackColor(step.attack));
        } else {
          // Standalone attack: "5" prefix stays black, only the label is colored.
          emit('5', null);
          emit(step.attack.label, _attackColor(step.attack));
        }
      }
    }
  }
}
