# Implementation Roadmap: Project Descent

This roadmap outlines the implementation milestones for **Project Descent**, grounded in [spec.md](spec.md) and the starter prototype in [main.odin](../src/main.odin).

---

## Current Baseline (Already in `src/main.odin`)
- `#soa` fixed-capacity pools (`Enemy`, `Projectile`) with $O(1)$ swap-and-pop removal
- Zero-allocation spatial hash grid (`grid_rebuild`) for broad-phase queries
- Basic player movement, camera tracking, and auto-firing projectile loop
- Scaffolding for `grant_ability_xp`, `grant_specialization`, and `apply_ability_hit`

---

## Phase 0: Split it out
**Goal:** Outline the game architecture fully in terms of entities and split main.odin into multiple files.

- **Deliverables:**
  - **Code Organization:** Split `src/main.odin` into focused files (`sim.odin`, `render.odin`, `abilities.odin`, `monuments.odin`).

## Phase 1: Core Combat & The 3 Starting Abilities
**Goal:** Replace the single auto-firing prototype with the full 3-ability loadout and "Muscle Memory" usage-based leveling.

- **Deliverables:**
  1. **3 Base Abilities:**
     - *Melee Sweep* (short-range arc/cone using spatial hash neighborhood query)
     - *Targeted Projectile* (cursor-aimed ranged attack)
     - *Defensive Dash / Shield* (mobility + i-frames or damage block)
  2. **Muscle Memory Leveling:**
     - Award ability XP on successful execution (hit landed, damage blocked/dodged).
     - Tune `xp_for_next_level` curve and flat-% stat scaling per level.
  3. **Player Health & Game Over Loop:**
     - Player HP, invulnerability frames on hit, and a clean death/restart flow.
  4. **Minimal Combat HUD:**
     - Ability cooldowns, current ability levels/XP bars, and player HP.
- **Done When:** You can fight waves using all 3 abilities, see them level up from use, and die/restart cleanly.

---

## Phase 2: Specializations & Status Effects
**Goal:** Make specializations (`Blood`, `Ice`, `Fire`, `Storm`) mechanically distinct and data-driven.

- **Deliverables:**
  1. **Status Effect System:**
     - Add status timers/stacks to the `#soa` enemy pool (burn DoT, ice slow, storm chain/arc, blood lifesteal).
  2. **Specialization Scaling:**
     - Hook `apply_ability_hit` so effect magnitude scales with both **specialization tier** and **ability level**.
     - Enforce the single-slot rule and level-cost trade-off in `grant_specialization` (first is free at tier 1; deepening or overwriting costs levels equal to tiers gained).
  3. **Visual Readability:**
     - Distinct projectile/hit tints and enemy status indicators (e.g., blue tint for slowed, orange particles/flash for burn).
- **Done When:** Each of the 4 specialization types visibly and mechanically alters how any of the 3 abilities behaves.

---

## Phase 3: Monuments & Risk/Reward Exploration
**Goal:** Turn the empty arena into an interactive map with Risk vs. Reward decisions.

- **Deliverables:**
  1. **Monument Entity Pool & Spawning:**
     - Procedurally place Monuments across the open 2D arena away from the player's spawn.
  2. **Three Monument Trigger Types:**
     - *Proximity:* Stand in radius for $N$ seconds $\rightarrow$ +1 tier.
     - *Sacrifice:* Instant interaction for a cost (e.g., 30% current HP for Blood, temporary slow for Ice) $\rightarrow$ +1 tier.
     - *Skill-Check / Chance:* Trigger a timed mini-challenge (dodge sequence or mini-horde) $\rightarrow$ +2 tiers or unlock a 4th/5th/6th ability slot.
  3. **Interaction UI:**
     - Clear world-space prompts showing cost, target ability, and specialization type.
- **Done When:** All 3 monument types spawn, can be interacted with mid-combat, and grant specializations or new abilities.

---

## Phase 4: Enemy Variety, Teleporter Loop & Difficulty Scaling (MVP Complete)
**Goal:** Complete the *Risk of Rain 2*-inspired stage loop and hit the MVP milestone.

- **Deliverables:**
  1. **Enemy Roster (MVP):**
     - *Basic Chaser* (swarm separation + player steering)
     - *Ranged Shooter* (maintains distance, fires enemy projectiles)
     - *Stage Boss* (high HP, telegraphed attacks, spawns during Teleporter event)
  2. **Mob Quota & Teleporter Event:**
     - Track stage kills against a quota; spawn the Teleporter once met.
     - Activating locks the player in a confined arena radius and spawns the Boss/elite horde.
     - Surviving advances to the next Stage (resets map/monuments, keeps player loadout).
  3. **Continuous + Stage Difficulty Scaling:**
     - Scale enemy HP, speed, and spawn density continuously over time and steeply per stage.
- **Done When:** You can play an endless run across multiple stages, scaling in difficulty, fighting both enemy types and bosses.

---

## Phase 5: Polish, Architecture & Audio/Visual Juice
**Goal:** Elevate game feel, performance at scale, and code modularity.

- **Deliverables:**
  - **Audio & Juice:** Hitstop/screen-shake, damage numbers, pixel-art sprites, and `raylib` SFX for hits, level-ups, and monument activations.
  - **Stress Testing:** Profile 5,000–16,384 active enemies to verify 60+ FPS with zero mid-frame heap allocations.
