# Signal Routing Panic

Signal Routing Panic is a keyboard-only, real-time grid puzzle prototype. You operate a live signal network, rotate/toggle routing components, deliver colored signal types to matching sinks, and prevent system overload.

## Tech Stack
- Engine: Godot 4.x
- Language: GDScript
- Level format: JSON data files under `game/levels`
- Python tooling: `uv` + `ruff` (repo-local `.venv`)

## Setup
1. Install Godot 4.x.
2. Install `uv` (system tool).
3. Clone this repository.
4. Create a local Python environment for tooling:
   - `uv venv .venv`
5. Sync tooling dependencies into the local environment:
   - `uv sync`
6. Open the repository folder in Godot.

## Run
1. Open project in Godot.
2. Press `F5` to run.
3. The game starts at the main menu.
4. Select `Settings` from the main menu to change windowed resolution presets.
5. Select `Level Select` to jump directly to any of the three handcrafted levels.
6. Select `How To Play` for a concise controls/mechanics reference.

## Python Tooling
All Python tooling for this repo is local to `.venv` and managed by `uv`.

- Create environment:
  - `uv venv .venv`
- Install/sync tooling dependencies:
  - `uv sync`
- Run lint:
  - `uv run ruff check .`
- Run format check:
  - `uv run ruff format --check .`
- Apply formatting:
  - `uv run ruff format .`

If you add Python helper scripts later, run them through the local environment:
- `uv run python path/to/script.py`

## Controls
### Menus
- `Up/Down` or `W/S`: Move selection
- `Left/Right` or `A/D`: Adjust settings sliders
- `Enter`: Confirm
- `Esc`: Back

### Settings Menu
- Accessible from main menu.
- Keyboard only navigation (`Up/Down`, `Enter`, `Esc`).
- `Left/Right` adjusts slider values.
- SFX volume slider (global).
- Music volume slider (global background track).
- Resolution presets (windowed mode): `1024x576`, `1280x720`, `1600x900`.
- The currently active preset is marked with `[X]`.
- Settings are persisted to `user://settings.cfg` and restored on next launch.

### Gameplay
- `Arrow Keys` or `WASD`: Move cursor
- `Space`: Interact with selected tile (rotate/toggle)
- `R`: Restart current level
- `Esc`: Pause/resume

## Game Summary
- Each level starts with a 3-second countdown while the board is already visible.
- During countdown, you can move the cursor and pre-rotate/toggle components.
- Signals and overload progression start only after the countdown ends.
- Sources emit signals continuously based on per-level spawn intervals.
- Signals step tile-to-tile in real time.
- You route them through wires/components to compatible sinks.
- Routing failures increase a global overload meter.
- Reach each level's delivery quotas before overload reaches maximum.

## Architecture Overview
- `game/systems/level_loader.gd`
  - Loads JSON levels into normalized tile grids.
- `game/systems/component_rules.gd`
  - Tile behavior rules, connectivity, interaction behavior.
- `game/systems/signal_simulator.gd`
  - Deterministic fixed-step simulation (spawn, movement, delivery/failure).
- `game/systems/game_session.gd`
  - Global level progression/session state.
- `game/ui/board_view.gd`
  - Board rendering, component orientation visuals, signal rendering, cursor highlight.
- `game/ui/hud.gd`
  - Overload meter, level name, objectives, status text.
- `game/ui/menu_panel.gd`
  - Reusable keyboard menu for main/pause/complete/game-over flows.
- `game/ui/menu_background.gd`
  - Main menu background presentation rendering.
- `game/scenes/main_menu.*` and `game/scenes/gameplay.*`
  - Scene flow and runtime state handling.
- `game/audio/audio_hooks.gd`
  - Placeholder sound event hook points.

## Level Definition Method
Levels are data-driven JSON files (`game/levels/level_01.json` ... `level_03.json`).

Each level defines:
- board size
- simulation step time
- overload maximum
- objective quotas per signal type
- component placements with orientation/state/source/sink properties

Core logic is not hardcoded per level; level files only provide board configuration.

## Key Implementation Decisions
- Simulation model: fixed-step discrete tile movement for determinism and readability.
- Signal types: `blue` and `red`, with both color and letter markers (`B`/`R`) to avoid color-only distinction.
- Splitter behavior: deterministic alternating output. Each accepted signal is routed to one output, then the splitter toggles to the other output for the next accepted signal.
- Gate behavior: single input with two output states; `Space` toggles active output.

## Repository Structure
- `project.godot`
- `pyproject.toml`
- `uv.lock`
- `game/scenes`
- `game/systems`
- `game/ui`
- `game/levels`
- `game/audio`
- `game/assets`

## Version 1 Scope Included
- Main menu
- Pause flow
- Level-complete flow
- Game-over flow
- Restart support
- Real-time signal simulation
- Overload failure system
- Objectives + HUD
- Exactly 3 handcrafted levels
- Keyboard-only play

## Known Limitations / Next Steps
- Placeholder audio hooks are implemented, but no shipped sound assets yet.
- No mouse interactions by design (keyboard-first prototype scope).
- No save/load, procedural generation, or meta progression (out of scope for v1).
- No collision/loop-advanced simulation rules beyond required prototype behavior.
- There are currently no Python helper scripts in this repo; Python is only used for local dev tooling (`ruff`).

## Environment Notes
- Godot remains a system-wide dependency (for example Homebrew install) and is not installed in `.venv`.
- `.venv` is only for Python-based repository tooling.
