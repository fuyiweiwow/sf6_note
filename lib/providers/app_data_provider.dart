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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
    );
    _scheduleSave();
  }

  void removeCharacter(String characterId) {
    state = AppData(
      characters: state.characters
          .where((c) => c.id != characterId)
          .toList(),
      globalTemplates: state.globalTemplates,
    );
    _scheduleSave();
  }

  void renameCharacter(String characterId, String newName) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) c.name = newName;
        return c;
      }).toList(),
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
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
      globalTemplates: state.globalTemplates,
    );
    _scheduleSave();
  }

  // --- Template operations ---
  //
  // Templates live in two places:
  //   * per-character (characterId != null): only that character sees them
  //   * global (characterId == null): visible to every character
  // All template ops take a nullable characterId to target either location.
  // `effectiveTemplates` merges the two lists for a given character.

  /// All templates a character can use: globals first, then its own.
  List<MoveTemplate> effectiveTemplates(String characterId) {
    final own = _findCharacter(characterId)?.templates ?? const [];
    return [...state.globalTemplates, ...own];
  }

  Character? _findCharacter(String characterId) {
    for (final c in state.characters) {
      if (c.id == characterId) return c;
    }
    return null;
  }

  /// Read the list that owns this template (mutable, in current state).
  /// characterId == null targets the global list.
  List<MoveTemplate> _templateList(String? characterId) {
    if (characterId == null) return state.globalTemplates;
    return _findCharacter(characterId)?.templates ?? const [];
  }

  void addTemplate(String? characterId, MoveTemplate template) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) c.templates.add(template);
        return c;
      }).toList(),
      globalTemplates: characterId == null
          ? [...state.globalTemplates, template]
          : state.globalTemplates,
    );
    _scheduleSave();
  }

  void removeTemplate(String? characterId, String templateId) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          c.templates = c.templates.where((t) => t.id != templateId).toList();
        }
        return c;
      }).toList(),
      globalTemplates: characterId == null
          ? state.globalTemplates.where((t) => t.id != templateId).toList()
          : state.globalTemplates,
    );
    _scheduleSave();
  }

  void renameTemplate(String? characterId, String templateId, String newName) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.name = newName;
          }
        }
        return c;
      }).toList(),
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) t.name = newName;
      }),
    );
    _scheduleSave();
  }

  void updateTemplateNotes(
      String? characterId, String templateId, String notes) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.notes = notes;
          }
        }
        return c;
      }).toList(),
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) t.notes = notes;
      }),
    );
    _scheduleSave();
  }

  void setTemplateUseNameInPdf(
      String? characterId, String templateId, bool value) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.useNameInPdf = value;
          }
        }
        return c;
      }).toList(),
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) t.useNameInPdf = value;
      }),
    );
    _scheduleSave();
  }

  /// Set template color (ARGB int). null resets to default black.
  void setTemplateColor(
      String? characterId, String templateId, int? colorValue) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.colorValue = colorValue;
          }
        }
        return c;
      }).toList(),
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) t.colorValue = colorValue;
      }),
    );
    _scheduleSave();
  }

  void updateTemplateSteps(
      String? characterId, String templateId, List<MoveStep> steps) {
    state = AppData(
      characters: state.characters.map((c) {
        if (c.id == characterId) {
          for (final t in c.templates) {
            if (t.id == templateId) t.steps = steps;
          }
        }
        return c;
      }).toList(),
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) t.steps = steps;
      }),
    );
    _scheduleSave();
  }

  void appendTemplateStep(
      String? characterId, String templateId, MoveStep step) {
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
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) {
          t.steps = [...t.steps, step];
        }
      }),
    );
    _scheduleSave();
  }

  void removeTemplateStep(
      String? characterId, String templateId, int index) {
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
      globalTemplates: _mutateGlobal(characterId, (t) {
        if (t.id == templateId) {
          t.steps = List.from(t.steps)..removeAt(index);
        }
      }),
    );
    _scheduleSave();
  }

  /// Move a template between the global pool and a character (or vice versa).
  /// `toCharacterId == null` means "make it global / visible to all".
  /// `fromCharacterId == null` means it currently lives in the global pool.
  void relocateTemplate(
      String? fromCharacterId, String? toCharacterId, String templateId) {
    if (fromCharacterId == toCharacterId) return;
    final list = _templateList(fromCharacterId);
    final idx = list.indexWhere((t) => t.id == templateId);
    if (idx < 0) return;
    final template = list[idx];

    if (fromCharacterId == null) {
      // global -> character: remove from globals
      final globals = state.globalTemplates.where((t) => t.id != templateId).toList();
      state = AppData(
        characters: state.characters.map((c) {
          if (c.id == toCharacterId) c.templates.add(template);
          return c;
        }).toList(),
        globalTemplates: globals,
      );
    } else {
      // character -> (global or another character)
      final chars = state.characters.map((c) {
        if (c.id == fromCharacterId) {
          c.templates = c.templates.where((t) => t.id != templateId).toList();
        }
        if (c.id == toCharacterId) {
          c.templates.add(template);
        }
        return c;
      }).toList();
      final globals = toCharacterId == null
          ? [...state.globalTemplates, template]
          : state.globalTemplates;
      state = AppData(
        characters: chars,
        globalTemplates: globals,
      );
    }
    _scheduleSave();
  }

  /// Helper: rebuild the global list applying [mutator]. No-op when the
  /// template lives on a character (characterId != null).
  List<MoveTemplate> _mutateGlobal(
      String? characterId, void Function(MoveTemplate) mutator) {
    if (characterId != null) return state.globalTemplates;
    final copy = state.globalTemplates.map((t) {
      mutator(t);
      return t;
    }).toList();
    return copy;
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

  /// Merge [incoming] into the current data instead of replacing it.
  /// Dedupes by id at every level (character → entry → combo; global +
  /// per-character templates), preserving existing items and only adding the
  /// ones that are missing.
  Future<bool> mergeImportData() async {
    final incoming = await _fileIo.importFromFile();
    if (incoming == null) return false;
    state = _merge(state, incoming);
    await _fileIo.saveLocal(state);
    return true;
  }

  static AppData _merge(AppData local, AppData incoming) {
    // --- Characters: key by id, merge entries + per-character templates ---
    final charById = <String, Character>{
      for (final c in local.characters) c.id: c,
    };
    for (final inc in incoming.characters) {
      final existing = charById[inc.id];
      if (existing == null) {
        charById[inc.id] = inc;
      } else {
        existing.entries = _mergeEntries(existing.entries, inc.entries);
        // Per-character templates must be merged too (dedupe by id), otherwise
        // newly-added character templates on the incoming side get lost.
        existing.templates =
            _mergeTemplates(existing.templates, inc.templates);
      }
    }

    // --- Global templates: dedupe by id ---
    final globals = _mergeTemplates(local.globalTemplates, incoming.globalTemplates);

    return AppData(
      characters: charById.values.toList(),
      globalTemplates: globals,
      pdfExportMode: local.pdfExportMode,
    );
  }

  /// Merge two template lists by id: keep all of [local], then add any from
  /// [incoming] whose id isn't already present.
  static List<MoveTemplate> _mergeTemplates(
      List<MoveTemplate> local, List<MoveTemplate> incoming) {
    final seen = <String>{};
    final out = <MoveTemplate>[];
    for (final t in local) {
      if (seen.add(t.id)) out.add(t);
    }
    for (final t in incoming) {
      if (seen.add(t.id)) out.add(t);
    }
    return out;
  }

  static List<Entry> _mergeEntries(List<Entry> local, List<Entry> incoming) {
    final byId = <String, Entry>{for (final e in local) e.id: e};
    for (final inc in incoming) {
      final existing = byId[inc.id];
      if (existing == null) {
        byId[inc.id] = inc;
      } else {
        existing.combos = _mergeCombos(existing.combos, inc.combos);
      }
    }
    return byId.values.toList();
  }

  static List<Combo> _mergeCombos(List<Combo> local, List<Combo> incoming) {
    final byId = <String, Combo>{for (final c in local) c.id: c};
    for (final inc in incoming) {
      byId.putIfAbsent(inc.id, () => inc);
    }
    return byId.values.toList();
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
