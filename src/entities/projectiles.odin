package entities

import "core:math"
import "core:math/linalg"
import "../abilities"
import "../structs"

// -----------------------------------------------------------------------------
// Projectile Pool Management & Simulation
// -----------------------------------------------------------------------------

spawn_projectile :: proc(state: ^structs.Game_State, pos, dir: [2]f32, ability_slot: int) {
	ability := state.player.abilities[ability_slot]
	level_mult := 1.0 + 0.12 * f32(ability.focus_ranks[.Damage])
	abilities.spawn_bolt_projectile(state, pos, dir, 520.0, 4.0, 15.0 * level_mult, 1.75, ability_slot)
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
		kind := state.projectiles[i].kind

		// Returning knife updates velocity to home back to the player after outward flight
		if kind == .Returning_Knife {
			if !state.projectiles[i].returning {
				state.projectiles[i].out_timer -= dt
				if state.projectiles[i].out_timer <= 0 {
					state.projectiles[i].returning = true
					state.projectiles[i].last_hit_enemy = -1
				}
			}
			if state.projectiles[i].returning {
				to_player := state.player.pos - state.projectiles[i].pos
				d2 := linalg.length2(to_player)
				catch_dist := state.player.radius + 14.0
				if d2 <= catch_dist * catch_dist {
					remove_projectile(state, i)
					continue
				}
				if d2 > 0.0001 {
					state.projectiles[i].vel = (to_player / math.sqrt(d2)) * state.projectiles[i].return_speed
				}
			}
		}

		state.projectiles[i].pos += state.projectiles[i].vel * dt
		state.projectiles[i].lifetime -= dt

		if state.projectiles[i].lifetime <= 0 {
			remove_projectile(state, i)
			continue
		}

		p_pos := state.projectiles[i].pos
		p_rad := state.projectiles[i].radius
		cx, cy := structs.world_to_cell(p_pos)

		switch kind {
		case .Bolt:
			hit := false
			bolt_search: for dy in i32(-1) ..= 1 {
				for dx in i32(-1) ..= 1 {
					bucket := structs.hash_cell(cx + dx, cy + dy)
					e_idx := state.grid.cell_head[bucket]
					for e_idx != -1 {
						e_pos := state.enemies[e_idx].pos
						e_rad := state.enemies[e_idx].radius
						diff := p_pos - e_pos
						min_dist := p_rad + e_rad
						if linalg.length2(diff) <= min_dist * min_dist {
							abilities.apply_ability_hit(state, state.projectiles[i].ability_slot, int(e_idx), state.projectiles[i].damage)
							hit = true
							break bolt_search
						}
						e_idx = state.grid.next_in_cell[e_idx]
					}
				}
			}
			if hit {
				remove_projectile(state, i)
			}

		case .Returning_Knife:
			// Pierces enemies on outward & return pass without self-destructing
			for dy in i32(-1) ..= 1 {
				for dx in i32(-1) ..= 1 {
					bucket := structs.hash_cell(cx + dx, cy + dy)
					e_idx := state.grid.cell_head[bucket]
					for e_idx != -1 {
						if e_idx != state.projectiles[i].last_hit_enemy {
							e_pos := state.enemies[e_idx].pos
							e_rad := state.enemies[e_idx].radius
							diff := p_pos - e_pos
							min_dist := p_rad + e_rad
							if linalg.length2(diff) <= min_dist * min_dist {
								abilities.apply_ability_hit(state, state.projectiles[i].ability_slot, int(e_idx), state.projectiles[i].damage)
								state.projectiles[i].last_hit_enemy = e_idx
							}
						}
						e_idx = state.grid.next_in_cell[e_idx]
					}
				}
			}

		case .Mana_Orb:
			// Pulses damage to all enemies within aura_radius every pulse_interval
			state.projectiles[i].pulse_timer -= dt
			if state.projectiles[i].pulse_timer <= 0 {
				state.projectiles[i].pulse_timer = state.projectiles[i].pulse_interval
				aura_rad := state.projectiles[i].aura_radius
				cell_rad := i32(math.ceil((aura_rad + 16.0) / structs.GRID_CELL_SIZE))
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
								diff := p_pos - e_pos
								max_dist := aura_rad + e_rad
								if linalg.length2(diff) <= max_dist * max_dist {
									state.enemies[e_idx].last_query_stamp = stamp
									abilities.apply_ability_hit(state, state.projectiles[i].ability_slot, int(e_idx), state.projectiles[i].damage)
								}
							}
							e_idx = state.grid.next_in_cell[e_idx]
						}
					}
				}
			}
		}
	}
}
