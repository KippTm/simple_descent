package abilities

import "../structs"

// -----------------------------------------------------------------------------
// Utility Ability: Haste (Temporary Movement Speed Boost)
// -----------------------------------------------------------------------------

HASTE_DEF :: structs.Ability_Def {
	id              = .Haste,
	name            = "Haste",
	short_desc      = "Grants a temporary boost to movement speed.",
	category        = .Utility,
	cooldown_time   = 5.5,
	default_focus   = .Duration,
	allowed_focuses = {.Range, .Duration},
}

HASTE_BASE_MULT     :: 1.45
HASTE_SPEED_STEP    :: 0.08
HASTE_DURATION      :: 3.0
HASTE_DURATION_STEP :: 0.50
HASTE_UTILITY_XP    :: 1.5 // Utility abilities gain XP on every cast, at a slower pace

cast_haste :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = aim_dir
	_ = move_input
	ability := &state.player.abilities[slot]
	mult := f32(HASTE_BASE_MULT) + f32(HASTE_SPEED_STEP) * f32(ability.focus_ranks[.Range])
	duration := f32(HASTE_DURATION) + f32(HASTE_DURATION_STEP) * f32(ability.focus_ranks[.Duration])

	state.player.haste_mult = mult
	state.player.haste_timer = duration

	grant_ability_xp(ability, HASTE_UTILITY_XP)
}
