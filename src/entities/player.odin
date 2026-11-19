package entities

import "core:math/linalg"
import rl "vendor:raylib"
import "../structs"

// -----------------------------------------------------------------------------
// Player Initialization & Controls
// -----------------------------------------------------------------------------

init_player :: proc(player: ^structs.Player) {
	player^ = structs.Player {
		pos             = {0, 0},
		hp              = 100,
		max_hp          = 100,
		speed           = 220,
		radius          = 10,
		melee_swing_dir = {1, 0},
		dash_dir        = {1, 0},
		ability_count   = 3,
	}

	// 3 Starting Abilities (spec 2.1) — triggered manually via keys "1", "2", "3"
	// Slot 0 (Key 1): Slightly ranged melee swing (Terraria broadsword length)
	player.abilities[0] = structs.Ability {
		kind          = .Melee_Sweep,
		level         = 1,
		spec_type     = .Fire,
		spec_tier     = 1,
		cooldown_time = 0.42,
	}
	// Slot 1 (Key 2): Targeted Projectile
	player.abilities[1] = structs.Ability {
		kind          = .Targeted_Projectile,
		level         = 1,
		spec_type     = .Ice,
		spec_tier     = 1,
		cooldown_time = 0.85,
	}
	// Slot 2 (Key 3): Defensive Dash
	player.abilities[2] = structs.Ability {
		kind          = .Defensive_Dash,
		level         = 1,
		spec_type     = .None,
		spec_tier     = 0,
		cooldown_time = 2.0,
	}
}

trigger_ability :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	if slot < 0 || slot >= state.player.ability_count do return

	ability := &state.player.abilities[slot]
	if ability.cooldown > 0 || ability.kind == .None do return

	ability.cooldown = ability.cooldown_time

	switch ability.kind {
	case .None:
	case .Melee_Sweep:
		state.player.melee_swing_dir = aim_dir
		state.player.melee_swing_timer = structs.MELEE_SWING_VISUAL_DUR
		perform_melee_sweep(state, aim_dir, slot)
	case .Targeted_Projectile:
		spawn_projectile(state, state.player.pos, aim_dir, slot)
	case .Defensive_Dash:
		dash_dir := move_input if linalg.length2(move_input) > 0.001 else aim_dir
		state.player.dash_dir = dash_dir
		state.player.dash_timer = structs.DASH_DURATION
		state.player.invuln_timer = max(state.player.invuln_timer, structs.DASH_DURATION + 0.15)
		// Award muscle-memory XP on executing dash
		grant_ability_xp(ability, 3.0)
	}
}

update_player :: proc(state: ^structs.Game_State, dt: f32, camera: rl.Camera2D) {
	if state.player.invuln_timer > 0 {
		state.player.invuln_timer = max(0, state.player.invuln_timer - dt)
	}
	if state.player.melee_swing_timer > 0 {
		state.player.melee_swing_timer = max(0, state.player.melee_swing_timer - dt)
	}
	if state.player.dash_timer > 0 {
		state.player.dash_timer = max(0, state.player.dash_timer - dt)
	}

	// Tick ability cooldowns
	for i in 0 ..< state.player.ability_count {
		if state.player.abilities[i].cooldown > 0 {
			state.player.abilities[i].cooldown = max(0, state.player.abilities[i].cooldown - dt)
		}
	}

	// 1. Player Movement (WASD / Arrow Keys, or Dash burst if active)
	move_input: [2]f32
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)    do move_input.y -= 1
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)  do move_input.y += 1
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do move_input.x -= 1
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do move_input.x += 1

	if linalg.length2(move_input) > 0 {
		move_input = linalg.normalize(move_input)
	}

	if state.player.dash_timer > 0 {
		dash_mult := 1.0 + 0.05 * f32(state.player.abilities[2].level - 1)
		state.player.vel = state.player.dash_dir * (structs.DASH_SPEED * dash_mult)
	} else {
		state.player.vel = move_input * state.player.speed
	}
	state.player.pos += state.player.vel * dt

	// 2. Manual Ability Activation via Keys "1", "2", "3"
	mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
	to_mouse := [2]f32{mouse_world.x, mouse_world.y} - state.player.pos
	aim_dir := [2]f32{1, 0}
	if linalg.length2(to_mouse) > 0.001 {
		aim_dir = linalg.normalize(to_mouse)
	}

	if rl.IsKeyPressed(.ONE) || rl.IsKeyPressed(.KP_1) {
		trigger_ability(state, 0, aim_dir, move_input)
	}
	if rl.IsKeyPressed(.TWO) || rl.IsKeyPressed(.KP_2) {
		trigger_ability(state, 1, aim_dir, move_input)
	}
	if rl.IsKeyPressed(.THREE) || rl.IsKeyPressed(.KP_3) {
		trigger_ability(state, 2, aim_dir, move_input)
	}
}
