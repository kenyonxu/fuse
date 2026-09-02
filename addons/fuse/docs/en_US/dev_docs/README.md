> 🌐 [**中文版**](../../zh_CN/dev_docs/README.md) | English

# Developer Documentation (dev_docs)

Technical guides for Fuse system developers: how to create events / instructions / conditions, and how to use the runtime architecture, editor integration, and the various specialized tools.

> For user-facing usage documentation see [../user_docs/](../user_docs/); for architecture and system-level design see [../system_docs/](../system_docs/).

---

## 📚 Developer Guides (by Topic)

### Core Component Creation

| Guide | Description |
|------|------|
| [Event Creation Guide](guides/event-creation-guide.md) | `BaseEvent` subclassing, `RuntimeEventInstance` state isolation, signal management, complete template, and common pitfalls |
| [Instruction Creation Guide](guides/instruction-creation-guide.md) | `BaseInstruction` subclassing, execution methods, parameters, and localization |
| [Condition Creation Guide](guides/condition-creation-guide.md) | `BaseCondition` subclassing, composite conditions, validation logic |

### Runtime Architecture

| Guide | Description |
|------|------|
| [RuntimeInstructionInstance Guide](guides/runtime-instruction-instance-guide.md) | Runtime state isolation, timeout mechanism, pause / resume, signal connection management |
| [Event RuntimeInstance Migration Guide](guides/runtime-instance-migration-guide.md) | Migration steps to the declared-state pattern and the `_emit_triggered` rework (companion detail for the fuse_event_runtime_instance_migration skill) |
| [Multithreading Developer Guide](guides/multithreading-developer-guide.md) | Multithreaded execution model, thread-safety constraints |

### Editor Integration

| Guide | Description |
|------|------|
| [Conditional Property Display](guides/conditional-property-display-guide.md) | `_validate_property()`, dynamic Inspector property visibility, and conditional checks |
| [Icon System Design](guides/icon-system-guide.md) | Icon registration, configuration, built-in icon naming reference |

### Specialized Development

| Guide | Description |
|------|------|
| [Array Instructions Development](guides/array-instructions-guide.md) | The `element_value` property, variable-change notifications, translation key naming, debug logging |
| [Variable Operations Tools](guides/variable-operations-guide.md) | Variable read/write tool APIs and usage |
| [Translation Glossary (Chinese-English)](guides/translation-glossary-guide.md) | Terminology authority for the bilingual `docs/` (`en_US/` mirror) and the per-document translation checklist |

---

## 🎯 Task-Oriented Entry Points

### I want to create a new event / instruction / condition
→ [Event creation](guides/event-creation-guide.md) · [Instruction creation](guides/instruction-creation-guide.md) · [Condition creation](guides/condition-creation-guide.md)

### I want a component to support runtime state or pause / resume
→ [RuntimeInstructionInstance Guide](guides/runtime-instruction-instance-guide.md)

### I want concurrent execution or care about thread safety
→ [Multithreading Developer Guide](guides/multithreading-developer-guide.md)

### I want Inspector properties to show or hide dynamically based on conditions
→ [Conditional Property Display](guides/conditional-property-display-guide.md)

### I want to configure icons for components
→ [Icon System Design](guides/icon-system-guide.md)

### I am developing array-style instructions or debugging variable-change notifications
→ [Array Instructions Development](guides/array-instructions-guide.md) · [Variable Operations Tools](guides/variable-operations-guide.md)

---

## 🔗 Cross-Directory Resources

### Architecture and System Design (../system_docs/)
- Architecture overview: [visual_programming_system_architecture](../system_docs/architecture/visual_programming_system_architecture.md) and the [Complete Design Summary](../system_docs/architecture/visual_programming_complete_design_summary.md)
- Per-subsystem design: [Event](../system_docs/architecture/event_on_input_key_design.md) · [Instruction](../system_docs/architecture/instruction_system_design.md) · [Condition](../system_docs/architecture/condition_system_design.md) · [Variable](../system_docs/architecture/variable_system_design.md)
- Editor: [Editor Tools Design](../system_docs/architecture/editor_tools_design.md) · [Godot Integration Design](../system_docs/architecture/godot_integration_design.md)
- Data flow / control flow: [dataflow_controlflow_design](../system_docs/architecture/dataflow_controlflow_design.md)
- Component analyses: [BaseEvent](../system_docs/analysis/base_event_analysis.md) · [BaseInstruction](../system_docs/analysis/base_instruction_analysis.md) · [BaseCondition](../system_docs/analysis/base_condition_analysis.md) · [BaseVariable](../system_docs/analysis/base_variable_analysis.md) · [ExecutionContext](../system_docs/analysis/execution_context_analysis.md) · [ActionRunner](../system_docs/analysis/action_runner_analysis.md)

### User-Facing Guides (../user_docs/guides/)
- [Variable System Guide](../user_docs/guides/01-variable-system-guide.md) · [Global Variable Manager V2](../user_docs/guides/54-global-variables-guide.md) · [Global Variable Persistence](../user_docs/guides/54-global-variables-guide.md)
- [Instruction Generator](../user_docs/guides/06-instruction-generator-guide.md) · [Runner](../user_docs/guides/03-runner-guide.md) · [Multi-Event Trigger](../user_docs/guides/04-multi-event-trigger-guide.md) · [Event Bus](../user_docs/guides/34-event-bus-guide.md)
- [Multithreading Optimization](../user_docs/guides/52-multithreading-optimization.md) · [Expression](../user_docs/guides/05-expression-guide.md) · [Debugging](../user_docs/guides/25-debugging-guide.md) · [Icon Manager](../user_docs/guides/53-icon-manager-guide.md)

### Historical Archive
Historical implementation plans, interim reports, design proposals, and migration documents are archived in the local `../archive/` directory (not tracked in git; see .gitignore). For reference only — **not the authoritative source for the current implementation**; rely on the guides in this directory and on `system_docs/`.

---

## 📊 Documentation Statistics

| Category | Count |
|------|------|
| Developer guides | 9 (in `guides/`) |
| Update spec | 1 ([UPDATE_SPEC.md (Chinese)](../../zh_CN/dev_docs/UPDATE_SPEC.md)) |

---

## 📝 Maintenance

- **Code conventions**: GDScript 2.0, TAB indentation, type annotations, `##` doc comments (see the repo-root `CLAUDE.md` for details)
- **New guides**: put them in `guides/` and register them under the corresponding topic group in this README
- **Link health**: when adding or modifying documents, make sure all relative links point to files that actually exist

---

**Last updated**: 2026-09-02
**Maintainer**: Fuse development team
