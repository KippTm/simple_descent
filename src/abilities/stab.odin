package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Physical Ability: Stab (Deep Straight Thrust)
// -----------------------------------------------------------------------------

STAB_DEF :: structs.Ability_Def {
	id              = .Stab,
	name            = "Stab",
	short_desc      = "Deep, narrow straight thrust with high reach.",
	category        = .Physical,
	cooldown_time   = 0.55,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range},
}

STAB_BASE_DAMAGE :: 18.0
STAB_DAMAGE_STEP :: 0.15
STAB_RANGE       :: 86.0
STAB_RANGE_STEP  :: 0.12
STAB_HALF_WIDTH  :: 14.0
STAB_KNOCKBACK   :: 22.0

cast_stab :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = move_input
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(STAB_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	range_mult := 1.0 + f32(STAB_RANGE_STEP) * f32(ability.focus_ranks[.Range])
	damage := STAB_BASE_DAMAGE * dmg_mult
	reach := f32(STAB_RANGE) * range_mult

	dir := aim_dir
	if linalg.length2(dir) > 0.0001 {
		dir = linalg.normalize(dir)
	} else {
		dir = {1, 0}
	}

	state.player.stab_dir = dir
	state.player.stab_range = reach
	state.player.stab_visual_timer = structs.STAB_VISUAL_DUR

	p_pos := state.player.pos
	tip := p_pos + dir * reach
	margin := f32(STAB_HALF_WIDTH + 24.0)

	min_x, min_y := structs.world_to_cell({min(p_pos.x, tip.x) - margin, min(p_pos.y, tip.y) - margin})
	max_x, max_y := structs.world_to_cell({max(p_pos.x, tip.x) + margin, max(p_pos.y, tip.y) + margin})

	for cy in min_y ..= max_y {
		for cx in min_x ..= max_x {
			bucket := structs.hash_cell(cx, cy)
			e_idx := state.grid.cell_head[bucket]
			for e_idx != -1 {
				e_pos := state.enemies[e_idx].pos
				e_rad := state.enemies[e_idx].radius
				to_e := e_pos - p_pos
				proj := clamp(linalg.dot(to_e, dir), f32(0.0), reach)
				closest := p_pos + dir * proj
				dist_sq := linalg.length2(e_pos - closest)
				hit_rad := f32(STAB_HALF_WIDTH) + e_rad

				if dist_sq <= hit_rad * hit_rad {
					apply_ability_hit(state, slot, int(e_idx), damage)
					state.enemies[e_idx].pos += dir * STAB_KNOCKBACK
				}

				e_idx = state.grid.next_in_cell[e_idx]
			}
		}
	}
}
