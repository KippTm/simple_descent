package entities

import "core:math/linalg"
import rl "vendor:raylib"
import "../abilities"
import "../structs"

// -----------------------------------------------------------------------------
// Player Initialization & Controls
// -----------------------------------------------------------------------------

init_player :: proc(
	player: ^structs.Player,
	loadout: [structs.STARTING_ABILITY_COUNT]structs.Ability_Id = abilities.DEFAULT_LOADOUT,
) {
	player^ = structs.Player {
		pos                    = {0, 0},
		hp                     = 100,
		max_hp                 = 100,
		speed                  = 220,
		radius                 = 10,
		melee_swing_dir        = {1, 0},
		melee_swing_range      = structs.MELEE_RANGE,
		melee_swing_half_angle = structs.MELEE_HALF_ANGLE,
		stab_dir               = {1, 0},
		dash_dir               = {1, 0},
		dash_speed             = structs.DASH_SPEED,
		haste_mult             = 1.0,
		ability_count          = structs.STARTING_ABILITY_COUNT,
	}

	for i in 0 ..< structs.STARTING_ABILITY_COUNT {
		id := loadout[i]
		if id == .None {
			id = abilities.DEFAULT_LOADOUT[i]
		}
		player.abilities[i] = abilities.make_ability(id)
	}
}

update_player :: proc(state: ^structs.Game_State, dt: f32, camera: rl.Camera2D) {
	if state.player.invuln_timer > 0 {
		state.player.invuln_timer = max(0, state.player.invuln_timer - dt)
	}
	if state.player.melee_swing_timer > 0 {
		state.player.melee_swing_timer = max(0, state.player.melee_swing_timer - dt)
	}
	if state.player.stab_visual_timer > 0 {
		state.player.stab_visual_timer = max(0, state.player.stab_visual_timer - dt)
	}
	if state.player.reflect_timer > 0 {
		state.player.reflect_timer = max(0, state.player.reflect_timer - dt)
	}
	if state.player.lunge_timer > 0 {
		state.player.lunge_timer = max(0, state.player.lunge_timer - dt)
	}
	if state.player.nova_visual_timer > 0 {
		state.player.nova_visual_timer = max(0, state.player.nova_visual_timer - dt)
	}
	if state.player.shield_timer > 0 {
		state.player.shield_timer = max(0, state.player.shield_timer - dt)
		if state.player.shield_timer <= 0 {
			state.player.shield_hp = 0
		}
	}
	if state.player.dash_timer > 0 {
		state.player.dash_timer = max(0, state.player.dash_timer - dt)
	}
	if state.player.haste_timer > 0 {
		state.player.haste_timer = max(0, state.player.haste_timer - dt)
		if state.player.haste_timer <= 0 {
			state.player.haste_mult = 1.0
		}
	}
	if state.player.mend_timer > 0 {
		heal_dt := min(dt, state.player.mend_timer)
		state.player.hp = min(state.player.max_hp, state.player.hp + state.player.mend_hps * heal_dt)
		state.player.mend_timer = max(0, state.player.mend_timer - dt)
	}

	// Tick ability cooldowns
	for i in 0 ..< state.player.ability_count {
		if state.player.abilities[i].cooldown > 0 {
			state.player.abilities[i].cooldown = max(0, state.player.abilities[i].cooldown - dt)
		}
	}

	// 1. Player Movement (WASD / Arrow Keys, Haste boost, Lunge, or Dash burst if active)
	move_input: [2]f32
	if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)    do move_input.y -= 1
	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)  do move_input.y += 1
	if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)  do move_input.x -= 1
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do move_input.x += 1

	if linalg.length2(move_input) > 0 {
		move_input = linalg.normalize(move_input)
	}

	if state.player.dash_timer > 0 {
		state.player.vel = state.player.dash_dir * state.player.dash_speed
	} else if state.player.lunge_timer > 0 {
		state.player.vel = state.player.lunge_dir * state.player.lunge_speed
	} else {
		speed_mult: f32 = state.player.haste_mult if state.player.haste_timer > 0 else 1.0
		state.player.vel = move_input * (state.player.speed * speed_mult)
	}
	state.player.pos += state.player.vel * dt

	if state.player.lunge_timer > 0 {
		abilities.update_lunge_hitbox(state, dt)
	}

	// 2. Mouse / Trackpad Aiming ONLY
	mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
	to_mouse := [2]f32{mouse_world.x, mouse_world.y} - state.player.pos
	aim_dir := [2]f32{1, 0}
	if linalg.length2(to_mouse) > 0.001 {
		aim_dir = linalg.normalize(to_mouse)
	}

	// 3. Manual Ability Activation via Keys "1", "2", "3"
	if rl.IsKeyPressed(.ONE) || rl.IsKeyPressed(.KP_1) {
		abilities.trigger_ability(state, 0, aim_dir, move_input)
	}
	if rl.IsKeyPressed(.TWO) || rl.IsKeyPressed(.KP_2) {
		abilities.trigger_ability(state, 1, aim_dir, move_input)
	}
	if rl.IsKeyPressed(.THREE) || rl.IsKeyPressed(.KP_3) {
		abilities.trigger_ability(state, 2, aim_dir, move_input)
	}
}
