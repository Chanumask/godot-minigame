# Signal Routing Panic — Agent-Ready Build Specification

## Status of This Document
This document is the authoritative implementation brief for a coding agent. It is written to be handed over directly.

The coding agent starts from an **empty repository** and is expected to build a **playable version 1 prototype** of the game described below.

The agent should **not** reinterpret the core game concept, expand scope, or invent major mechanics outside this specification unless a requirement here explicitly allows implementation freedom.

---

## 1. Mission
Build a small but polished prototype of **Signal Routing Panic**.

**Signal Routing Panic** is a:
- single-player
- real-time
- puzzle game
- fully playable with keyboard only
- grid-based systems game

The player manages a live network of flowing signals on a 2D grid. Signals are emitted continuously by source nodes and must be routed through wires and interactive components into valid sinks. Incorrect routing causes overload. The player wins by fulfilling delivery quotas before overload reaches the maximum.

---

## 2. Non-Negotiable Product Constraints

These are hard constraints. Do not violate them.

### 2.1 Input Constraints
- The game must be fully playable without a mouse.
- The game must not require mouse input for menus or gameplay.
- The game must be designed keyboard-first, not keyboard-compatible as an afterthought.

### 2.2 Genre Constraints
- The game must remain a **real-time puzzle game**.
- Do not turn it into an action game, roguelike, management sim, or arcade score-chaser.
- Pressure should come from routing and prioritization, not from combat or dexterity-heavy avoidance.

### 2.3 Scope Constraints
- Build a **vertical slice / prototype**, not a content-heavy full game.
- Only one mode is required.
- Exactly **3 handcrafted playable levels** are required for version 1.
- No procedural generation.
- No save/load system.
- No online features.
- No level editor.
- No meta progression.
- No story content required.

### 2.4 Readability Constraints
- Board state must remain readable at all times.
- Avoid visual clutter.
- Avoid excessive effects.
- Do not rely on color alone to distinguish signal types or sink compatibility.

### 2.5 Implementation Constraints
- Prefer simple, deterministic, maintainable systems.
- Favor clean architecture over flashy polish.
- Do not hardcode the full game inside one large script.
- Levels must be stored separately from core simulation logic.

---

## 3. Preferred Technical Stack

### 3.1 Preferred Engine
Use **Godot 4.x** unless there is a compelling reason not to.

### 3.2 Allowed Alternatives
If needed, the agent may instead use:
- Pygame / Python
- Love2D / Lua

### 3.3 Decision Rule
If not using Godot 4.x, document the reason clearly in the README.

### 3.4 Build Goal
The project must run locally from a clean checkout using the instructions in the README.

---

## 4. Required Deliverables

The finished repository must contain at minimum:

1. Full source code
2. A root-level `README.md`
3. A playable prototype
4. 3 handcrafted levels
5. Menu flow
6. Pause and restart support
7. Basic placeholder audio hooks or sound stubs
8. Separate level data from core gameplay logic
9. Brief architecture notes in the README
10. Brief known limitations / next steps section in the README

---

## 5. Success Definition

The project is complete only when all of the following are true:

- The game launches successfully from a clean repo checkout by following the README.
- The player can navigate menus by keyboard only.
- The player can complete all gameplay by keyboard only.
- There is a main menu.
- There is a gameplay scene/state.
- There is a pause flow.
- There is a level-complete flow.
- There is a game-over flow.
- There are exactly 3 playable handcrafted levels.
- Signals move in real time.
- The player can manipulate board components.
- Overload increases when routing errors occur.
- The player loses when overload reaches max.
- The player wins a level by fulfilling delivery quotas.
- The repository structure is modular and understandable.

---

## 6. Core Design Summary

### 6.1 High-Level Player Fantasy
The player acts as an operator maintaining a fragile signal-processing machine under pressure.

### 6.2 Core Challenge
The player must understand a live routing system, identify bottlenecks or errors, and reconfigure the board in time.

### 6.3 Design Pillars
These pillars must guide decisions:

1. **Readable at a glance**
2. **Keyboard-first**
3. **Simple rules, meaningful combinations**
4. **Pressure from prioritization**
5. **Fast restart and iteration**

---

## 7. Core Gameplay Loop

The core loop is mandatory and should be implemented as follows:

1. Sources emit signals at configured time intervals.
2. Signals travel across the board in real time.
3. The player moves a cursor/focus across the grid.
4. The player interacts with the selected tile.
5. Interactions rotate or toggle routing components.
6. Correctly routed signals reach compatible sinks.
7. Incorrectly routed signals increase overload.
8. The player wins by fulfilling required sink quotas.
9. The player loses when overload reaches its maximum.

Do not replace this core loop with an alternative progression model.

---

## 8. Control Specification

All required controls must exist.

### 8.1 Gameplay Controls
- **Arrow keys or WASD**: Move cursor
- **Space**: Primary interaction on selected tile
- **R**: Restart current level
- **Esc**: Pause / resume

### 8.2 Menu Controls
- **Up / Down**: Navigate menu items
- **Enter**: Confirm selection
- **Esc**: Back / pause where applicable

### 8.3 Optional Controls
The following are allowed but not required:
- **Q / E**: Rotate counterclockwise / clockwise
- **Tab**: Jump between interactable tiles

### 8.4 Control Rules
- The player must not need a mouse at any point.
- Core play must not require simultaneous multi-key combinations.
- Inputs should be responsive and deterministic.
- Interactions must apply only to the currently selected tile.

---

## 9. Board and Grid Specification

### 9.1 Grid Model
- The level is a rectangular 2D grid.
- Recommended size range for version 1: **8x8 to 12x12**.
- Each tile contains either empty space or a component.

### 9.2 Required Tile Categories
Implement support for these categories:
- Empty
- Wall / blocker
- Wire component
- Interactive routing component
- Source
- Sink
- Optional hazard tile

### 9.3 Cursor Model
- The player controls a visible tile cursor.
- The cursor snaps tile-to-tile.
- The selected tile must always be obvious.

### 9.4 Board Readability Rules
- Component orientation must be visible.
- Signal direction must be inferable.
- The player must be able to understand the board without needing debug overlays.

---

## 10. Signal System Specification

### 10.1 Minimum Signal Properties
Each signal must track at least:
- current tile or position
- direction of travel
- signal type
- state needed for validity checks

### 10.2 Signal Timing
Signals must move in real time.

Allowed implementations:
- discrete stepping at a fixed simulation interval
- smooth interpolation backed by fixed logic steps

**Preferred for version 1:** discrete tile stepping.

### 10.3 Signal Types
At least **2 distinct signal types** are required.

Recommended example:
- Blue
- Red

Important: signal types must not be distinguished by color alone. Use shape, icon, outline, or another secondary distinction.

### 10.4 Signal Spawn Rules
- Sources emit signals at a configurable interval.
- Spawn interval must be level-configurable.
- Signal type must be defined by the source.

### 10.5 Signal Failure Rules
At minimum, overload must increase when one of the following happens:
- signal reaches a dead end
- signal reaches an incompatible sink
- signal exits into an invalid direction
- signal is otherwise lost due to incorrect routing

### 10.6 Simplification Rule
Collisions, loop detection, and advanced simulation are optional unless needed for clarity. Do not overcomplicate the first version.

---

## 11. Required Component Set

The following components are mandatory.

### 11.1 Straight Wire
Behavior:
- connects opposite sides

Required orientations:
- horizontal
- vertical

Interaction:
- rotate 90 degrees

### 11.2 Corner Wire
Behavior:
- connects two adjacent sides

Interaction:
- rotate through 4 orientations

### 11.3 Splitter
Behavior:
- accepts one incoming signal and routes it to two outputs or alternates outputs

Interaction:
- rotate through valid orientations

Implementation freedom:
- duplication behavior is allowed, or
- alternating-output behavior is allowed

Rule:
- whichever behavior is chosen must be documented in the README

### 11.4 Gate / Toggle Switch
Behavior:
- one of two routing states is active at a time

Interaction:
- toggle between state A and state B

Purpose:
- creates time-pressure decisions

### 11.5 Source
Behavior:
- emits signals

Required properties:
- signal type
- spawn interval
- emission direction

### 11.6 Sink
Behavior:
- accepts only compatible signals

Required properties:
- accepted signal type
- quota target or contribution toward objective

---

## 12. Failure Model and Global Pressure

### 12.1 Required Failure System
Implement a global **Overload Meter**.

### 12.2 Overload Increase Triggers
Overload must increase on routing mistakes.

At minimum, support these triggers:
- lost signal
- invalid endpoint
- incompatible sink delivery
- equivalent critical routing error

### 12.3 Overload Decrease Rule
For version 1, overload does **not** need to decrease automatically.

### 12.4 Lose Condition
The level is lost when overload reaches the configured maximum.

### 12.5 Feedback Requirements
Whenever overload increases, the game must provide:
- visual feedback
- HUD update
- sound hook or placeholder call

---

## 13. Objective Model

### 13.1 Mandatory Win Condition
Each level is completed when required delivery quotas are met.

Example:
- deliver 10 blue signals to blue sinks
- deliver 8 red signals to red sinks

### 13.2 Objective Tracking
The HUD must show quota progress clearly.

### 13.3 Optional Add-On
An additional short survive state after meeting quota is allowed, but not required. Do not add it unless it remains clean and readable.

---

## 14. UI and UX Requirements

### 14.1 Required HUD Elements
The gameplay HUD must show:
- overload meter
- objective progress
- current level name or number
- pause state when paused

### 14.2 Required Menu States
Implement:
- main menu
- pause menu
- level complete screen/state
- game over screen/state

### 14.3 Required Visual Feedback
- selected tile highlight
- clear component visuals per type
- visible component orientation
- distinct signal and sink identity
- visible feedback when a component rotates or toggles

### 14.4 Clarity Rules
- Do not overload the screen with text.
- Do not hide critical information.
- Ensure the player can learn controls quickly.

---

## 15. Level Content Specification

Build exactly **3 handcrafted levels**.

### 15.1 Level 1 — Introduction
Purpose:
- teach cursor movement
- teach rotating wires
- teach basic delivery of one signal type

Constraints:
- small board
- low pressure
- no splitter required
- simple success path

### 15.2 Level 2 — Mixed Routing
Purpose:
- teach two signal types
- teach gate usage
- introduce prioritization

Constraints:
- medium complexity
- one or two conflict points
- moderate spawn pressure

### 15.3 Level 3 — System Stress
Purpose:
- require splitter usage
- require managing multiple issues at once
- create sustained but fair real-time pressure

Constraints:
- highest complexity of the three
- still readable
- should reward understanding, not frantic spam

### 15.4 Level Design Rules
- Every level must be consistently solvable.
- Early levels must teach one new concept at a time.
- Avoid precision-timing requirements beyond reasonable reaction demands.
- Prefer problems of understanding and prioritization over raw speed.

---

## 16. Repository Structure Requirements

The exact filenames may vary, but the repository must be organized into clear areas.

A suitable structure should look conceptually like this:

```text
/project-root
  README.md
  /game
    /scenes or /states
    /systems
    /components
    /ui
    /levels
    /assets
```

### Mandatory Structural Rules
- Core gameplay logic must be separated from level content.
- UI/menu logic must not be mixed into the main simulation code unnecessarily.
- Signal simulation should be isolated enough to be testable/debuggable.

---

## 17. Architecture Requirements

Use a modular architecture.

### 17.1 Required System Separation
At minimum, keep the following concerns reasonably separated:
- input handling
- grid/board representation
- component definitions/behavior
- signal simulation
- level loading
- game state flow
- HUD/UI
- audio hooks

### 17.2 Data-Driven Levels
Levels should be defined in data or engine-native resources, not embedded as giant hardcoded arrays inside the main gameplay loop unless no better option exists.

Allowed formats include:
- JSON
- YAML
- Godot scenes/resources
- simple Python/Lua data files

### 17.3 Simplicity Rule
Do not introduce premature abstraction, but do avoid a monolithic implementation.

---

## 18. Exact Build Sequence

Follow this order unless a small deviation is necessary for the chosen engine.

### Phase 1 — Project Bootstrap
1. Initialize repository/project.
2. Create README with setup/run placeholder.
3. Create runnable application window.
4. Commit or structure project skeleton.

### Phase 2 — Grid and Cursor
1. Implement grid rendering.
2. Implement cursor movement.
3. Implement selected-tile highlight.
4. Verify keyboard-only movement flow.

### Phase 3 — Basic Routing Pieces
1. Implement empty and wall tiles.
2. Implement straight wire.
3. Implement corner wire.
4. Implement interaction and rotation.
5. Make orientation readable.

### Phase 4 — Signal Flow
1. Implement source tiles.
2. Implement sink tiles.
3. Implement signal spawning.
4. Implement tile-to-tile signal movement.
5. Implement success detection.
6. Implement failure detection.

### Phase 5 — Global Pressure
1. Implement overload meter.
2. Increase overload on failures.
3. Implement lose state.
4. Add basic visual feedback.

### Phase 6 — Advanced Routing Components
1. Implement gate/toggle component.
2. Implement splitter component.
3. Verify deterministic behavior.
4. Document chosen splitter behavior.

### Phase 7 — Objectives and HUD
1. Implement sink quotas/objectives.
2. Track progress.
3. Add HUD.
4. Implement win state.

### Phase 8 — Menus and Flow
1. Build main menu.
2. Build pause menu.
3. Build level complete flow.
4. Build game over flow.
5. Implement restart behavior.

### Phase 9 — Level Authoring
1. Create level 1.
2. Create level 2.
3. Create level 3.
4. Tune quotas and spawn rates.
5. Verify progression.

### Phase 10 — Polish and Documentation
1. Add placeholder sound hooks.
2. Improve readability and feedback.
3. Clean code/comments where helpful.
4. Finalize README.
5. Add known limitations / next steps.

---

## 19. README Requirements

The `README.md` must include:
- project name
- one-paragraph game summary
- chosen tech stack
- setup instructions
- run instructions
- controls
- short architecture overview
- note on how levels are defined
- note on any key implementation decisions
- known limitations / future improvements

If the agent deviates from the preferred stack or makes a meaningful mechanical interpretation choice, it must document that.

---

## 20. Allowed Implementation Freedom

The agent may decide the following details as long as all hard requirements remain satisfied:
- exact screen resolution
- visual style
- exact naming conventions
- exact asset placeholders
- exact file/folder names
- stepped vs interpolated signal movement
- exact splitter implementation
- exact menu presentation

Do not use this freedom to expand scope.

---

## 21. Explicitly Out of Scope

Do not add these unless absolutely necessary to support the required loop:
- procedural levels
- achievements
- campaign map
- dialogue/story scenes
- cutscenes
- mouse interactions
- character movement beyond cursor movement
- combat
- enemy AI
- score combo system
- accessibility settings menu
- rebinding UI
- save system
- online features
- full art/audio production pass

---

## 22. Final Instruction to the Coding Agent

Build the **smallest polished, maintainable, keyboard-only real-time puzzle prototype** that satisfies this specification.

When choosing between two implementation options, prefer:
1. clarity
2. determinism
3. readability
4. maintainability
5. lower scope

Do not invent additional major mechanics. Do not expand beyond the brief. Finish a clean version 1 prototype.
