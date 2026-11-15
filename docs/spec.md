# Technical & Game Specification (Spec)

## 1. Development Architecture
* **Language & Toolchain:** **Odin** (`odin build src -out:descent`), leveraging manual memory management, built-in array programming, custom allocators (`context.allocator` / `context.temp_allocator`), and fast compile times.
* **Windowing, Rendering & Audio:** **`vendor:raylib`** (ships with the Odin compiler). Uses immediate-mode 2D rendering backed by `rlgl` automatic sprite/quad batching.
* **Memory Layout & Entity Storage:**
  * Zero mid-frame heap allocations for gameplay entities. All simulation state lives in a single root `Game_State` struct.
  * Hot entity collections (such as enemies and projectiles) use fixed-capacity **Structure of Arrays (`#soa`)** pools with **swap-and-pop ($O(1)$)** deletion to keep active elements tightly packed and CPU cache-friendly.
  * Temporary per-frame allocations (e.g., spatial hash query buffers, UI string formatting) use `context.temp_allocator`, cleared at the end of every frame via `free_all(context.temp_allocator)`.
* **Broad-Phase Collision & Spatial Queries:**
  * A uniform 2D **Spatial Hash Grid** rebuilt from scratch each frame in $O(N)$ time using a flat intrusive linked-list (`cell_head` + `next_in_cell` index arrays), enabling fast neighbor lookups for swarm soft-separation, melee sweeps, and projectile hits.
* **Enemy AI & Swarm Simulation:**
  * Direct vector steering toward the player combined with local neighbor repulsion queried via the spatial hash grid. Can be extended with a 2D Dijkstra Flow Field around Monuments and terrain obstacles.
* **Data-Driven Combat & Specializations:**
  * Abilities and specializations are plain data structs and bitflags (`bit_set`), avoiding OOP inheritance hierarchies. On-hit hooks resolve specialization modifiers directly from ability state.

## 2. Core Gameplay Mechanics

### 2.1 The Player & The Loadout
* **Starting Abilities:** The player begins with exactly 3 abilities (e.g., a short-range melee sweep, a targeted projectile, and a defensive dash/shield).
* **Usage-Based Leveling (The "Muscle Memory" System):**
  * Every ability has a hidden XP counter and a level. 
  * XP is gained purely through successful execution (e.g., landing a hit, blocking damage, dodging an attack).
  * XP required for the next level follows a simple curve: TBD.
  * On level-up, the ability's primary stat scales by a flat percentage or similar. 
* **Specialization (via Monuments & Chance Encounters):**
  * Raw leveling makes an ability *stronger*; specialization makes it *different*. Specializations are earned separately, at Monuments (see 2.2), and applied as data-driven modifiers (e.g. on-hit burn, slow-on-hit, lifesteal) layered on top of the ability's base behavior.
  * A shared pool of ~4–6 specialization types (e.g. Blood, Ice, Fire, Storm) is reused across all abilities, so specialization content stays data-driven rather than bespoke per ability.
* **Rules:**
  * Each ability holds **exactly one specialization slot**, not multiple.
  * The first monument interaction for an ability is free — it sets tier = 1 on whichever specialization type the monument grants. No level cost.
  * Every subsequent specialization action on that ability — whether deepening the same specialization to a higher tier, or overwriting it with a different type — costs ability levels equal to the tiers gained. This keeps the trade-off symmetric and the formula trivial.
  * The specialization's effect magnitude scales with both tier and the ability's current level, so leveling up still matters even after you've specialized — it's just now in tension with tier depth instead of being purely additive.

### 2.2 The Environment & Monuments
* **World Generation:** Perpetual, open 2D arenas.
* **Interactive Monuments:** Procedurally spawned structures that grant a specialization to an ability. Three trigger types, all producing the same output (`grantSpecialization(player, ability, tier)`):
  * **Proximity Monuments:** Stand in a radius for N seconds. Grants 1 specialization tier. Low risk, but time exposure to nearby mobs.
  * **Sacrifice Monuments:** Instant trade for an immediate cost (e.g. 30% current HP for a Blood specialization, a momentary movement-speed slow for an Ice specialization). Grants 1 tier instantly, no time spent.
  * **Skill-Check Monuments / Chance Encounters:** Trigger a challenge (timed dodge sequence, surviving a mini-horde, precision timing). Grants 2 tiers at once, or unlocks a rarer specialization unavailable elsewhere. Highest risk, highest reward.
* **New Abilities:** The *only* way to gain a 4th, 5th, or 6th ability during a run is by completing Monument challenges.

### 2.3 The Loop (The Teleporter System)
* **The Mob Quota:** A UI tracker displays the current zone's required kill count.
* **The Teleporter Event:**
  * Once the quota is met, a Teleporter spawns on the map.
  * Activating it locks the player in a confined radius and spawns a massive boss or elite horde.
  * Upon surviving, the player teleports to the next "Stage."
* **Difficulty Scaling:** Inspired by *Risk of Rain 2*, difficulty is tied to a continuous timer AND stage progression. Every teleport drastically increases enemy health, speed, and spawn density.

## 3. Minimum Viable Product (MVP) 
* 1 Playable Character.
* 3 Base Abilities with flat-% leveling and at least 1 specialization slot each.
* 2 Enemy Types (Basic Chaser, Ranged Shooter) + 1 Boss.
* 1 Endless Biome that loops and scales in difficulty via the Teleporter.
