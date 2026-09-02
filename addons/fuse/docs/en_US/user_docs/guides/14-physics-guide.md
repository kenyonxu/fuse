> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/14-physics-guide.md) | English

# Physics System Guide

The Fuse physics system provides 5 physics instructions and 10 physics events, covering common physics interaction needs such as applying forces, setting velocity, collision detection, area detection, raycasting, and on-screen visibility detection. All components support both 2D and 3D physics.

## Instruction List

| Name | Description | Key parameters |
|------|----------|----------|
| **ApplyForce** | Apply a continuous force to a RigidBody (e.g. wind, thrusters) | `target_node` (target physics body), `use_3d` (whether 3D), `force` / `force_3d` (force vector), `use_center` (whether to apply at the center), `force_position` (force application offset position) |
| **ApplyImpulse** | Apply an instant impulse to a RigidBody (e.g. explosions, jumps) | `target_node` (target physics body), `use_3d` (whether 3D), `impulse` / `impulse_3d` (impulse vector), `use_center` (whether to apply at the center), `impulse_position` (impulse application offset position) |
| **SetVelocity** | Set a physics body's velocity (CharacterBody / RigidBody) | `target_node` (target physics body), `use_3d` (whether 3D), `velocity` / `velocity_3d` (velocity vector), `use_local_space` (whether to use the local coordinate system) |
| **SetCollisionLayer** | Set a collision object's collision layer and/or mask | `target_node` (target collision object), `set_type` (set type: Layer/Mask/Both), `layer_value` (layer value), `mask_value` (mask value) |
| **Raycast** | Cast a ray from a given position to detect collisions | `use_3d` (whether 3D), `from_position` / `from_position_3d` (start point), `to_position` / `to_position_3d` (end point), `collision_mask` (collision layer mask), `exclude_target` (exclude node), `save_result` (whether to save to a variable), `result_variable` (variable name) |

### Instruction Usage Notes

**ApplyForce vs ApplyImpulse:**
- `ApplyForce` applies a continuous force, suited to effects like wind or thrusters; it must be called repeatedly every physics frame
- `ApplyImpulse` applies an instant impulse, suited to one-shot effects like explosions or jumps

**Force application position:**
- With `use_center = true`, the force is applied at the object's center and produces no rotation
- With `use_center = false`, the force is applied at the offset position and produces a rotational torque

**SetVelocity target types:**
- CharacterBody2D/3D: sets the `velocity` property directly
- RigidBody2D/3D: sets the `linear_velocity` property, with local coordinate system conversion support

**Raycast result format:**
When saved to a variable, a dictionary is returned:
```json
{
  "collider": <collider object or null>,
  "point": <collision point Vector2/Vector3>,
  "normal": <collision normal Vector2/Vector3>,
  "distance": <distance float>
}
```

---

## Event List

| Name | Trigger condition | Output data |
|------|----------|----------|
| **OnArea2DEnter** | A PhysicsBody or Area enters an Area2D region | `body` (entering body), `area` (the entered Area2D) |
| **OnArea2DExited** | A PhysicsBody or Area leaves an Area2D region | `body` (leaving body), `area` (the exited Area2D) |
| **OnArea3DEntered** | A PhysicsBody or Area enters an Area3D region | `body` (entering body), `area` (the entered Area3D) |
| **OnArea3DExited** | A PhysicsBody or Area leaves an Area3D region | `body` (leaving body), `area` (the exited Area3D) |
| **OnBodyEntered** | A PhysicsBody enters an Area2D region | `body` (the entering PhysicsBody2D) |
| **OnCollision** | Fires when physics bodies collide | `collider` (collider), `collider_shape_index`, `local_shape_index`, `target_shape`, `body_shape`, `collider_velocity` (for CharacterBody) |
| **OnOverlappingBodies** | The number of overlapping bodies in a region meets a threshold condition | `count` (current overlap count) |
| **OnShapeCast** | A ShapeCast detects a collision | `collider` (collider), `collision_point` (collision point), `collision_normal` (collision normal) |
| **OnRaycastHit** | Fires when a RayCast ray hits an object | `collider` (collider), `collision_point` (collision point), `collision_normal` (collision normal), `raycast_origin` (ray origin) |
| **OnScreenEnteredExited** | A node enters or leaves the camera's view | `target_node` (target node), `is_on_screen`, `was_on_screen`, `event_type` ("entered" / "exited") |

### Event Usage Notes

**Common parameters for area events:**
- `area_node_path` / `area_node`: target Area node path
- `target_group`: target group name filter; matches any body when empty
- `trigger_once_per_body`: fires only once per body (fires on enter, resets after exit)

**OnOverlappingBodies comparison modes:**
- `Greater`: fires when the count is greater than the threshold
- `Less`: fires when the count is less than the threshold
- `Equal`: fires when the count equals the threshold

**OnScreenEnteredExited trigger timing:**
- `ENTER`: fires only when entering the screen
- `EXIT`: fires only when leaving the screen
- `BOTH`: fires on both entering and leaving

**OnCollision collision layer filtering:**
Set `collision_mask` to filter colliders by collision layer; 0 means no filtering.

---

## Common Use Cases

### 1. Platformer - Character Jump

Use `OnBodyEntered` to detect the character landing, and `ApplyImpulse` to apply the jump impulse:

```
# Event: detect the character colliding with the ground
OnBodyEntered → area_node: GroundArea, target_group: "player"

# Instruction: apply the jump impulse
ApplyImpulse → target_node: Player, impulse: (0, -500), use_center: true
```

### 2. 2D Game - Enemy Vision Detection

Use `OnRaycastHit` to detect whether an enemy can see the player:

```
# Event: raycast detection
OnRaycastHit → origin_node_path: Enemy, target_position: (200, 0), collision_mask: Layer 1

# Instructions (run after the event fires):
# trigger chase logic once a collider is detected
```

### 3. Multiplayer - Zone Headcount Detection

Use `OnOverlappingBodies` to detect the number of players in a region:

```
# Event: fires when the number of bodies in the region >= 2
OnOverlappingBodies → area_node: ZoneArea, comparison: Greater, check_threshold: 2, trigger_once: true, emit_count: true
```
