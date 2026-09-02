> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/16-camera-guide.md) | English

# Camera System Guide

The Fuse camera system provides 4 camera instructions covering camera following, zoom control, boundary limits, and screen shake effects, suited to common camera control needs in 2D games.

## Instruction List

| Name | Description | Key parameters |
|------|----------|----------|
| **CameraFollow** | Make the camera follow a target node | `target_node` (follow target), `camera_node` (camera node), `follow_mode` (follow mode: Lock/Smooth/Damped), `smooth_speed` (smoothing speed), `damping` (whether to enable damping), `enabled` (whether enabled) |
| **SetCameraZoom** | Set the Camera2D's zoom level | `target_node` (target Camera2D), `zoom_source` (zoom source: Direct/Variable), `zoom` (direct zoom value), `zoom_variable` / `zoom_scope` (read the zoom value from a variable) |
| **SetCameraLimit** | Set the Camera2D's movement boundary limits | `target_node` (target Camera2D), `limit_side` (boundary direction: Top/Bottom/Left/Right), `limit_value` (boundary value, -9999 means unlimited) |
| **CameraShake** | Trigger a camera shake effect (async instruction) | `target_node` (target camera), `intensity` (shake intensity 0.0-1.0), `duration` (duration in seconds) |

### Instruction Usage Notes

**CameraFollow follow modes:**
- `LOCK`: the camera locks to the target position immediately, with no lag
- `SMOOTH`: the camera smoothly tracks the target at the given speed (controlled via `smooth_speed`)
- `DAMPED`: uses physical damping for a natural decelerating follow effect (enabled or not via `damping`)

**SetCameraZoom zoom sources:**
- `DIRECT`: specify the zoom value directly
- `VARIABLE`: read the zoom value from a variable, supporting all three Local/Scope/Global scopes

**SetCameraLimit boundary directions:**
- `TOP` / `BOTTOM` / `LEFT` / `RIGHT`: set the camera's movement limit in each of the four directions
- Setting `limit_value` to `-9999` means no limit in that direction

**CameraShake:**
- Async instruction; it marks completion only after the shake duration ends
- Uses random offsets for a natural shake effect, running at 30 FPS

---

## Common Use Cases

### 1. Side-scrolling Game - Camera Follows the Player

```
# Set up camera following at game initialization
CameraFollow → target_node: Player, camera_node: Camera2D, follow_mode: Smooth, smooth_speed: 8.0
```

### 2. Level Boundary Limits

```
# Keep the camera from leaving the level bounds
SetCameraLimit → target_node: Camera2D, limit_side: Left, limit_value: 0
SetCameraLimit → target_node: Camera2D, limit_side: Right, limit_value: 1920
SetCameraLimit → target_node: Camera2D, limit_side: Top, limit_value: 0
SetCameraLimit → target_node: Camera2D, limit_side: Bottom, limit_value: 1080
```

### 3. Explosion/Hit Feedback

```
# Trigger a camera shake when hit
CameraShake → target_node: Camera2D, intensity: 0.8, duration: 0.3
```
