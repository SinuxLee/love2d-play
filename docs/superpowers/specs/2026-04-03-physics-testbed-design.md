# Physics Testbed Design

## Overview

A Love2D physics engine testbed in `games/physics-testbed/` with interactive debug UI for tweaking Box2D parameters in real-time. Serves both as a learning tool for love.physics API and a reusable debugging environment for future physics-based games.

## Architecture

**Pattern:** Scene registration system. Each physics demo is an independent Lua module registered with a central testbed manager. A SUIT-based debug panel overlays the physics world for parameter manipulation.

```
games/physics-testbed/
├── main.lua                  # Entry point
├── conf.lua                  # Love2D config + monorepo paths
├── src/
│   ├── testbed.lua           # Core manager: scene registry, switching, world lifecycle
│   ├── debug_draw.lua        # Physics world visualization
│   ├── debug_panel.lua       # SUIT debug panel
│   ├── camera.lua            # Pan/zoom camera (HUMP-based)
│   └── scenes/
│       ├── init.lua           # Scene registry
│       ├── stacking.lua       # Box stacking
│       ├── chain.lua          # Chain/rope
│       ├── joints.lua         # Joint types showcase
│       ├── bouncing.lua       # Bouncing balls
│       ├── friction.lua       # Friction ramp
│       ├── restitution.lua    # Restitution comparison
│       ├── bridge.lua         # Bridge (chain + revolute joints)
│       ├── ragdoll.lua        # Ragdoll system
│       ├── particles.lua      # Particle simulation
│       └── playground.lua     # Free sandbox
```

## Dependencies

- **SUIT** (vendor/suit, git submodule) - Immediate mode GUI for debug panel
- **HUMP** (vendor/hump, existing) - Camera system

## Debug Panel Parameters

### Global Physics
- Gravity X / Y (slider)
- Physics Step Rate
- Velocity Iterations / Position Iterations

### Selected Body
- Mass / Density
- Friction
- Restitution
- Linear Damping / Angular Damping
- Fixed Rotation (checkbox)
- Is Bullet (checkbox)
- Body Type (static/dynamic/kinematic)

### Joint Parameters (contextual)
- Motor Speed / Max Motor Torque
- Frequency / Damping Ratio
- Lower/Upper Limit

### Debug Render Toggles
- Show Bodies / Joints / Contacts / AABBs
- Show Center of Mass / Velocity Vectors
- Wireframe Mode

### Simulation Control
- Pause / Step / Reset buttons
- Speed multiplier (0.25x - 4x)

## Interaction

- **Left click drag**: MouseJoint to drag bodies
- **Right click drag**: Pan camera
- **Scroll wheel**: Zoom
- **Click body**: Select, show properties in panel
- **R**: Reset current scene
- **Space**: Pause/resume
- **S**: Single step

## Data Flow

```
UI slider change → debug_panel updates value → testbed applies to world/body
Scene switch → testbed destroys old world → creates new world → calls scene.setup()
Per frame: world:update() → debug_draw renders → SUIT renders UI overlay
```

## Scenes

1. **stacking** - Pyramid of boxes falling onto a platform
2. **chain** - Chain links connected by revolute joints, dangling from fixed point
3. **joints** - Showcase of all joint types side by side
4. **bouncing** - Balls with varying restitution bouncing on surfaces
5. **friction** - Objects sliding down ramps with different friction coefficients
6. **restitution** - Side-by-side comparison of restitution values (0.0 to 1.0)
7. **bridge** - Plank bridge made of segments connected by revolute joints
8. **ragdoll** - Multi-body ragdoll with joint limits
9. **particles** - Many small bodies simulating fluid/particles
10. **playground** - Free sandbox: click to spawn shapes, drag to interact
