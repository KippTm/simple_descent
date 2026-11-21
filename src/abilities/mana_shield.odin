package abilities

import "../structs"

// -----------------------------------------------------------------------------
// Magical Ability: Mana Shield (Timed Damage-Absorbing Barrier)
// -----------------------------------------------------------------------------

MANA_SHIELD_DEF :: structs.Ability_Def {
	id            = .Mana_Shield,
	name          = "Mana Shield",
	short_desc    = "Barrier that absorbs damage for a short duration.",
	category      = .Magical,
	cooldown_time = 5.0,
}

MANA_SHIELD_BASE_HP       :: 25.0
MANA_SHIELD_LEVEL_SCALE   :: 0.18
MANA_SHIELD_DURATION      :: 4.0
MANA_SHIELD_FREE_XP_LEVEL :: 2 // Levels 1-2 gain small XP on cast; level 3+ requires absorbing damage

cast_mana_shield :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = aim_dir
	_ = move_input
	ability := &state.player.abilities[slot]
	level_mult := 1.0 + f32(MANA_SHIELD_LEVEL_SCALE) * f32(ability.level - 1)
	shield_amount := f32(MANA_SHIELD_BASE_HP) * level_mult

	state.player.shield_hp = shield_amount
	state.player.shield_max_hp = shield_amount
	state.player.shield_timer = MANA_SHIELD_DURATION
	state.player.shield_slot = slot

	// Early levels grant a small amount of XP on cast; after a few levels it only gains XP on absorption
	if ability.level <= MANA_SHIELD_FREE_XP_LEVEL {
		grant_ability_xp(ability, 1.5)
	}
}

// Absorbs incoming damage with the active Mana Shield, returning any remaining overflow damage.
absorb_with_mana_shield :: proc(state: ^structs.Game_State, incoming_damage: f32) -> f32 {
	if state.player.shield_timer <= 0 || state.player.shield_hp <= 0 || incoming_damage <= 0 {
		return incoming_damage
	}

	absorbed := min(state.player.shield_hp, incoming_damage)
	state.player.shield_hp -= absorbed
	if state.player.shield_hp <= 0 {
		state.player.shield_hp = 0
		state.player.shield_timer = 0
	}

	slot := state.player.shield_slot
	if absorbed > 0 && slot >= 0 && slot < state.player.ability_count {
		grant_ability_xp(&state.player.abilities[slot], 3.0)
	}

	return incoming_damage - absorbed
}
