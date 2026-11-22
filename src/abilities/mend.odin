package abilities

import "../structs"

// -----------------------------------------------------------------------------
// Utility Ability: Mend (Slow Heal Over Time)
// -----------------------------------------------------------------------------

MEND_DEF :: structs.Ability_Def {
	id              = .Mend,
	name            = "Mend",
	short_desc      = "Slowly restores health over time.",
	category        = .Utility,
	cooldown_time   = 7.50,
	default_focus   = .Duration,
	allowed_focuses = {.Damage, .Duration},
}

MEND_BASE_HPS      :: 4.0 // Slow heal: 4 HP/s (16 HP over 4s at base)
MEND_POWER_STEP    :: 0.15
MEND_BASE_DURATION :: 4.0
MEND_DURATION_STEP :: 0.75
MEND_UTILITY_XP    :: 1.5 // Utility abilities gain XP on every cast, at a slower pace

cast_mend :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = aim_dir
	_ = move_input
	ability := &state.player.abilities[slot]
	power_mult := 1.0 + f32(MEND_POWER_STEP) * f32(ability.focus_ranks[.Damage])
	duration := f32(MEND_BASE_DURATION) + f32(MEND_DURATION_STEP) * f32(ability.focus_ranks[.Duration])

	state.player.mend_hps = f32(MEND_BASE_HPS) * power_mult
	state.player.mend_timer = duration

	grant_ability_xp(ability, MEND_UTILITY_XP)
}
