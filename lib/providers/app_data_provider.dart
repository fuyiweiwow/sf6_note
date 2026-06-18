import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_data.dart';
import '../models/character.dart';
import '../models/combo.dart';
import '../models/entry.dart';
import '../models/move_step.dart';
import '../models/move_template.dart';
import '../services/file_io_service.dart';
import '../services/pdf_export_service.dart';

const _uuid = Uuid();

class AppDataNotifier extends StateNotifier<AppData> {
  AppDataNotifier() : super(AppData.empty()) {
    _init();
  }

  final _fileIo = FileIoService();
  Timer? _debounceTimer;
  bool numpadMode = false;

  void toggleNumpadMode() {
    numpadMode = !numpadMode;
  }

  PdfNotationMode get pdfExportMode => state.pdfExportMode;

  void setPdfExportMode(PdfNotationMode mode) {
    state = AppData(
      pdfExportMode: mode,
      characters: state.characters,
    );
    _scheduleSave();
  }

  Future<void> _init() async {
    final data = await _fileIo.loadLocal();
    state = data;
  }

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fileIo.saveLocal(state);
    });
  }

  // --- Character operations ---

  void addCharacter(String name) {
    state = AppData(
      characters: [...state.characters, Character(name: name)],
    );
    _scheduleSave();
  }

  void removeCharacter(String characterId) {
    state = AppData(
      characters: state.characters
          .where((c) => c.id != characterId)
          .toList(),
    );
    _scheduleSave();
  }

  void renameCharacter(String characterId, String newName) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) c.name = newName;
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  // --- Entry operations ---

  void addCustomEntry(String characterId, String customName) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          c.entries.add(
            Entry(id: _uuid.v4(), type: EntryType.custom, customName: customName),
          );
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void removeEntry(String characterId, String entryId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          c.entries = c.entries.where((e) => e.id != entryId).toList();
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  /// Reorder entries within a character.
  void reorderEntries(
      String characterId, int oldIndex, int newIndex) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          final entries = List<Entry>.from(c.entries);
          if (oldIndex < newIndex) newIndex -= 1;
          final entry = entries.removeAt(oldIndex);
          entries.insert(newIndex, entry);
          c.entries = entries;
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void toggleComboLock(String characterId, String entryId, String comboId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) co.locked = !co.locked;
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  // --- Combo operations ---

  void addCombo(String characterId, String entryId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              e.combos.add(Combo());
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void removeCombo(String characterId, String entryId, String comboId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              e.combos = e.combos.where((co) => co.id != comboId).toList();
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  /// Duplicate a combo, inserting the copy right after the original.
  void duplicateCombo(String characterId, String entryId, String comboId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              final idx = e.combos.indexWhere((co) => co.id == comboId);
              if (idx >= 0) {
                final src = e.combos[idx];
                final copy = Combo(
                  name: src.name,
                  notation: src.notation.map((s) => _cloneStep(s)).toList(),
                  notes: src.notes,
                  locked: false,
                );
                e.combos = List<Combo>.from(e.combos)..insert(idx + 1, copy);
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  /// Reorder combos within an entry.
  void reorderCombos(
      String characterId, String entryId, int oldIndex, int newIndex) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              final combos = List<Combo>.from(e.combos);
              if (oldIndex < newIndex) newIndex -= 1;
              final combo = combos.removeAt(oldIndex);
              combos.insert(newIndex, combo);
              e.combos = combos;
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  /// Deep-clone a MoveStep so duplicated combos don't share mutable lists.
  static MoveStep _cloneStep(MoveStep step) {
    if (step is MoveStepDirection) {
      return MoveStepDirection(step.direction);
    } else if (step is MoveStepAttack) {
      return MoveStepAttack(step.attack);
    } else if (step is MoveStepTemplate) {
      return MoveStepTemplate(
        templateId: step.templateId,
        templateName: step.templateName,
        templateSteps:
            step.templateSteps.map((s) => _cloneStep(s)).toList(),
      );
    }
    return step;
  }

  void updateComboNotation(
      String characterId, String entryId, String comboId, List<MoveStep> notation) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  co.notation = notation;
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void updateComboNotes(
      String characterId, String entryId, String comboId, String notes) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  co.notes = notes;
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void renameCombo(
      String characterId, String entryId, String comboId, String newName) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  co.name = newName;
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void appendComboStep(
      String characterId, String entryId, String comboId, MoveStep step) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  co.notation = [...co.notation, step];
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void removeComboStep(
      String characterId, String entryId, String comboId, int index) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  co.notation = List.from(co.notation)..removeAt(index);
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void reorderComboStep(
      String characterId, String entryId, String comboId, int oldIndex, int newIndex) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  final steps = List<MoveStep>.from(co.notation);
                  if (oldIndex < newIndex) newIndex -= 1;
                  final step = steps.removeAt(oldIndex);
                  steps.insert(newIndex, step);
                  co.notation = steps;
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void clearComboNotation(
      String characterId, String entryId, String comboId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final e in c.entries) {
            if (e.id == entryId) {
              for (final co in e.combos) {
                if (co.id == comboId) {
                  co.notation = [];
                }
              }
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  // --- Template operations ---

  void addTemplate(String characterId, MoveTemplate template) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) c.templates.add(template);
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void removeTemplate(String characterId, String templateId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          c.templates = c.templates.where((t) => t.id != templateId).toList();
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void renameTemplate(String characterId, String templateId, String newName) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.name = newName;
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void updateTemplateNotes(
      String characterId, String templateId, String notes) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.notes = notes;
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void setTemplateUseNameInPdf(
      String characterId, String templateId, bool value) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.useNameInPdf = value;
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  /// Set template color (ARGB int). null resets to default black.
  void setTemplateColor(
      String characterId, String templateId, int? colorValue) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.colorValue = colorValue;
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void updateTemplateSteps(
      String characterId, String templateId, List<MoveStep> steps) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.steps = steps;
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void appendTemplateStep(
      String characterId, String templateId, MoveStep step) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) {
              t.steps = [...t.steps, step];
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  void removeTemplateStep(
      String characterId, String templateId, int index) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) {
              t.steps = List.from(t.steps)..removeAt(index);
            }
          }
        }
        return c;
      }).toList(),
    );
    _scheduleSave();
  }

  /// Save a selection of steps from a combo as a new template.
  void saveSelectionAsTemplate(
    String characterId,
    String entryId,
    String comboId,
    int startIndex,
    int endIndex,
    String templateName,
  ) {
    List<MoveStep>? selectedSteps;
    for (final c in state.characters) {
      if (c.id == characterId) {
        for (final e in c.entries) {
          if (e.id == entryId) {
            for (final co in e.combos) {
              if (co.id == comboId) {
                final flat = <MoveStep>[];
                for (int i = startIndex;
                    i <= endIndex && i < co.notation.length;
                    i++) {
                  final step = co.notation[i];
                  if (step is MoveStepTemplate) {
                    flat.addAll(step.templateSteps);
                  } else {
                    flat.add(step);
                  }
                }
                selectedSteps = flat;
              }
            }
          }
        }
      }
    }
    if (selectedSteps == null || selectedSteps.isEmpty) return;

    addTemplate(
        characterId, MoveTemplate(name: templateName, steps: selectedSteps));
  }

  // --- Import / Export ---

  Future<bool> importData() async {
    final data = await _fileIo.importFromFile();
    if (data == null) return false;
    state = data;
    await _fileIo.saveLocal(state);
    return true;
  }

  Future<bool> exportData() async {
    return _fileIo.exportToFile(state);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final appDataProvider =
    StateNotifierProvider<AppDataNotifier, AppData>((ref) => AppDataNotifier());
