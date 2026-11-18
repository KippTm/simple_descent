package entities

import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Projectile Pool Management & Simulation
// -----------------------------------------------------------------------------

spawn_projectile :: proc(state: ^structs.Game_State, pos, dir: [2]f32, ability_slot: int) {
	if state.projectile_count >= structs.MAX_PROJECTILES do return

	idx := state.projectile_count
	state.projectile_count += 1

	ability := state.player.abilities[ability_slot]
	level_mult := 1.0 + 0.12 * f32(ability.level - 1)

	state.projectiles[idx] = structs.Projectile {
		pos          = pos,
		vel          = dir * 520.0,
		radius       = 4.0,
		damage       = 15.0 * level_mult,
		lifetime     = 1.75,
		ability_slot = ability_slot,
	}
}

remove_projectile :: #force_inline proc(state: ^structs.Game_State, idx: int) {
	last := state.projectile_count - 1
	if idx != last {
		state.projectiles[idx] = state.projectiles[last]
	}
	state.projectile_count -= 1
}

update_projectiles :: proc(state: ^structs.Game_State, dt: f32) {
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
}
