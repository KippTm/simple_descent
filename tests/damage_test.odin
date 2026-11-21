package tests

import "core:math"
import "core:math/linalg"
import "core:testing"
import "../src/abilities"
import "../src/entities"
import "../src/structs"

make_test_state :: proc() -> ^structs.Game_State {
	state := new(structs.Game_State)
	entities.init_player(&state.player)
	return state
}

@(test)
test_enemy_enemy_collision_deals_no_damage :: proc(t: ^testing.T) {
	state := make_test_state()
	defer free(state)

	// Keep the player far away so only enemy-to-enemy collision/separation occurs
	state.player.pos = {0, 0}

	// Spawn three enemies overlapping right next to each other
	entities.spawn_enemy(state, {400, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {402, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {401, 2}, .Basic_Chaser)

	initial_count := state.enemy_count
	testing.expect_value(t, initial_count, 3)

	dt: f32 = 1.0 / 60.0
	for _ in 0 ..< 60 {
		entities.grid_rebuild(state)
		entities.update_enemies(state, dt)
	}

	// All enemies must survive and remain at full HP
	testing.expect_value(t, state.enemy_count, initial_count)
	testing.expect_value(t, state.kill_count, 0)
	for i in 0 ..< state.enemy_count {
		testing.expect_value(t, state.enemies[i].hp, state.enemies[i].max_hp)
	}

	// Confirm separation actually pushed them apart from the initial ~2px overlap
	d01 := linalg.distance(state.enemies[0].pos, state.enemies[1].pos)
	testing.expect(t, d01 > 2.0, "Expected colliding enemies to separate")
}

@(test)
test_projectile_damages_only_hit_enemy :: proc(t: ^testing.T) {
	state := make_test_state()
	defer free(state)

	state.player.pos = {0, 0}

	// Explicitly specialize slot 1 (Mana_Bolt) to Ice to verify on-hit spec application
	abilities.grant_specialization(&state.player.abilities[1], .Ice, 1)

	// Enemy 0 directly in projectile path, Enemy 1 nearby but off-path
	entities.spawn_enemy(state, {20, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {20, 40}, .Basic_Chaser)

	// Trigger slot 1 (Mana_Bolt, level 1 -> 15.0 base damage)
	abilities.trigger_ability(state, 1, {1, 0}, {0, 0})
	testing.expect_value(t, state.projectile_count, 1)

	entities.grid_rebuild(state)
	entities.update_projectiles(state, 1.0 / 60.0)

	testing.expect_value(t, state.projectile_count, 0)
	testing.expect_value(t, state.enemies[0].hp, f32(25.0))
	testing.expect(t, .Slow in state.enemies[0].status_flags, "Expected Ice projectile to apply Slow")
	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)
}

@(test)
test_melee_sweep_damages_enemies_in_arc_only :: proc(t: ^testing.T) {
	state := make_test_state()
	defer free(state)

	state.player.pos = {0, 0}

	// Explicitly specialize slot 0 (Sweep) to Fire to verify on-hit Burn application
	abilities.grant_specialization(&state.player.abilities[0], .Fire, 1)

	// Enemy 0: in front within melee arc
	entities.spawn_enemy(state, {35, 0}, .Basic_Chaser)
	// Enemy 1: behind player (outside arc and outside body overlap)
	entities.spawn_enemy(state, {-50, 0}, .Basic_Chaser)
	// Enemy 2: in front but out of melee range
	entities.spawn_enemy(state, {200, 0}, .Basic_Chaser)

	entities.grid_rebuild(state)
	// Slot 0 is Sweep (level 1 -> 14.0 base damage)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})

	testing.expect_value(t, state.enemies[0].hp, f32(26.0))
	testing.expect(t, .Burn in state.enemies[0].status_flags, "Expected Fire sweep to apply Burn")

	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)
	testing.expect(t, !(.Burn in state.enemies[1].status_flags), "Enemy behind player should not burn")

	testing.expect_value(t, state.enemies[2].hp, state.enemies[2].max_hp)
	testing.expect(t, !(.Burn in state.enemies[2].status_flags), "Out-of-range enemy should not burn")
}

@(test)
test_burn_dot_damages_only_burning_enemy :: proc(t: ^testing.T) {
	state := make_test_state()
	defer free(state)

	state.player.pos = {0, 0}

	// Two colliding enemies; only enemy 0 is burning
	entities.spawn_enemy(state, {400, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {402, 0}, .Basic_Chaser)

	state.enemies[0].status_flags += {.Burn}
	state.enemies[0].burn_timer = 1.0

	dt: f32 = 0.1
	for _ in 0 ..< 5 {
		entities.grid_rebuild(state)
		entities.update_enemies(state, dt)
	}

	// Enemy 0 should take 8.0 DPS * 0.5s = 4.0 damage
	expected_hp: f32 = 40.0 - 4.0
	testing.expect(
		t,
		math.abs(state.enemies[0].hp - expected_hp) < 0.01,
		"Expected burning enemy to take ~4.0 burn damage",
	)
	// Colliding non-burning enemy must remain untouched
	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)
}

@(test)
test_enemy_contact_damages_player_with_iframes :: proc(t: ^testing.T) {
	state := make_test_state()
	defer free(state)

	state.player.pos = {0, 0}
	entities.spawn_enemy(state, {5, 0}, .Basic_Chaser)

	dt: f32 = 1.0 / 60.0
	entities.grid_rebuild(state)
	entities.update_enemies(state, dt)

	testing.expect_value(t, state.player.hp, f32(88.0))
	testing.expect(t, state.player.invuln_timer > 0, "Expected player to gain i-frames after contact damage")
	testing.expect_value(t, state.enemies[0].hp, state.enemies[0].max_hp)

	// Move enemy right back on top of player while i-frames are still active
	state.enemies[0].pos = {2, 0}
	entities.grid_rebuild(state)
	entities.update_enemies(state, dt)

	// Player should not take a second hit during i-frames
	testing.expect_value(t, state.player.hp, f32(88.0))
	testing.expect_value(t, state.enemies[0].hp, state.enemies[0].max_hp)
}
