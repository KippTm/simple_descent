package entities

import "core:math"
import "../structs"

// -----------------------------------------------------------------------------
// Combat & Usage-Based Leveling ("Muscle Memory")
// -----------------------------------------------------------------------------

xp_for_next_level :: #force_inline proc(level: int) -> f32 {
	return 10.0 * math.pow(f32(level), 1.35)
}

grant_ability_xp :: proc(ability: ^structs.Ability, amount: f32) {
	ability.xp += amount
	req := xp_for_next_level(ability.level)
	for ability.xp >= req {
		ability.xp -= req
		ability.level += 1
		req = xp_for_next_level(ability.level)
	}
}

// Monument interaction rule from spec.md:
// - First specialization on an ability is free (tier = 1).
// - Subsequent specializations cost ability levels equal to tiers gained.
grant_specialization :: proc(ability: ^structs.Ability, spec: structs.Spec_Type, tiers_gained: int) -> bool {
	if ability.spec_type == .None {
		ability.spec_type = spec
		ability.spec_tier = 1
		return true
	}

	if ability.level <= tiers_gained {
		return false // Not enough ability levels to pay the sacrifice cost
	}

	ability.level -= tiers_gained
	if ability.spec_type == spec {
		ability.spec_tier += tiers_gained
	} else {
		ability.spec_type = spec
		ability.spec_tier = tiers_gained
	}
	return true
}

apply_ability_hit :: proc(state: ^structs.Game_State, ability_slot: int, enemy_idx: int, base_damage: f32) {
	ability := &state.player.abilities[ability_slot]

	// Grant muscle-memory XP on successful hit
	grant_ability_xp(ability, 2.5)

	// Scale specialization magnitude by both tier and current ability level
	spec_scale := f32(ability.spec_tier) * (1.0 + 0.1 * f32(ability.level))

	state.enemies[enemy_idx].hp -= base_damage

	switch ability.spec_type {
	case .None:
	case .Fire:
		state.enemies[enemy_idx].status_flags += {.Burn}
		state.enemies[enemy_idx].burn_timer = 2.0 + 0.5 * spec_scale
	case .Ice:
		state.enemies[enemy_idx].status_flags += {.Slow}
		state.enemies[enemy_idx].slow_timer = 1.5 + 0.4 * spec_scale
	case .Blood:
		heal := 0.5 * spec_scale
		state.player.hp = min(state.player.max_hp, state.player.hp + heal)
	case .Storm:
		state.enemies[enemy_idx].hp -= 4.0 * spec_scale
	}
}
