package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Physical Ability: Sweep (Arced Melee Sweep)
// -----------------------------------------------------------------------------

SWEEP_DEF :: structs.Ability_Def {
	id              = .Sweep,
	name            = "Sweep",
	short_desc      = "Arced melee slash that knocks enemies back.",
	category        = .Physical,
	cooldown_time   = 0.45,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range},
}

SWEEP_BASE_DAMAGE :: 14.0
SWEEP_DAMAGE_STEP :: 0.15
SWEEP_RANGE_STEP  :: 0.12
SWEEP_ARC_STEP    :: 0.06
SWEEP_KNOCKBACK   :: 18.0

cast_sweep :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = move_input
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(SWEEP_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	range_mult := 1.0 + f32(SWEEP_RANGE_STEP) * f32(ability.focus_ranks[.Range])
	arc_mult := 1.0 + f32(SWEEP_ARC_STEP) * f32(ability.focus_ranks[.Range])

	damage := SWEEP_BASE_DAMAGE * dmg_mult
	range := f32(structs.MELEE_RANGE) * range_mult
	half_angle := min(f32(structs.MELEE_HALF_ANGLE) * arc_mult, f32(math.PI) * 0.9)
	cos_threshold := math.cos(half_angle)

	state.player.melee_swing_dir = aim_dir
	state.player.melee_swing_timer = structs.MELEE_SWING_VISUAL_DUR
	state.player.melee_swing_range = range
	state.player.melee_swing_half_angle = half_angle

	p_pos := state.player.pos
	cx, cy := structs.world_to_cell(p_pos)
	cell_rad := i32(math.ceil((range + 16.0) / structs.GRID_CELL_SIZE))
	state.query_stamp += 1
	stamp := state.query_stamp

	for dy in -cell_rad ..= cell_rad {
		for dx in -cell_rad ..= cell_rad {
			bucket := structs.hash_cell(cx + dx, cy + dy)
			e_idx := state.grid.cell_head[bucket]
			for e_idx != -1 {
				if state.enemies[e_idx].last_query_stamp != stamp {
					e_pos := state.enemies[e_idx].pos
					e_rad := state.enemies[e_idx].radius
					to_enemy := e_pos - p_pos
					dist_sq := linalg.length2(to_enemy)
					max_reach := range + e_rad

					if dist_sq <= max_reach * max_reach {
						hit := false
						if dist_sq < 0.001 {
							hit = true
						} else {
							dist := math.sqrt(dist_sq)
							to_enemy_dir := to_enemy / dist
							// Allow slightly wider angle when overlapping directly with player body
							if linalg.dot(aim_dir, to_enemy_dir) >= cos_threshold || dist <= state.player.radius + e_rad + 6.0 {
								hit = true
							}
						}

						if hit {
							state.enemies[e_idx].last_query_stamp = stamp
							apply_ability_hit(state, slot, int(e_idx), damage)
							if dist_sq > 0.001 {
								push_dir := to_enemy / math.sqrt(dist_sq)
								state.enemies[e_idx].pos += push_dir * SWEEP_KNOCKBACK
							}
						}
					}
				}

				e_idx = state.grid.next_in_cell[e_idx]
			}
		}
	}
}
