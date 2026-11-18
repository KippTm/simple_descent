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
	state.stage = 1
	state.kill_quota = 250

	entities.init_player(&state.player)

	// Spawn an initial wave of 1,000 chasers in a ring around the player
	for _ in 0 ..< 1000 {
		angle := rand.float32_range(0, math.TAU)
		dist := rand.float32_range(250, 900)
		pos := [2]f32{math.cos(angle) * dist, math.sin(angle) * dist}
		entities.spawn_enemy(state, pos, .Basic_Chaser)
	}
}

update_game :: proc(state: ^structs.Game_State, dt: f32, camera: rl.Camera2D) {
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

	// 2. Update Player Movement & Auto-Fire
	entities.update_player(state, dt, camera)

	// 3. Update Projectiles & Query Spatial Grid for Hits
	entities.update_projectiles(state, dt)

	// 4. Update Enemies (Chaser AI + Spatial Grid Local Separation + Status Effects)
	entities.update_enemies(state, dt)
}
