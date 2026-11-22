package abilities

import "core:math"
import "../structs"

// -----------------------------------------------------------------------------
// Shared Combat, Usage-Based Leveling ("Muscle Memory") & Specializations
// -----------------------------------------------------------------------------

// Gentle exponential scaling using Euler's number: 20 * e^(0.22 * (level - 1))
// Lv 1->2: 20.0, Lv 2->3: ~24.9, Lv 3->4: ~31.1, Lv 5->6: ~48.2, Lv 10->11: ~144.9
XP_BASE     :: 20.0
XP_EXPONENT :: 0.22

xp_for_next_level :: #force_inline proc(level: int) -> f32 {
	return XP_BASE * math.exp(f32(XP_EXPONENT) * f32(max(level - 1, 0)))
}

enemy_xp_reward :: proc(kind: structs.Enemy_Kind) -> f32 {
	switch kind {
	case .Basic_Chaser:
		return 5.0
	case .Ranged_Shooter:
		return 9.0
	case .Boss:
		return 50.0
	}
	return 5.0
}

grant_ability_xp :: proc(ability: ^structs.Ability, amount: f32) {
	if amount <= 0 do return
	ability.xp += amount
	req := xp_for_next_level(ability.level)
	for ability.xp >= req {
		ability.xp -= req
		ability.level += 1
		ability.focus_ranks[ability.upgrade_focus] += 1
		if ability.level % structs.UPGRADE_FOCUS_INTERVAL == 0 {
			ability.pending_focus_choice = true
		}
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

	// Remember which ability last damaged this enemy so kill XP is awarded on death
	state.enemies[enemy_idx].last_hit_ability_slot = ability_slot

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

spawn_bolt_projectile :: proc(
	state: ^structs.Game_State,
	pos, dir: [2]f32,
	speed, radius, damage, lifetime: f32,
	ability_slot: int,
) {
	if state.projectile_count >= structs.MAX_PROJECTILES do return

	idx := state.projectile_count
	state.projectile_count += 1

	state.projectiles[idx] = structs.Projectile {
		kind           = .Bolt,
		pos            = pos,
		vel            = dir * speed,
		radius         = radius,
		damage         = damage,
		lifetime       = lifetime,
		ability_slot   = ability_slot,
		last_hit_enemy = -1,
	}
}
