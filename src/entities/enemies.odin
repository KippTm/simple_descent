package entities

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "../structs"

// -----------------------------------------------------------------------------
// Enemy Pool Management & Simulation
// -----------------------------------------------------------------------------

spawn_enemy :: proc(state: ^structs.Game_State, pos: [2]f32, kind: structs.Enemy_Kind) {
	if state.enemy_count >= structs.MAX_ENEMIES do return

	idx := state.enemy_count
	state.enemy_count += 1

	state.enemies[idx] = structs.Enemy {
		pos          = pos,
		vel          = {0, 0},
		hp           = 40.0,
		max_hp       = 40.0,
		speed        = 92.0 + rand.float32_range(-12.0, 12.0),
		radius       = 10.0,
		kind         = kind,
		status_flags = {},
	}
}

// O(1) swap-and-pop removal keeps active enemies contiguous [0 ..< enemy_count]
remove_enemy :: #force_inline proc(state: ^structs.Game_State, idx: int) {
	last := state.enemy_count - 1
	if idx != last {
		state.enemies[idx] = state.enemies[last]
	}
	state.enemy_count -= 1
}

update_enemies :: proc(state: ^structs.Game_State, dt: f32) {
	player_pos := state.player.pos
	player_rad := state.player.radius

	for i := state.enemy_count - 1; i >= 0; i -= 1 {
		if state.enemies[i].hp <= 0 {
			remove_enemy(state, i)
			state.kill_count += 1
			continue
		}

		// Tick status effects
		flags := state.enemies[i].status_flags
		speed_mult: f32 = 1.0

		if .Burn in flags {
			state.enemies[i].hp -= 8.0 * dt
			state.enemies[i].burn_timer -= dt
			if state.enemies[i].burn_timer <= 0 {
				state.enemies[i].status_flags -= {.Burn}
			}
		}
		if .Slow in flags {
			speed_mult = 0.5
			state.enemies[i].slow_timer -= dt
			if state.enemies[i].slow_timer <= 0 {
				state.enemies[i].status_flags -= {.Slow}
			}
		}

		e_pos := state.enemies[i].pos
		to_player := player_pos - e_pos
		dist_sq := linalg.length2(to_player)
		steer: [2]f32
		if dist_sq > 0.001 {
			steer = to_player / math.sqrt(dist_sq)
		}

		// Query 3x3 neighborhood in spatial hash for soft separation
		separation: [2]f32
		cx, cy := world_to_cell(e_pos)
		e_rad := state.enemies[i].radius
		sep_diam := e_rad * 2.0
		sep_diam_sq := sep_diam * sep_diam

		for dy in i32(-1) ..= 1 {
			for dx in i32(-1) ..= 1 {
				bucket := hash_cell(cx + dx, cy + dy)
				other := state.grid.cell_head[bucket]
				for other != -1 {
					if int(other) != i {
						diff := e_pos - state.enemies[other].pos
						d2 := linalg.length2(diff)
						if d2 > 0.0001 && d2 < sep_diam_sq {
							d := math.sqrt(d2)
							separation += (diff / d) * ((sep_diam - d) / sep_diam)
						}
					}
					other = state.grid.next_in_cell[other]
				}
			}
		}

		vel := (steer + separation * 1.65) * state.enemies[i].speed * speed_mult
		new_pos := e_pos + vel * dt

		// Player contact damage & collision response
		hit_diff := player_pos - new_pos
		hit_dist_sq := linalg.length2(hit_diff)
		contact_dist := player_rad + e_rad
		if hit_dist_sq <= contact_dist * contact_dist {
			if state.player.invuln_timer <= 0 {
				state.player.hp = max(0, state.player.hp - 12.0)
				state.player.invuln_timer = structs.PLAYER_IFRAME_DURATION
			}
			if hit_dist_sq > 0.0001 {
				hit_dist := math.sqrt(hit_dist_sq)
				push_out := (hit_diff / hit_dist) * (contact_dist - hit_dist + 4.0)
				new_pos -= push_out
			}
		}

		state.enemies[i].vel = vel
		state.enemies[i].pos = new_pos
	}
}
