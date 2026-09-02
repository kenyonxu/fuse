> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/15-ui-guide.md) | English

# UI System Guide

The Fuse UI system provides 4 UI instructions and 5 UI events, covering common UI interaction needs such as setting text, switching textures, progress bar control, visibility management, plus button presses, value changes, text changes, item selection, and focus listening.

## Instruction List

| Name | Description | Key parameters |
|------|----------|----------|
| **SetUIText** | Set a UI node's text content | `target_node` (target UI node), `use_variable` (whether to read text from a variable), `text` (direct text), `text_variable` / `text_scope` (text variable name and scope) |
| **SetUITexture** | Set a TextureRect's texture resource | `target_node` (target TextureRect), `texture_source` (texture source: Resource Path/Variable), `texture_path` (texture file path), `texture_variable` / `texture_scope` (texture variable name and scope) |
| **SetUIProgress** | Set a ProgressBar's progress value | `target_node` (target ProgressBar), `use_variable` (whether to read the progress value from a variable), `value` (direct progress value 0.0-1.0), `value_variable` / `value_scope` (progress value variable name and scope) |
| **ShowHideUI** | Control a UI node's visibility | `target_node` (target UI node), `action` (action: Show/Hide/Toggle) |

### Instruction Usage Notes

**SetUIText:**
- Supports controls with a `text` property, such as Label, RichTextLabel, Button, LineEdit, and TextEdit
- In variable mode, non-string types are automatically converted to strings

**SetUITexture texture sources:**
- `RESOURCE_PATH`: load the texture from a file path
- `VARIABLE`: get the texture resource from a variable (the variable value must be a CompressedTexture2D or similar)

**ShowHideUI action types:**
- `SHOW`: show the node
- `HIDE`: hide the node
- `TOGGLE`: toggle the current visibility state

---

## Event List

| Name | Trigger condition | Output data |
|------|----------|----------|
| **OnButtonPressed** | Fires when a Button node is pressed | `button` (button node, optional) |
| **OnValueChanged** | Fires when a Slider/SpinBox/ProgressBar value changes | `value` (current value), `old_value` (old value), `delta` (change amount) |
| **OnTextChanged** | Fires when LineEdit/TextEdit text changes | `text` (current text), `old_text` (old text) |
| **OnItemSelected** | Fires when an ItemList control's selection changes | `selected_indices` (array of selected indices), `selected_count` (number selected) |
| **OnFocus** | Fires when a Control node gains or loses focus | `target_node` (target node), `focus_type` ("entered" / "exited") |

### Event Usage Notes

**OnButtonPressed:**
- `require_enabled`: when enabled, fires only while the button is not disabled
- `emit_button`: when enabled, passes the button node as event data

**OnValueChanged trigger modes:**
- `ON_ANY_CHANGE`: fires on any value change
- `ON_THRESHOLD`: fires when the value reaches the specified threshold (`threshold_value`)
- `ON_MIN_REACHED`: fires when the value reaches the minimum threshold (`min_threshold`)
- `ON_MAX_REACHED`: fires when the value reaches the maximum threshold (`max_threshold`)

**OnTextChanged trigger modes:**
- `ON_CHANGE`: fires when the text changes
- `ON_EMPTY`: fires when the text is empty
- `ON_MAX_LENGTH`: fires when the maximum length is reached (`max_length`)
- `ON_PATTERN_MATCH`: fires when a regex pattern is matched (`pattern`)

**OnItemSelected:**
- `multi_select_mode`: enables multi-select mode
- `emit_indices`: whether to pass the array of selected indices
- `emit_count`: whether to pass the number of selected items

**OnFocus listen modes:**
- `ON_ENTERED`: fires only when focus is gained
- `ON_EXITED`: fires only when focus is lost
- `ON_BOTH`: fires on both gaining and losing focus

---

## Common Use Cases

### 1. HP Bar Update

Use `SetUIProgress` with a variable to update the HP bar in real time:

```
# Update the HP bar
SetUIProgress → target_node: HPBar, use_variable: true, value_variable: hp_ratio, value_scope: Local
```

### 2. Score Display

Use `SetUIText` with a variable to display the current score:

```
# Update the score text
SetUIText → target_node: ScoreLabel, use_variable: true, text_variable: score_text, text_scope: Local
```

### 3. Pause Menu Toggle

Use `ShowHideUI`'s Toggle mode to switch the pause panel:

```
# Toggle the pause menu
ShowHideUI → target_node: PausePanel, action: Toggle
```
