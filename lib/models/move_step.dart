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
