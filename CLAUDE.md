# Claude Code Guidelines - Cepas Selvagens

## Project Architecture & Tech Stack
- **Engine:** Godot 4.7 Forward Plus (GDScript).
- **Core Design:** Action RPG sandbox with anatomical hunting, modular crafting (no primary attributes, Albion-style sockets), authoritative network layer, and living ecology.
- **Reference Docs:** See `PROJECT_CONTEXT.md`, `README.md`, `docs/gdd/`, `docs/decisions/` (ADRs 0001–0007), and `docs/blocos/` (blocks B01–B23).

## Critical GDScript Rules
- **Type Preloading:** To avoid "Could not find type 'X'" errors, always include explicit preloads (`const _Type = preload("res://...")`) at the top of scripts referencing custom class types.
- **Null Safety:** Always verify that `PackedScene.instantiate()` returns a valid node before assigning transforms or parenting.
- **Combat Resolution:** All damage flows as `HitEvent` through `CombatResolver` (ADR-0003).

## Verification & Commands
- **Run All Tests:** `godot --path . --headless -s res://tests/run_all.gd` or `.\setup_project.ps1`
- **Initial Asset Import:** `godot --headless --editor --quit`
- **Git Protocol:** Never commit directly to `master`. Create a feature branch (`feature/bXX-...`) and link PR to a GitHub Issue.
