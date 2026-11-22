package tests

import "core:math"
import "core:testing"
import "../src/abilities"
import "../src/entities"
import "../src/structs"

@(test)
test_registry_completeness :: proc(t: ^testing.T) {
	testing.expect_value(t, len(abilities.SELECTABLE_ABILITIES), 12)

	for id in abilities.SELECTABLE_ABILITIES {
		def := abilities.ABILITY_DEFS[id]
		testing.expect_value(t, def.id, id)
		testing.expect(t, def.name != "", "Expected ability to have a name")
		testing.expect(t, def.category != .None, "Expected ability to have a category")
		testing.expect(t, def.cooldown_time > 0, "Expected positive cooldown")
		testing.expect(t, def.default_focus in def.allowed_focuses, "Default focus must be in allowed focuses")
		testing.expect(t, abilities.ABILITY_CAST_PROCS[id] != nil, "Expected non-nil cast proc")

		inst := abilities.make_ability(id)
		testing.expect_value(t, inst.spec_type, structs.Spec_Type.None)
		testing.expect_value(t, inst.spec_tier, 0)
		testing.expect_value(t, inst.level, 1)
		testing.expect_value(t, inst.upgrade_focus, def.default_focus)
	}
}

@(test)
test_custom_loadout_init :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	loadout := [structs.STARTING_ABILITY_COUNT]structs.Ability_Id{.Stab, .Mana_Shield, .Haste}
	entities.init_player(&state.player, loadout)

	testing.expect_value(t, state.player.ability_count, 3)
	testing.expect_value(t, state.player.abilities[0].id, structs.Ability_Id.Stab)
	testing.expect_value(t, state.player.abilities[1].id, structs.Ability_Id.Mana_Shield)
	testing.expect_value(t, state.player.abilities[2].id, structs.Ability_Id.Haste)
	testing.expect_value(t, state.player.abilities[0].spec_type, structs.Spec_Type.None)
	testing.expect_value(t, state.player.abilities[1].spec_type, structs.Spec_Type.None)
	testing.expect_value(t, state.player.abilities[2].spec_type, structs.Spec_Type.None)
}

@(test)
test_stab_hits_shorter_narrow_line_only :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Stab, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// Enemy 0: straight ahead within Stab's 86px range
	entities.spawn_enemy(state, {80, 0}, .Basic_Chaser)
	// Enemy 1: beyond Stab's new shorter range (86 + 14 + 10 = 110 max tip reach, so 115 is out)
	entities.spawn_enemy(state, {115, 0}, .Basic_Chaser)
	// Enemy 2: off-axis to the side (outside narrow stab width)
	entities.spawn_enemy(state, {35, 45}, .Basic_Chaser)

	entities.grid_rebuild(state)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})

	testing.expect_value(t, state.enemies[0].hp, f32(22.0)) // 40 - 18
	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)
	testing.expect_value(t, state.enemies[2].hp, state.enemies[2].max_hp)
	// Non-lethal hit must NOT grant XP for attacks
	testing.expect_value(t, state.player.abilities[0].xp, f32(0.0))
}

@(test)
test_attack_xp_only_on_kill_by_enemy_kind :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Sweep, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// Spawn a Basic_Chaser and hit it once (non-lethal: 40 -> 26 HP)
	entities.spawn_enemy(state, {35, 0}, .Basic_Chaser)
	entities.grid_rebuild(state)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	entities.update_enemies(state, 1.0 / 60.0)

	testing.expect_value(t, state.player.abilities[0].xp, f32(0.0))
	testing.expect_value(t, state.enemy_count, 1)

	// Reduce enemy to lethal threshold and finish it with Sweep
	state.enemies[0].hp = 10.0
	state.enemies[0].pos = {35, 0}
	state.player.abilities[0].cooldown = 0
	entities.grid_rebuild(state)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	entities.update_enemies(state, 1.0 / 60.0)

	testing.expect_value(t, state.enemy_count, 0)
	testing.expect_value(t, state.player.abilities[0].xp, abilities.enemy_xp_reward(.Basic_Chaser))

	// Boss kill should reward more XP than Basic_Chaser
	testing.expect(
		t,
		abilities.enemy_xp_reward(.Boss) > abilities.enemy_xp_reward(.Ranged_Shooter),
		"Expected Boss XP > Ranged_Shooter XP",
	)
	testing.expect(
		t,
		abilities.enemy_xp_reward(.Ranged_Shooter) > abilities.enemy_xp_reward(.Basic_Chaser),
		"Expected Ranged_Shooter XP > Basic_Chaser XP",
	)
}

@(test)
test_exponential_xp_curve :: proc(t: ^testing.T) {
	req1 := abilities.xp_for_next_level(1)
	req2 := abilities.xp_for_next_level(2)
	req3 := abilities.xp_for_next_level(3)
	req6 := abilities.xp_for_next_level(6)

	testing.expect(t, math.abs(req1 - 20.0) < 0.01, "Expected Lv1->2 XP to be 20.0")
	testing.expect(t, req2 > req1 && req3 > req2 && req6 > req3, "Expected strictly increasing XP requirements")

	// Verify constant exponential ratio e^0.22 between consecutive levels
	expected_ratio := math.exp(f32(abilities.XP_EXPONENT))
	testing.expect(t, math.abs((req2 / req1) - expected_ratio) < 0.001, "Expected Euler exponential ratio")
	testing.expect(t, math.abs((req3 / req2) - expected_ratio) < 0.001, "Expected Euler exponential ratio")
}

@(test)
test_upgrade_focus_ranks_and_milestone_trigger :: proc(t: ^testing.T) {
	ability := abilities.make_ability(.Sweep)
	testing.expect_value(t, ability.upgrade_focus, structs.Upgrade_Focus.Damage)
	testing.expect_value(t, ability.pending_focus_choice, false)

	// Level 1 -> 2 (not milestone yet)
	abilities.grant_ability_xp(&ability, abilities.xp_for_next_level(1))
	testing.expect_value(t, ability.level, 2)
	testing.expect_value(t, ability.focus_ranks[.Damage], 1)
	testing.expect_value(t, ability.pending_focus_choice, false)

	// Level 2 -> 3 (milestone! triggers pending_focus_choice)
	abilities.grant_ability_xp(&ability, abilities.xp_for_next_level(2))
	testing.expect_value(t, ability.level, 3)
	testing.expect_value(t, ability.focus_ranks[.Damage], 2)
	testing.expect_value(t, ability.pending_focus_choice, true)

	// Switch focus to Range and level 3 -> 4 -> Damage ranks stay, Range rank increments
	ability.upgrade_focus = .Range
	ability.pending_focus_choice = false
	abilities.grant_ability_xp(&ability, abilities.xp_for_next_level(3))
	testing.expect_value(t, ability.level, 4)
	testing.expect_value(t, ability.focus_ranks[.Damage], 2)
	testing.expect_value(t, ability.focus_ranks[.Range], 1)
}

@(test)
test_mana_bolt_projectile_focus_spawns_extra_bolts :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Mana_Bolt, .Sweep, .Dash})
	state.player.abilities[0].focus_ranks[.Projectiles] = 2

	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect_value(t, state.projectile_count, 3)
}

@(test)
test_reflect_blocks_and_damages_attacker :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Reflect, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// Activate Reflect in slot 0
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect(t, state.player.reflect_timer > 0, "Expected Reflect timer to activate")
	testing.expect_value(t, state.player.abilities[0].xp, f32(0.0))

	// Enemy collides with player during Reflect window
	entities.spawn_enemy(state, {5, 0}, .Basic_Chaser)
	entities.grid_rebuild(state)
	entities.update_enemies(state, 1.0 / 60.0)

	// Player takes 0 damage, enemy takes reflected 24.0 damage (12 * 2.0), Reflect gains parry XP
	testing.expect_value(t, state.player.hp, state.player.max_hp)
	testing.expect_value(t, state.enemies[0].hp, f32(16.0))
	testing.expect(t, state.player.abilities[0].xp > 0, "Expected Reflect to gain XP on successful parry")
}

@(test)
test_mana_shield_balance_and_xp_rule :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Mana_Shield, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// Verify lowered base shield HP (12.0) and duration (1.75s)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect_value(t, state.player.shield_hp, f32(12.0))
	testing.expect_value(t, state.player.shield_timer, f32(1.75))

	// At level 3+, casting Mana Shield without absorbing damage should grant 0 XP
	state.player.abilities[0].level = 3
	state.player.abilities[0].xp = 0
	state.player.abilities[0].cooldown = 0

	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect_value(t, state.player.abilities[0].xp, f32(0.0))

	// Enemy contacts player -> shield absorbs the 12.0 damage, player HP stays full, XP is awarded
	entities.spawn_enemy(state, {5, 0}, .Basic_Chaser)
	entities.grid_rebuild(state)
	entities.update_enemies(state, 1.0 / 60.0)

	testing.expect_value(t, state.player.hp, state.player.max_hp)
	testing.expect_value(t, state.player.shield_hp, f32(0.0))
	testing.expect(t, state.player.abilities[0].xp > 0, "Expected Mana Shield to gain XP on absorbing damage")
}

@(test)
test_dash_and_haste_utility_behavior :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	// Equip Dash in slot 0 and Haste in slot 1 (verifying Dash works in any slot, not just slot 2)
	entities.init_player(&state.player, {.Dash, .Haste, .Sweep})

	abilities.trigger_ability(state, 0, {1, 0}, {0, 1})
	testing.expect(t, state.player.dash_timer > 0, "Expected Dash timer to activate")
	testing.expect(t, state.player.invuln_timer > 0, "Expected Dash to grant i-frames")
	testing.expect(t, state.player.abilities[0].xp > 0, "Expected Dash to gain utility XP on cast")

	abilities.trigger_ability(state, 1, {1, 0}, {0, 0})
	testing.expect(t, state.player.haste_timer > 0, "Expected Haste timer to activate")
	testing.expect(t, state.player.haste_mult > 1.0, "Expected Haste to boost speed multiplier")
	testing.expect(t, state.player.abilities[1].xp > 0, "Expected Haste to gain utility XP on cast")
}

@(test)
test_knife_throw_flies_out_and_returns :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Knife_Throw, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	entities.spawn_enemy(state, {60, 0}, .Basic_Chaser)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect_value(t, state.projectile_count, 1)
	testing.expect_value(t, state.projectiles[0].kind, structs.Projectile_Kind.Returning_Knife)

	// Step outward flight until knife flips to returning and hits enemy along the way
	dt: f32 = 1.0 / 60.0
	flipped := false
	for _ in 0 ..< 40 {
		entities.grid_rebuild(state)
		entities.update_projectiles(state, dt)
		if state.projectile_count > 0 && state.projectiles[0].returning {
			flipped = true
			break
		}
	}
	testing.expect(t, flipped, "Expected knife to switch to returning phase")
	testing.expect(t, state.enemies[0].hp < state.enemies[0].max_hp, "Expected knife to damage enemy on outward pass")

	// Continue stepping until knife returns and is caught by the player
	for _ in 0 ..< 60 {
		if state.projectile_count == 0 do break
		entities.grid_rebuild(state)
		entities.update_projectiles(state, dt)
	}
	testing.expect_value(t, state.projectile_count, 0)
}

@(test)
test_lunge_shorter_than_dash_and_stab :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Lunge, .Stab, .Dash})
	state.player.pos = {0, 0}

	// Verify Lunge travel distance < Dash travel distance, and Lunge hitbox < Stab range
	lunge_travel := f32(abilities.LUNGE_SPEED) * f32(abilities.LUNGE_DURATION)
	dash_travel := f32(structs.DASH_SPEED) * f32(structs.DASH_DURATION)
	testing.expect(t, lunge_travel < dash_travel, "Expected Lunge range to be shorter than Dash")
	testing.expect(t, abilities.LUNGE_HITBOX_RANGE < abilities.STAB_RANGE, "Expected Lunge hitbox to be shorter than Stab")

	// Enemy in front within Lunge hitbox (40px) is hit; enemy at 80px (Stab range) is missed
	entities.spawn_enemy(state, {40, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {80, 0}, .Basic_Chaser)
	entities.grid_rebuild(state)

	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect(t, state.player.lunge_timer > 0, "Expected Lunge timer active")
	testing.expect_value(t, state.enemies[0].hp, f32(24.0)) // 40 - 16
	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)
}

@(test)
test_mana_nova_damages_and_pushes_360_ring :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Mana_Nova, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// 4 enemies on all sides within radius, 1 outside radius
	entities.spawn_enemy(state, {60, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {-60, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {0, 60}, .Basic_Chaser)
	entities.spawn_enemy(state, {0, -60}, .Basic_Chaser)
	entities.spawn_enemy(state, {220, 0}, .Basic_Chaser)

	entities.grid_rebuild(state)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})

	for i in 0 ..< 4 {
		testing.expect_value(t, state.enemies[i].hp, f32(16.0)) // 40 - 24
	}
	testing.expect(t, state.enemies[0].pos.x > 60.0, "Expected Mana Nova outward knockback")
	testing.expect_value(t, state.enemies[4].hp, state.enemies[4].max_hp)
}

@(test)
test_mana_orb_spawns_three_and_damages_in_range :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Mana_Orb, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// Enemy inside orb aura range, enemy far away
	entities.spawn_enemy(state, {35, 0}, .Basic_Chaser)
	entities.spawn_enemy(state, {300, 0}, .Basic_Chaser)

	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect_value(t, state.projectile_count, 3)

	// Step past the initial 0.05s pulse timer so orbs pulse damage
	entities.grid_rebuild(state)
	entities.update_projectiles(state, 0.1)

	testing.expect(t, state.enemies[0].hp < state.enemies[0].max_hp, "Expected Mana Orb aura to damage nearby enemy")
	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)

	// Upgrading Projectiles focus spawns extra orbs (3 + 2 = 5)
	state.projectile_count = 0
	state.player.abilities[0].cooldown = 0
	state.player.abilities[0].focus_ranks[.Projectiles] = 2
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect_value(t, state.projectile_count, 5)
}

@(test)
test_mend_heals_slowly_over_time :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Mend, .Sweep, .Dash})
	state.player.hp = 50.0

	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect(t, state.player.mend_timer > 0, "Expected Mend timer active")
	testing.expect(t, state.player.abilities[0].xp > 0, "Expected Mend utility XP on cast")

	// Simulate 1.0s of Mend healing (4.0 HP/s -> 54.0 HP)
	dt: f32 = 1.0
	heal_dt := min(dt, state.player.mend_timer)
	state.player.hp = min(state.player.max_hp, state.player.hp + state.player.mend_hps * heal_dt)
	testing.expect_value(t, state.player.hp, f32(54.0))
}
