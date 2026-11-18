package entities

import "core:math/linalg"
import rl "vendor:raylib"
import "../structs"

// -----------------------------------------------------------------------------
// Player Initialization & Controls
// -----------------------------------------------------------------------------

init_player :: proc(player: ^structs.Player) {
	player^ = structs.Player {
		pos           = {0, 0},
		hp            = 100,
		max_hp        = 100,
		speed         = 220,
		radius        = 10,
		ability_count = 3,
	}

	// 3 Starting Abilities (spec 2.1)
	player.abilities[0] = structs.Ability {
		kind          = .Targeted_Projectile,
		level         = 1,
		spec_type     = .Ice,
		spec_tier     = 1,
		cooldown_time = 0.18,
	}
	player.abilities[1] = structs.Ability {
		kind          = .Melee_Sweep,
		level         = 1,
		spec_type     = .Fire,
		spec_tier     = 1,
		cooldown_time = 0.85,
	}
	player.abilities[2] = structs.Ability {
		kind          = .Defensive_Dash,
		level         = 1,
		spec_type     = .None,
		spec_tier     = 0,
		cooldown_time = 2.0,
	}
}

update_player :: proc(state: ^structs.Game_State, dt: f32, camera: rl.Camera2D) {
	// 1. Player Movement (WASD / Arrow Keys)
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

	// 2. Player Auto-Fire Targeted Projectile toward Mouse Cursor
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
}
