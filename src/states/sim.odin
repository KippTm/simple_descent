package states

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../entities"
import "../structs"

// -----------------------------------------------------------------------------
// Simulation Step & Game Lifecycle
// -----------------------------------------------------------------------------

init_game :: proc(state: ^structs.Game_State) {
	reset_run(state)
	change_state(state, .Menu)
}

spawn_wave :: proc(state: ^structs.Game_State) {
	// Keep the first couple of waves small (4 -> 6 -> 8 -> ...) so the player
	// can focus on individual enemies, ramping gradually with later waves.
	count := 4 + (state.wave - 1) * 2
	if state.wave > 3 {
		count += (state.wave - 3) * 2
	}

	for _ in 0 ..< count {
		angle := rand.float32_range(0, math.TAU)
		dist := rand.float32_range(240, 480)
		offset := [2]f32{math.cos(angle) * dist, math.sin(angle) * dist}
		entities.spawn_enemy(state, state.player.pos + offset, .Basic_Chaser)
	}
}

reset_run :: proc(state: ^structs.Game_State) {
	state.run_timer = 0
	state.stage = 1
	state.wave = 1
	state.kill_count = 0
	state.kill_quota = 40
	state.spawn_timer = 0
	state.enemy_count = 0
	state.projectile_count = 0

	entities.init_player(&state.player)

	spawn_wave(state)
}

update_playing :: proc(state: ^structs.Game_State, dt: f32, camera: rl.Camera2D) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.P) {
		change_state(state, .Paused)
		return
	}

	state.run_timer += dt

	// Debug key: hold SPACE to stress-test spawning 100 enemies per frame
	if rl.IsKeyDown(.SPACE) {
		for _ in 0 ..< 100 {
			angle := rand.float32_range(0, math.TAU)
			dist := rand.float32_range(400, 750)
			offset := [2]f32{math.cos(angle) * dist, math.sin(angle) * dist}
			entities.spawn_enemy(state, state.player.pos + offset, .Basic_Chaser)
		}
	}

	// 1. Rebuild Spatial Hash Grid in O(N)
	entities.grid_rebuild(state)

	// 2. Update Player Movement & Melee Auto-Attack
	entities.update_player(state, dt, camera)

	// 3. Update Projectiles & Query Spatial Grid for Hits
	entities.update_projectiles(state, dt)

	// 4. Update Enemies (Chaser AI + Spatial Grid Local Separation + Contact Damage)
	entities.update_enemies(state, dt)

	// Check player death -> return to Main Menu (or reset)
	if state.player.hp <= 0 {
		change_state(state, .Menu)
		return
	}

	// 5. Wave Progression: when wave is cleared, spawn the next wave after a brief breather
	if state.enemy_count == 0 {
		state.spawn_timer += dt
		if state.spawn_timer >= 1.0 {
			state.spawn_timer = 0
			state.wave += 1
			spawn_wave(state)
		}
	}
}
