
# agent-instructions.md

## Role

You are a coding agent responsible for implementing a small game prototype based on the specification in:

signal-routing-panic-agent-ready-spec.md

You start from an empty repository except for the specification file.

Your task is to build a complete version 1 prototype that satisfies the specification.
Do not expand the scope beyond what is defined in the spec.

---

# 1. Primary Source of Truth

The authoritative specification is:

signal-routing-panic-agent-ready-spec.md

If ambiguity arises:

1. Prefer the simplest interpretation
2. Prefer smaller scope
3. Prefer deterministic systems
4. Prefer readability over visual polish

Do not invent new mechanics unless strictly necessary.

---

# 2. Development Philosophy

Follow these principles:

### Keep the system small
Build the smallest working version first.

### Implement vertically
Prefer building a minimal playable loop rather than many incomplete systems.

### Avoid premature abstraction
Keep the architecture clean but avoid unnecessary complexity.

### Maintain board readability
Clarity of the grid and signal flow is more important than visual fidelity.

---

# 3. Expected Workflow

Implement the project following the phases defined in the specification section:

Exact Build Sequence

Do not change the implementation order unless technically required.

---

# 4. Commit Strategy

Commit after each major phase.

Example commit progression:

bootstrap project
implement grid and cursor
implement basic wires
implement signal simulation
implement overload system
implement advanced components
implement HUD and objectives
implement menu flow
add levels
polish and documentation

Every commit should leave the repository in a working state.

---

# 5. Technical Decision Rules

If a design choice is not specified:

Choose the option that is:

1. simpler
2. easier to maintain
3. easier to understand
4. easier to debug

Document major decisions in README.md.

---

# 6. Code Quality Expectations

The codebase must be:

- modular
- readable
- logically structured
- easy to extend

Avoid:

- large monolithic files
- deeply nested logic
- hardcoded level data inside gameplay logic

---

# 7. Repository Structure

Use a clear structure similar to:

/project-root
  README.md
  /game
    /systems
    /components
    /ui
    /levels
    /assets

Exact naming may depend on the chosen engine.

---

# 8. README Requirements

The README must include:

Game Summary
Tech Stack
Setup Instructions
Run Instructions
Controls
Architecture Overview
Level Definition Method
Known Limitations

---

# 9. Implementation Constraints

Do NOT add:

- procedural generation
- multiplayer
- story systems
- meta progression
- achievements
- save systems
- online functionality
- mouse input
- complex visual effects

Remain within prototype scope.

---

# 10. Final Validation Checklist

Before finishing verify:

The game:

- launches successfully
- works without mouse input
- supports all required controls
- contains 3 playable handcrafted levels
- includes all required components
- includes overload failure system
- includes win conditions
- includes menu flow

The repository:

- runs from README instructions
- has a clear structure
- includes architecture notes
- includes known limitations

---

# 11. Final Output

The repository must contain:

- source code
- README.md
- playable prototype
- 3 levels
- modular architecture
- documentation

Stop after completing version 1.
