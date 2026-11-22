package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Magical Ability: Mana Nova (High-Cooldown 360° Ring of Damage & Force)
// -----------------------------------------------------------------------------

MANA_NOVA_DEF :: structs.Ability_Def {
	id              = .Mana_Nova,
	name            = "Mana Nova",
	short_desc      = "High-cooldown 360-degree ring of damage and force.",
	category        = .Magical,
	cooldown_time   = 4.50,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range},
}

MANA_NOVA_BASE_DAMAGE :: 24.0
MANA_NOVA_DAMAGE_STEP :: 0.15
MANA_NOVA_BASE_RADIUS :: 115.0
MANA_NOVA_RANGE_STEP  :: 0.14
MANA_NOVA_KNOCKBACK   :: 48.0

cast_mana_nova :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = aim_dir
	_ = move_input
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(MANA_NOVA_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	range_mult := 1.0 + f32(MANA_NOVA_RANGE_STEP) * f32(ability.focus_ranks[.Range])

	damage := f32(MANA_NOVA_BASE_DAMAGE) * dmg_mult
	radius := f32(MANA_NOVA_BASE_RADIUS) * range_mult
	knockback := f32(MANA_NOVA_KNOCKBACK) * range_mult

	p_pos := state.player.pos
	state.player.nova_visual_pos = p_pos
	state.player.nova_visual_radius = radius
	state.player.nova_visual_timer = structs.NOVA_VISUAL_DUR

	cx, cy := structs.world_to_cell(p_pos)
	cell_rad := i32(math.ceil((radius + 16.0) / structs.GRID_CELL_SIZE))
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
					to_e := e_pos - p_pos
					dist_sq := linalg.length2(to_e)
					max_reach := radius + e_rad

					if dist_sq <= max_reach * max_reach {
						state.enemies[e_idx].last_query_stamp = stamp
						apply_ability_hit(state, slot, int(e_idx), damage)
						if dist_sq > 0.001 {
							push_dir := to_e / math.sqrt(dist_sq)
							state.enemies[e_idx].pos += push_dir * knockback
						}
					}
				}
				e_idx = state.grid.next_in_cell[e_idx]
			}
		}
	}
}
