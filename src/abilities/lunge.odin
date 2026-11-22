package abilities

import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Physical Ability: Lunge (Short Forward Burst with Front Hitbox)
// -----------------------------------------------------------------------------
// Shorter range than Dash (70px vs 114px) and shorter hitbox than Stab (46px vs 86px).

LUNGE_DEF :: structs.Ability_Def {
	id              = .Lunge,
	name            = "Lunge",
	short_desc      = "Short burst forward with a compact frontal hitbox.",
	category        = .Physical,
	cooldown_time   = 1.35,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range},
}

LUNGE_BASE_DAMAGE  :: 16.0
LUNGE_DAMAGE_STEP  :: 0.15
LUNGE_DURATION     :: 0.11 // Shorter than Dash (0.15s)
LUNGE_SPEED        :: 640.0 // ~70px travel vs Dash's ~114px
LUNGE_HITBOX_RANGE :: 46.0 // Shorter than Stab's 86px
LUNGE_HITBOX_WIDTH :: 18.0
LUNGE_RANGE_STEP   :: 0.12
LUNGE_KNOCKBACK    :: 24.0
LUNGE_HIT_INTERVAL :: 0.08

cast_lunge :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(LUNGE_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	range_mult := 1.0 + f32(LUNGE_RANGE_STEP) * f32(ability.focus_ranks[.Range])

	dir := aim_dir if linalg.length2(aim_dir) > 0.0001 else (move_input if linalg.length2(move_input) > 0.0001 else [2]f32{1, 0})
	dir = linalg.normalize(dir)

	state.player.lunge_dir = dir
	state.player.lunge_speed = f32(LUNGE_SPEED) * range_mult
	state.player.lunge_timer = LUNGE_DURATION
	state.player.lunge_damage = f32(LUNGE_BASE_DAMAGE) * dmg_mult
	state.player.lunge_range = f32(LUNGE_HITBOX_RANGE) * range_mult
	state.player.lunge_slot = slot
	state.player.lunge_hit_timer = 0 // Hit immediately on cast frame

	// Immediate frontal strike on launch
	check_lunge_hitbox(state)
}

check_lunge_hitbox :: proc(state: ^structs.Game_State) {
	p_pos := state.player.pos
	dir := state.player.lunge_dir
	reach := state.player.lunge_range
	tip := p_pos + dir * reach
	margin := f32(LUNGE_HITBOX_WIDTH + 20.0)

	min_x, min_y := structs.world_to_cell({min(p_pos.x, tip.x) - margin, min(p_pos.y, tip.y) - margin})
	max_x, max_y := structs.world_to_cell({max(p_pos.x, tip.x) + margin, max(p_pos.y, tip.y) + margin})
	state.query_stamp += 1
	stamp := state.query_stamp

	hit_any := false
	for cy in min_y ..= max_y {
		for cx in min_x ..= max_x {
			bucket := structs.hash_cell(cx, cy)
			e_idx := state.grid.cell_head[bucket]
			for e_idx != -1 {
				if state.enemies[e_idx].last_query_stamp != stamp {
					e_pos := state.enemies[e_idx].pos
					e_rad := state.enemies[e_idx].radius
					to_e := e_pos - p_pos
					proj := clamp(linalg.dot(to_e, dir), f32(0.0), reach)
					closest := p_pos + dir * proj
					dist_sq := linalg.length2(e_pos - closest)
					hit_rad := f32(LUNGE_HITBOX_WIDTH) + e_rad

					if dist_sq <= hit_rad * hit_rad {
						state.enemies[e_idx].last_query_stamp = stamp
						apply_ability_hit(state, state.player.lunge_slot, int(e_idx), state.player.lunge_damage)
						state.enemies[e_idx].pos += dir * LUNGE_KNOCKBACK
						hit_any = true
					}
				}
				e_idx = state.grid.next_in_cell[e_idx]
			}
		}
	}

	if hit_any {
		state.player.lunge_hit_timer = LUNGE_HIT_INTERVAL
	}
}

update_lunge_hitbox :: proc(state: ^structs.Game_State, dt: f32) {
	if state.player.lunge_timer <= 0 do return
	if state.player.lunge_hit_timer > 0 {
		state.player.lunge_hit_timer = max(0, state.player.lunge_hit_timer - dt)
		return
	}
	check_lunge_hitbox(state)
}
