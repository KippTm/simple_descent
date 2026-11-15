package descent

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

// -----------------------------------------------------------------------------
// Constants & Configuration
// -----------------------------------------------------------------------------

WINDOW_WIDTH  :: 1280
WINDOW_HEIGHT :: 720

MAX_ENEMIES     :: 16384
MAX_PROJECTILES :: 4096
MAX_ABILITIES   :: 6

// Spatial Hash Grid Configuration
// Using a power-of-two bucket count allows fast bitwise modulo (& (GRID_BUCKETS - 1))
GRID_CELL_SIZE :: 32.0
GRID_BUCKETS   :: 4096

// -----------------------------------------------------------------------------
// Data-Driven Combat & Specialization Types
// -----------------------------------------------------------------------------

Ability_Kind :: enum u8 {
	None,
	Melee_Sweep,
	Targeted_Projectile,
	Defensive_Dash,
}

Spec_Type :: enum u8 {
	None,
	Blood, // Lifesteal / bleed
	Ice,   // Slow on hit
	Fire,  // Burn DoT
	Storm, // Chain lightning / shock
}

Status_Effect :: enum u8 {
	Burn,
	Slow,
	Bleed,
	Shock,
}

Status_Flags :: distinct bit_set[Status_Effect; u8]

Ability :: struct {
	kind:          Ability_Kind,
	level:         int,
	xp:            f32,
	spec_type:     Spec_Type,
	spec_tier:     int,
	cooldown:      f32,
	cooldown_time: f32,
}

// -----------------------------------------------------------------------------
// Entities (Structure of Arrays Ready)
// -----------------------------------------------------------------------------

Enemy_Kind :: enum u8 {
	Basic_Chaser,
	Ranged_Shooter,
	Boss,
}

Enemy :: struct {
	pos:          [2]f32,
	vel:          [2]f32,
	hp:           f32,
	max_hp:       f32,
	speed:        f32,
	radius:       f32,
	kind:         Enemy_Kind,
	status_flags: Status_Flags,
	burn_timer:   f32,
	slow_timer:   f32,
}

Projectile :: struct {
	pos:          [2]f32,
	vel:          [2]f32,
	radius:       f32,
	damage:       f32,
	lifetime:     f32,
	ability_slot: int,
}

Player :: struct {
	pos:           [2]f32,
	vel:           [2]f32,
	hp:            f32,
	max_hp:        f32,
	speed:         f32,
	radius:        f32,
	abilities:     [MAX_ABILITIES]Ability,
	ability_count: int,
}

// -----------------------------------------------------------------------------
// Spatial Hash Grid (Zero-Allocation Intrusive Linked List)
// -----------------------------------------------------------------------------
// Instead of allocating dynamic arrays per cell, each bucket stores the index
// of the first enemy in that bucket (`cell_head`), and `next_in_cell[enemy_idx]`
// stores the next enemy index in the same bucket (-1 for end of list).
Spatial_Grid :: struct {
	cell_head:    [GRID_BUCKETS]i32,
	next_in_cell: [MAX_ENEMIES]i32,
}

//Root Game State allocated on the heap so stack size stays tiny.
Game_State :: struct {
	player:           Player,

	// Structure of Arrays (#soa) for cache-friendly iteration over hot loops
	enemies:          #soa[MAX_ENEMIES]Enemy,
	enemy_count:      int,

	projectiles:      #soa[MAX_PROJECTILES]Projectile,
	projectile_count: int,

	grid:             Spatial_Grid,

	// Loop & Teleporter progression
	run_timer:        f32,
	stage:            int,
	kill_count:       int,
	kill_quota:       int,
	spawn_timer:      f32,
}

// -----------------------------------------------------------------------------
// Spatial Hash Implementation
// -----------------------------------------------------------------------------

hash_cell :: #force_inline proc(cx, cy: i32) -> u32 {
	// Large primes for spatial hashing of 2D integer cell coordinates
	h := u32(cx) * 73856093 ~ u32(cy) * 19349663
	return h & (GRID_BUCKETS - 1)
}

world_to_cell :: #force_inline proc(pos: [2]f32) -> (i32, i32) {
	return i32(math.floor(pos.x / GRID_CELL_SIZE)), i32(math.floor(pos.y / GRID_CELL_SIZE))
}

grid_rebuild :: proc(state: ^Game_State) {
	// Reset all bucket heads to -1 (empty)
	for i in 0 ..< GRID_BUCKETS {
		state.grid.cell_head[i] = -1
	}

	// Insert all active enemies in O(N)
	for i in 0 ..< state.enemy_count {
		cx, cy := world_to_cell(state.enemies[i].pos)
		bucket := hash_cell(cx, cy)
		state.grid.next_in_cell[i] = state.grid.cell_head[bucket]
		state.grid.cell_head[bucket] = i32(i)
	}
}

// -----------------------------------------------------------------------------
// Entity Management (Swap-and-Pop Pools)
// -----------------------------------------------------------------------------

spawn_enemy :: proc(state: ^Game_State, pos: [2]f32, kind: Enemy_Kind) {
	if state.enemy_count >= MAX_ENEMIES do return

	idx := state.enemy_count
	state.enemy_count += 1

	state.enemies[idx] = Enemy {
		pos          = pos,
		vel          = {0, 0},
		hp           = 30.0,
		max_hp       = 30.0,
		speed        = 95.0 + rand.float32_range(-15.0, 15.0),
		radius       = 8.0,
		kind         = kind,
		status_flags = {},
	}
}

// O(1) swap-and-pop removal keeps active enemies contiguous [0 ..< enemy_count]
remove_enemy :: #force_inline proc(state: ^Game_State, idx: int) {
	last := state.enemy_count - 1
	if idx != last {
		state.enemies[idx] = state.enemies[last]
	}
	state.enemy_count -= 1
}

spawn_projectile :: proc(state: ^Game_State, pos, dir: [2]f32, ability_slot: int) {
	if state.projectile_count >= MAX_PROJECTILES do return

	idx := state.projectile_count
	state.projectile_count += 1

	ability := state.player.abilities[ability_slot]
	level_mult := 1.0 + 0.12 * f32(ability.level - 1)

	state.projectiles[idx] = Projectile {
		pos          = pos,
		vel          = dir * 520.0,
		radius       = 4.0,
		damage       = 15.0 * level_mult,
		lifetime     = 1.75,
		ability_slot = ability_slot,
	}
}

remove_projectile :: #force_inline proc(state: ^Game_State, idx: int) {
	last := state.projectile_count - 1
	if idx != last {
		state.projectiles[idx] = state.projectiles[last]
	}
	state.projectile_count -= 1
}

// -----------------------------------------------------------------------------
// Combat & Usage-Based Leveling ("Muscle Memory")
// -----------------------------------------------------------------------------

xp_for_next_level :: #force_inline proc(level: int) -> f32 {
	return 10.0 * math.pow(f32(level), 1.35)
}

grant_ability_xp :: proc(ability: ^Ability, amount: f32) {
	ability.xp += amount
	req := xp_for_next_level(ability.level)
	for ability.xp >= req {
		ability.xp -= req
		ability.level += 1
		req = xp_for_next_level(ability.level)
	}
}

// Monument interaction rule from spec.md:
// - First specialization on an ability is free (tier = 1).
// - Subsequent specializations cost ability levels equal to tiers gained.
grant_specialization :: proc(ability: ^Ability, spec: Spec_Type, tiers_gained: int) -> bool {
	if ability.spec_type == .None {
		ability.spec_type = spec
		ability.spec_tier = 1
		return true
	}

	if ability.level <= tiers_gained {
		return false // Not enough ability levels to pay the sacrifice cost
	}

	ability.level -= tiers_gained
	if ability.spec_type == spec {
		ability.spec_tier += tiers_gained
	} else {
		ability.spec_type = spec
		ability.spec_tier = tiers_gained
	}
	return true
}

apply_ability_hit :: proc(state: ^Game_State, ability_slot: int, enemy_idx: int, base_damage: f32) {
	ability := &state.player.abilities[ability_slot]

	// Grant muscle-memory XP on successful hit
	grant_ability_xp(ability, 2.5)

	// Scale specialization magnitude by both tier and current ability level
	spec_scale := f32(ability.spec_tier) * (1.0 + 0.1 * f32(ability.level))

	state.enemies[enemy_idx].hp -= base_damage

	switch ability.spec_type {
	case .None:
	case .Fire:
		state.enemies[enemy_idx].status_flags += {.Burn}
		state.enemies[enemy_idx].burn_timer = 2.0 + 0.5 * spec_scale
	case .Ice:
		state.enemies[enemy_idx].status_flags += {.Slow}
		state.enemies[enemy_idx].slow_timer = 1.5 + 0.4 * spec_scale
	case .Blood:
		heal := 0.5 * spec_scale
		state.player.hp = min(state.player.max_hp, state.player.hp + heal)
	case .Storm:
		state.enemies[enemy_idx].hp -= 4.0 * spec_scale
	}
}

// -----------------------------------------------------------------------------
// Simulation Step
// -----------------------------------------------------------------------------

init_game :: proc(state: ^Game_State) {
	state.stage = 1
	state.kill_quota = 250

	state.player = Player {
		pos           = {0, 0},
		hp            = 100,
		max_hp        = 100,
		speed         = 220,
		radius        = 10,
		ability_count = 3,
	}

	// 3 Starting Abilities (spec 2.1)
	state.player.abilities[0] = Ability {
		kind          = .Targeted_Projectile,
		level         = 1,
		spec_type     = .Ice,
		spec_tier     = 1,
		cooldown_time = 0.18,
	}
	state.player.abilities[1] = Ability {
		kind          = .Melee_Sweep,
		level         = 1,
		spec_type     = .Fire,
		spec_tier     = 1,
		cooldown_time = 0.85,
	}
	state.player.abilities[2] = Ability {
		kind          = .Defensive_Dash,
		level         = 1,
		spec_type     = .None,
		spec_tier     = 0,
		cooldown_time = 2.0,
	}

	// Spawn an initial wave of 1,000 chasers in a ring around the player
	for i in 0 ..< 1000 {
		angle := rand.float32_range(0, math.TAU)
		dist := rand.float32_range(250, 900)
		pos := [2]f32{math.cos(angle) * dist, math.sin(angle) * dist}
		spawn_enemy(state, pos, .Basic_Chaser)
	}
}

update_game :: proc(state: ^Game_State, dt: f32, camera: rl.Camera2D) {
	state.run_timer += dt

	// 1. Player Movement (WASD)
	move_input: [2]f32
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)    do move_input.y -= 1
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)  do move_input.y += 1
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do move_input.x -= 1
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do move_input.x += 1

	if linalg.length2(move_input) > 0 {
		move_input = linalg.normalize(move_input)
	}
	state.player.vel = move_input * state.player.speed
	state.player.pos += state.player.vel * dt

	// Debug key: hold SPACE to stress-test spawning 100 enemies per frame
	if rl.IsKeyDown(.SPACE) {
		for _ in 0 ..< 100 {
			angle := rand.float32_range(0, math.TAU)
			dist := rand.float32_range(400, 750)
			offset := [2]f32{math.cos(angle) * dist, math.sin(angle) * dist}
			spawn_enemy(state, state.player.pos + offset, .Basic_Chaser)
		}
	}

	// 2. Rebuild Spatial Hash Grid in O(N)
	grid_rebuild(state)

	// 3. Player Auto-Fire Targeted Projectile toward Mouse Cursor
	proj_ability := &state.player.abilities[0]
	proj_ability.cooldown -= dt
	if proj_ability.cooldown <= 0 {
		proj_ability.cooldown = proj_ability.cooldown_time
		mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		to_mouse := [2]f32{mouse_world.x, mouse_world.y} - state.player.pos
		if linalg.length2(to_mouse) > 0.001 {
			dir := linalg.normalize(to_mouse)
			spawn_projectile(state, state.player.pos, dir, 0)
		}
	}

	// 4. Update Projectiles & Query Spatial Grid for Hits
	for i := state.projectile_count - 1; i >= 0; i -= 1 {
		state.projectiles[i].pos += state.projectiles[i].vel * dt
		state.projectiles[i].lifetime -= dt

		if state.projectiles[i].lifetime <= 0 {
			remove_projectile(state, i)
			continue
		}

		p_pos := state.projectiles[i].pos
		p_rad := state.projectiles[i].radius
		cx, cy := world_to_cell(p_pos)
		hit := false

		// Check 3x3 neighboring cells around projectile
		cell_search: for dy in i32(-1) ..= 1 {
			for dx in i32(-1) ..= 1 {
				bucket := hash_cell(cx + dx, cy + dy)
				e_idx := state.grid.cell_head[bucket]
				for e_idx != -1 {
					e_pos := state.enemies[e_idx].pos
					e_rad := state.enemies[e_idx].radius
					diff := p_pos - e_pos
					min_dist := p_rad + e_rad
					if linalg.length2(diff) <= min_dist * min_dist {
						apply_ability_hit(state, state.projectiles[i].ability_slot, int(e_idx), state.projectiles[i].damage)
						hit = true
						break cell_search
					}
					e_idx = state.grid.next_in_cell[e_idx]
				}
			}
		}

		if hit {
			remove_projectile(state, i)
		}
	}

	// 5. Update Enemies (Chaser AI + Spatial Grid Local Separation + Status Effects)
	player_pos := state.player.pos
	for i := state.enemy_count - 1; i >= 0; i -= 1 {
		if state.enemies[i].hp <= 0 {
			remove_enemy(state, i)
			state.kill_count += 1
			continue
		}

		// Tick status effects
		flags := state.enemies[i].status_flags
		speed_mult: f32 = 1.0

		if .Burn in flags {
			state.enemies[i].hp -= 8.0 * dt
			state.enemies[i].burn_timer -= dt
			if state.enemies[i].burn_timer <= 0 {
				state.enemies[i].status_flags -= {.Burn}
			}
		}
		if .Slow in flags {
			speed_mult = 0.5
			state.enemies[i].slow_timer -= dt
			if state.enemies[i].slow_timer <= 0 {
				state.enemies[i].status_flags -= {.Slow}
			}
		}

		e_pos := state.enemies[i].pos
		to_player := player_pos - e_pos
		dist_sq := linalg.length2(to_player)
		steer: [2]f32
		if dist_sq > 0.001 {
			steer = to_player / math.sqrt(dist_sq)
		}

		// Query 3x3 neighborhood in spatial hash for soft separation
		separation: [2]f32
		cx, cy := world_to_cell(e_pos)
		e_rad := state.enemies[i].radius
		sep_diam := e_rad * 2.0
		sep_diam_sq := sep_diam * sep_diam

		for dy in i32(-1) ..= 1 {
			for dx in i32(-1) ..= 1 {
				bucket := hash_cell(cx + dx, cy + dy)
				other := state.grid.cell_head[bucket]
				for other != -1 {
					if int(other) != i {
						diff := e_pos - state.enemies[other].pos
						d2 := linalg.length2(diff)
						if d2 > 0.0001 && d2 < sep_diam_sq {
							d := math.sqrt(d2)
							separation += (diff / d) * ((sep_diam - d) / sep_diam)
						}
					}
					other = state.grid.next_in_cell[other]
				}
			}
		}

		vel := (steer + separation * 1.65) * state.enemies[i].speed * speed_mult
		state.enemies[i].vel = vel
		state.enemies[i].pos = e_pos + vel * dt
	}
}

// -----------------------------------------------------------------------------
// Rendering
// -----------------------------------------------------------------------------

render_game :: proc(state: ^Game_State, camera: rl.Camera2D) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground({16, 16, 22, 255})

	rl.BeginMode2D(camera)
	{
		// Draw subtle world reference grid around player
		grid_step :: 128
		start_x := (i32(state.player.pos.x) / grid_step - 8) * grid_step
		start_y := (i32(state.player.pos.y) / grid_step - 6) * grid_step
		for x := start_x; x <= start_x + 16 * grid_step; x += grid_step {
			rl.DrawLine(x, start_y, x, start_y + 12 * grid_step, {28, 28, 38, 255})
		}
		for y := start_y; y <= start_y + 12 * grid_step; y += grid_step {
			rl.DrawLine(start_x, y, start_x + 16 * grid_step, y, {28, 28, 38, 255})
		}

		// Draw Enemies
		for i in 0 ..< state.enemy_count {
			pos := state.enemies[i].pos
			rad := state.enemies[i].radius
			flags := state.enemies[i].status_flags

			color := rl.Color{215, 65, 65, 255}
			if .Slow in flags do color = {90, 185, 255, 255}
			if .Burn in flags do color = {255, 145, 40, 255}

			rl.DrawRectangleV({pos.x - rad, pos.y - rad}, {rad * 2, rad * 2}, color)
		}

		// Draw Projectiles
		for i in 0 ..< state.projectile_count {
			pos := state.projectiles[i].pos
			rad := state.projectiles[i].radius
			rl.DrawCircleV({pos.x, pos.y}, rad, rl.RAYWHITE)
		}

		// Draw Player
		p_pos := state.player.pos
		p_rad := state.player.radius
		rl.DrawCircleV({p_pos.x, p_pos.y}, p_rad, {80, 235, 145, 255})
	}
	rl.EndMode2D()

	// HUD Overlay (uses context.temp_allocator via fmt.ctprintf)
	ability0 := state.player.abilities[0]
	rl.DrawText(
		fmt.ctprintf(
			"FPS: %d | Enemies: %d / %d | Kills: %d / %d",
			rl.GetFPS(),
			state.enemy_count,
			MAX_ENEMIES,
			state.kill_count,
			state.kill_quota,
		),
		16,
		16,
		20,
		rl.RAYWHITE,
	)
	rl.DrawText(
		fmt.ctprintf(
			"Primary Ability Lv.%d (XP: %.0f / %.0f) | Spec: %v (Tier %d)",
			ability0.level,
			ability0.xp,
			xp_for_next_level(ability0.level),
			ability0.spec_type,
			ability0.spec_tier,
		),
		16,
		44,
		18,
		{180, 220, 255, 255},
	)
	rl.DrawText(
		"Controls: WASD = Move | Mouse = Aim | Hold SPACE = Spawn 100 Enemies/Frame",
		16,
		WINDOW_HEIGHT - 32,
		18,
		{150, 150, 165, 255},
	)
}

// -----------------------------------------------------------------------------
// Entry Point
// -----------------------------------------------------------------------------

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Project Descent")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Allocate Game_State on the heap so the large fixed pools don't overflow the stack
	state := new(Game_State)
	defer free(state)

	init_game(state)

	for !rl.WindowShouldClose() {
		dt := min(rl.GetFrameTime(), 0.05)

		camera := rl.Camera2D {
			target = {state.player.pos.x, state.player.pos.y},
			offset = {f32(WINDOW_WIDTH) * 0.5, f32(WINDOW_HEIGHT) * 0.5},
			zoom   = 1.0,
		}

		update_game(state, dt, camera)
		render_game(state, camera)

		// Reset temporary allocator at the end of every frame
		free_all(context.temp_allocator)
	}
}
