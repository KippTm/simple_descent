package abilities

import "../structs"

// -----------------------------------------------------------------------------
// Utility Ability: Haste (Temporary Movement Speed Boost)
// -----------------------------------------------------------------------------

HASTE_DEF :: structs.Ability_Def {
	id            = .Haste,
	name          = "Haste",
	short_desc    = "Grants a temporary boost to movement speed.",
	category      = .Utility,
	cooldown_time = 5.5,
}

HASTE_BASE_MULT   :: 1.45
HASTE_LEVEL_SCALE :: 0.05
HASTE_DURATION    :: 3.0
HASTE_UTILITY_XP  :: 1.5 // Utility abilities gain XP on every cast, at a slower pace

cast_haste :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = aim_dir
	_ = move_input
	ability := &state.player.abilities[slot]
	mult := f32(HASTE_BASE_MULT) + f32(HASTE_LEVEL_SCALE) * f32(ability.level - 1)

	state.player.haste_mult = mult
	state.player.haste_timer = HASTE_DURATION

	grant_ability_xp(ability, HASTE_UTILITY_XP)
}
