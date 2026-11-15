# Project Descent

A 2D top-down action roguelike blending the high-density swarm combat of *Vampire Survivors* with the stage-based teleporter progression and risk/reward monuments of *Risk of Rain 2*.

Built from scratch in **Odin** using **`vendor:raylib`** with a focus on low-level data-oriented design, explicit memory layout, and simulation performance.

## Documentation

- [Game Context & Philosophy](docs/context.md)
- [Technical & Gameplay Specification](docs/spec.md)

## Tech Stack & Architecture

- **Language:** [Odin](https://odin-lang.org/)
- **Windowing / 2D Rendering / Audio:** `vendor:raylib` (bundled with the Odin compiler)
- **Simulation Design:**
  - **Structure of Arrays (`#soa`)** fixed-capacity pools (`MAX_ENEMIES = 16384`) with $O(1)$ swap-and-pop removal.
  - **Zero-Allocation Spatial Hash Grid:** Rebuilt every frame in $O(N)$ using intrusive index arrays (`cell_head` and `next_in_cell`) for fast 3x3 neighborhood broad-phase collision and swarm separation.
  - **Data-Driven Combat:** Usage-based ability leveling ("Muscle Memory") and single-slot Monument specializations (`Blood`, `Ice`, `Fire`, `Storm`).
  - **Per-Frame Scratch Memory:** Uses `context.temp_allocator` reset at the end of each frame via `free_all(context.temp_allocator)`.

## Prerequisites

Install the **Odin** compiler (which includes `vendor:raylib` out of the box):
- **From Release / Source:** [Odin Getting Started](https://odin-lang.org/docs/install/)

## Build & Run

```bash
# Build and run in development mode
odin run src -out:descent

# Build an optimized release binary
odin build src -out:descent -o:speed
./descent
```

## Controls (Starter Prototype)

- **WASD / Arrow Keys:** Move player
- **Mouse Cursor:** Aim auto-firing projectiles
