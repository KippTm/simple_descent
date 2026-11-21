package tests

import "core:testing"
import "../src/abilities"
import "../src/entities"
import "../src/structs"

@(test)
test_registry_completeness :: proc(t: ^testing.T) {
	testing.expect_value(t, len(abilities.SELECTABLE_ABILITIES), 7)

	for id in abilities.SELECTABLE_ABILITIES {
		def := abilities.ABILITY_DEFS[id]
		testing.expect_value(t, def.id, id)
		testing.expect(t, def.name != "", "Expected ability to have a name")
		testing.expect(t, def.category != .None, "Expected ability to have a category")
		testing.expect(t, def.cooldown_time > 0, "Expected positive cooldown")
		testing.expect(t, abilities.ABILITY_CAST_PROCS[id] != nil, "Expected non-nil cast proc")

		inst := abilities.make_ability(id)
		testing.expect_value(t, inst.spec_type, structs.Spec_Type.None)
		testing.expect_value(t, inst.spec_tier, 0)
		testing.expect_value(t, inst.level, 1)
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
test_stab_hits_deep_narrow_line_only :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Stab, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// Enemy 0: deep straight ahead along +X (beyond Sweep's 68px range, inside Stab's 112px range)
	entities.spawn_enemy(state, {95, 0}, .Basic_Chaser)
	// Enemy 1: off-axis to the side (outside narrow stab width)
	entities.spawn_enemy(state, {35, 45}, .Basic_Chaser)

	entities.grid_rebuild(state)
	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})

	testing.expect_value(t, state.enemies[0].hp, f32(22.0)) // 40 - 18
	testing.expect_value(t, state.enemies[1].hp, state.enemies[1].max_hp)
	testing.expect(t, state.player.abilities[0].xp > 0, "Expected Stab to gain XP on hit")
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

	// Player takes 0 damage, enemy takes reflected 24.0 damage (12 * 2.0), Reflect gains XP
	testing.expect_value(t, state.player.hp, state.player.max_hp)
	testing.expect_value(t, state.enemies[0].hp, f32(16.0))
	testing.expect(t, state.player.abilities[0].xp > 0, "Expected Reflect to gain XP on successful parry")
}

@(test)
test_mana_shield_absorbs_damage_and_xp_rule :: proc(t: ^testing.T) {
	state := new(structs.Game_State)
	defer free(state)

	entities.init_player(&state.player, {.Mana_Shield, .Mana_Bolt, .Dash})
	state.player.pos = {0, 0}

	// At level 3+, casting Mana Shield without absorbing damage should grant 0 XP
	state.player.abilities[0].level = 3
	state.player.abilities[0].xp = 0

	abilities.trigger_ability(state, 0, {1, 0}, {0, 0})
	testing.expect(t, state.player.shield_hp > 0, "Expected Mana Shield HP to be active")
	testing.expect_value(t, state.player.abilities[0].xp, f32(0.0))

	// Enemy contacts player -> shield absorbs the 12.0 damage, player HP stays full, XP is awarded
	entities.spawn_enemy(state, {5, 0}, .Basic_Chaser)
	entities.grid_rebuild(state)
	entities.update_enemies(state, 1.0 / 60.0)

	testing.expect_value(t, state.player.hp, state.player.max_hp)
	testing.expect(t, state.player.shield_hp < state.player.shield_max_hp, "Expected shield to lose HP")
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
