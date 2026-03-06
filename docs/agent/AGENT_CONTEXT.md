
# AGENT_CONTEXT.md

## Project Overview

This repository contains the implementation of a small prototype game called:

Signal Routing Panic

It is a real-time grid-based puzzle game where the player manages a network of flowing signals and routes them correctly to avoid system overload.

The project is intentionally small and focused.

The goal is not to build a full game but a clean, maintainable prototype.

---

# Project Goals

The prototype should demonstrate:

- a real-time routing puzzle system
- keyboard-only gameplay
- modular architecture
- readable game state
- deterministic signal simulation

The final result should be easy to extend later but should not attempt to implement future features yet.

---

# Design Philosophy

The design prioritizes:

1. clarity
2. simplicity
3. maintainability
4. deterministic simulation
5. small scope

If a choice exists between a complex solution and a simpler one, prefer the simpler one.

---

# Gameplay Summary

The player controls a cursor on a grid.

Signals are emitted by sources and travel through wires and routing components.

The player rotates or toggles components to route signals toward compatible sinks.

Correct routing increases progress toward the level objective.

Incorrect routing increases a global overload meter.

If overload reaches its maximum the player loses.

The player wins by completing signal delivery quotas.

---

# Core Systems

The game consists of the following primary systems:

Grid System
Represents the tile-based board and component layout.

Signal Simulation
Handles signal spawning, movement, and routing logic.

Component System
Defines behavior for wires, splitters, gates, sources, and sinks.

Game State Flow
Controls gameplay state, pause state, win/lose state, and menus.

HUD System
Displays overload meter and objectives.

Level Data
Defines board layout and configuration.

---

# Constraints

This project intentionally limits scope.

The following features are explicitly out of scope:

procedural generation
save systems
multiplayer
campaign progression
mouse input
level editor
advanced visual effects

Do not add these features.

---

# Implementation Strategy

The correct strategy is:

1. bootstrap project
2. implement grid and cursor
3. implement routing components
4. implement signal flow
5. implement failure system
6. implement objectives
7. implement UI
8. create levels
9. polish and document

Focus on finishing a clean vertical slice.

---

# Decision Guidelines

If the specification leaves something undefined:

Prefer:

- smaller scope
- simpler implementation
- deterministic behavior
- readable systems

Avoid:

- overengineering
- speculative features
- complex simulation

---

# Long-Term Vision

This prototype could later evolve into:

- additional component types
- more signal behaviors
- larger levels
- endless mode
- level editor
- visual polish

However, none of these belong in version 1.

---

# Completion Definition

The project is complete when:

- the game runs
- all required mechanics exist
- 3 levels are playable
- keyboard-only play works
- the repository is clean and documented

After this point development should stop.
